local PlayerRating = require("PlayerRating")
local simpleCSV = require("simplecsv")

-- If starting RD is too high, or too many matches happen in one rating period, massive swings can happen.
-- This test is to explore that and come up with sane values.
local function testWeirdNumberStability() 

  local player1 = PlayerRating(1273, 20)
  local player2 = PlayerRating(1500, 100)

  local wins = 12
  local totalGames = 25

  local updatedPlayer1 = player1:newRatingWithResults(player1:createSetResults(player2, wins, totalGames))
  local updatedPlayer2 = player2:newRatingWithResults(player1:createSetResults(player1, totalGames-wins, totalGames))

  assert(updatedPlayer1:getRating() > 1073)
  assert(updatedPlayer2:getRating() < 1500)
end

testWeirdNumberStability()

local function testRatingPeriods() 
  local players = {}
  for _ = 1, 3 do
    players[#players+1] = PlayerRating()
  end
  
  local previousPlayers = nil
  for i = 1, 100, 1 do
    local playerResults = {}
    for _ = 1, 3 do
      playerResults[#playerResults+1] = {}
    end
    table.appendToList(playerResults[1], players[1]:createSetResults(players[2], 6, 10))
    table.appendToList(playerResults[2], players[2]:createSetResults(players[1], 4, 10))
    
    table.appendToList(playerResults[1], players[1]:createSetResults(players[3], 4, 5))
    table.appendToList(playerResults[3], players[3]:createSetResults(players[1], 1, 5))

    table.appendToList(playerResults[2], players[2]:createSetResults(players[3], 3, 5))
    table.appendToList(playerResults[3], players[3]:createSetResults(players[2], 2, 5))

    previousPlayers = {}
    for k = 1, 3 do
      previousPlayers[#previousPlayers+1] = players[k]:copy()
    end
    for k = 1, 3 do
      players[k] = players[k]:newRatingWithResults(playerResults[k])
    end
  end

  assert(players[1]:getRating() > players[2]:getRating())
  assert(players[1]:getRating() > players[3]:getRating())
  assert(players[2]:getRating() > players[3]:getRating())

  assert(players[1].glicko.RD < players[3].glicko.RD)
  assert(players[2].glicko.RD < players[3].glicko.RD)

  for k = 1, 3 do
    -- rating and deviation should stabilize over time if players perform the same
    assert(math.abs(previousPlayers[k]:getRating() - players[k]:getRating()) < 1)
    assert(math.abs(previousPlayers[k].glicko.RD - players[k].glicko.RD) < 1)
    assert(previousPlayers[k]:isProvisional() == false)
  end
end 

testRatingPeriods()

local function testFarming() 
  local players = {}
  for _ = 1, 3 do
    players[#players+1] = PlayerRating()
  end
  
  -- Player 1 and 2 play normal sets to get a standard
  for i = 1, 100, 1 do
    local playerResults = {}
    for _ = 1, 3 do
      playerResults[#playerResults+1] = {}
    end

    table.appendToList(playerResults[1], players[1]:createSetResults(players[2], 11, 20))
    table.appendToList(playerResults[2], players[2]:createSetResults(players[1], 9, 20))

    for k = 1, 2 do
      players[k] = players[k]:newRatingWithResults(playerResults[k])
    end
  end

  -- Farm newcomers to see how much rating you can gain
  for i = 1, 100, 1 do
    local playerResults = {}
    for _ = 1, 3 do
      playerResults[#playerResults+1] = {}
    end

    local newbiePlayer = PlayerRating()
    table.appendToList(playerResults[1], players[1]:createSetResults(newbiePlayer, 10, 10))

    for k = 1, 1 do
      players[k] = players[k]:newRatingWithResults(playerResults[k])
    end
  end

  assert(players[1]:getRating() > DEFAULT_RATING + ALLOWABLE_RATING_SPREAD) -- Ranked high enough we can't play default players anymore
  assert(players[1]:getRating() < 2000) -- Thus we couldn't farm really high

end 

testFarming()

local function invertedGameResult(gameResult)
  if gameResult == 0 then
    return 1
  end
  if gameResult == 1 then
    return 0
  end
  -- Ties stay 0.5
  return gameResult
end

local function runRatingPeriods(firstRatingPeriod, lastRatingPeriod, players, glickoResultsTable)
  -- Run each rating period (the later ones will just increase RD)
  for i = firstRatingPeriod, lastRatingPeriod, 1 do
    for playerID, playerTable in pairs(players) do

      local playerRating = playerTable.playerRating
      local gameResults = playerTable.gameResults
      local newPlayerRating = playerRating:newRatingWithResults(gameResults)

      playerTable.playerRating = newPlayerRating
      playerTable.gameResults = {}
    end

    if i == firstRatingPeriod then
      for playerID, playerTable in pairs(players) do
        local row = {}
        row[#row+1] = i
        row[#row+1] = playerID
        row[#row+1] = playerTable.playerRating:getRating()
        row[#row+1] = playerTable.playerRating.glicko.RD
        glickoResultsTable[#glickoResultsTable+1] = row
      end
    end
  end
end

local function testRealWorldData() 
  
  local players = {}
  local glickoResultsTable = {}
  local ratingPeriodNeedingRun = nil
  local latestRatingPeriodFound = nil
  local gameResults = simpleCSV.read("GameResults.csv")
  assert(gameResults)
  
  for row = 1, #gameResults do
    local player1ID = tonumber(gameResults[row][1])
    local player2ID = tonumber(gameResults[row][2])
    local winResult = tonumber(gameResults[row][3])
    local ranked = tonumber(gameResults[row][4])
    local timestamp = tonumber(gameResults[row][5])
    local dateTable = os.date("*t", timestamp)
    
    assert(player1ID)
    assert(player2ID)
    assert(winResult)
    assert(ranked)
    assert(timestamp)
    assert(dateTable)

    if ranked == 0 then
      goto continue
    end

    latestRatingPeriodFound = PlayerRating.ratingPeriodForTimeStamp(timestamp)
    if ratingPeriodNeedingRun == nil then
      ratingPeriodNeedingRun = latestRatingPeriodFound
    end

    -- if we just passed the rating period, time to update ratings
    if ratingPeriodNeedingRun ~= latestRatingPeriodFound then
      assert(latestRatingPeriodFound > ratingPeriodNeedingRun)
      runRatingPeriods(ratingPeriodNeedingRun, latestRatingPeriodFound-1, players, glickoResultsTable)
      ratingPeriodNeedingRun = latestRatingPeriodFound
    end

    local currentPlayerSets = {{player1ID, player2ID}, {player2ID, player1ID}}
    for _, currentPlayers in ipairs(currentPlayerSets) do
      local playerID = currentPlayers[1]
      if not players[playerID] then
        players[playerID] = {}
        players[playerID].playerRating = PlayerRating()
        players[playerID].gameResults = {}
        players[playerID].error = 0
        players[playerID].totalGames = 0
      end
    end
    
    for index, currentPlayers in ipairs(currentPlayerSets) do
      local player = players[currentPlayers[1]].playerRating
      local opponent = players[currentPlayers[2]].playerRating
      local gameResult = winResult
      if index == 2 then
        gameResult = invertedGameResult(winResult)
      end
      local expected = player:expectedOutcome(opponent)
      --if player:isProvisional() == false then
        players[currentPlayers[1]].error = players[currentPlayers[1]].error + (gameResult - expected)
        players[currentPlayers[1]].totalGames = players[currentPlayers[1]].totalGames + 1
      --end
      local result = player:createGameResult(opponent, gameResult)
      local gameResults = players[currentPlayers[1]].gameResults
      gameResults[#gameResults+1] = result
    end
    
    ::continue::
  end

  -- Handle the last rating period
  assert(ratingPeriodNeedingRun == latestRatingPeriodFound)
  runRatingPeriods(ratingPeriodNeedingRun, latestRatingPeriodFound, players, glickoResultsTable)

  local totalError = 0
  local totalGames = 0
  local provisionalCount = 0
  local playerCount = 0
  for playerID, playerTable in pairs(players) do
    if playerTable.totalGames > 0 then
      local error = math.abs(playerTable.error)
      totalError = totalError + error
      totalGames = totalGames + playerTable.totalGames
    end
    if playerTable.playerRating:isProvisional() then
      provisionalCount = provisionalCount + 1
      assert(playerTable.totalGames < 100)
    end
    playerCount = playerCount + 1
  end
  local totalErrorPerGame = totalError / totalGames

  simpleCSV.write("Glicko.csv", glickoResultsTable)
  -- 0.03724587514630  RATING PERIOD = 16hrs -- DEFAULT_RATING_DEVIATION = 250 = MAX_DEVIATION -- PROVISIONAL_DEVIATION = RD * 0.5 -- DEFAULT_VOLATILITY = 0.06 = MAX_VOLATILITY
  -- 0.03792533617676  RATING PERIOD = 24hrs -- DEFAULT_RATING_DEVIATION = 250 = MAX_DEVIATION -- PROVISIONAL_DEVIATION = RD * 0.5 -- DEFAULT_VOLATILITY = 0.06 = MAX_VOLATILITY
end 

testRealWorldData()