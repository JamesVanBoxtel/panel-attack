local Glicko2 = require("Glicko")
local simpleCSV = require("simplecsv")

local function basicTest() 
  local player1 = Glicko2.g1(1500, 350)
  local player2 = Glicko2.g1(1500, 350)

  local updatedPlayer1, updatedPlayer2 = Glicko2.updatedRatings(player1, player2, {1})

  assert(math.floor(updatedPlayer1.Rating) == 1662)
  assert(math.floor(updatedPlayer2.Rating) == 1337)

  assert(player1.RD > updatedPlayer1.RD)
  assert(player2.RD > updatedPlayer2.RD)
end 

basicTest()

local function establishedVersusNew() 

  local player1 = Glicko2.g1(1500, 40)
  local player2 = Glicko2.g1(1500, 350)
  
  local updatedPlayer1, updatedPlayer2 = Glicko2.updatedRatings(player1, player2, {1, 1, 1, 1, 1, 1, 1, 1, 1, 0})
  
  assert(math.floor(updatedPlayer1.Rating) == 1524)
  assert(math.floor(updatedPlayer2.Rating) == 1245)

  assert(math.floor(updatedPlayer1.RD) == 40)
  assert(math.floor(updatedPlayer2.RD) == 105)
end 

establishedVersusNew()

local function orderDoesntMatter() 

  local player1 = Glicko2.g1(1500, 350)
  local player2 = Glicko2.g1(1500, 350)
  
  local player1Copy = player1:copy()
  local player2Copy = player2:copy()

  local updatedPlayer1, updatedPlayer2 = Glicko2.updatedRatings(player1, player2, {1, 1, 1, 0})
  
  local updatedPlayer1Copy, updatedPlayer2Copy = Glicko2.updatedRatings(player1Copy, player2Copy, {0, 1, 1, 1})

  assert(updatedPlayer1Copy.Rating == updatedPlayer1.Rating)
  assert(updatedPlayer2Copy.Rating == updatedPlayer2.Rating)
end 

orderDoesntMatter()

local function paperExample() 

  local player1 = Glicko2.g1(1500, 200)
  local player2 = Glicko2.g1(1400, 30)
  local player3 = Glicko2.g1(1550, 100)
  local player4 = Glicko2.g1(1700, 300)

  local player1Results = {}
  player1Results[#player1Results+1] = player2:score(1)
  player1Results[#player1Results+1] = player3:score(0)
  player1Results[#player1Results+1] = player4:score(0)

  local updatedPlayer1 = player1:update(player1Results)

  assert(round(updatedPlayer1.Rating, 2) == 1464.05)
  assert(round(updatedPlayer1.RD, 2) == 151.52)
  assert(round(updatedPlayer1.Vol, 2) == 0.06)
end 

paperExample()


local function getScoreResults(player1, player2, player1WinCount, gameCount)
  
  assert(gameCount >= player1WinCount)

  local matchSet = {}
  for i = 1, player1WinCount, 1 do
    matchSet[#matchSet+1] = 1
  end
  for i = 1, gameCount - player1WinCount, 1 do
    matchSet[#matchSet+1] = 0
  end
    
  local player1Results = {}
  for j = 1, #matchSet do -- play through games
    local matchOutcome = matchSet[j]
    player1Results[#player1Results+1] = player2:score(matchOutcome)
  end

  return player1Results
end


-- If starting RD is too high, or too many matches happen in one rating period, massive swings can happen.
-- This test is to explore that and come up with sane values.
local function testWeirdNumberStability() 

  local initialVolatility = 0.06

  local player1 = Glicko2.g1(1073, 20, initialVolatility)
  local player2 = Glicko2.g1(1500, 100, initialVolatility)

  local wins = 12
  local total = 25
  local player1Results = getScoreResults(player1, player2, wins, total)
  local player2Results = getScoreResults(player2, player1, total-wins, total)

  local updatedPlayer1 = player1:update(player1Results)
  local updatedPlayer2 = player2:update(player2Results)

  assert(updatedPlayer2.Rating > 1073)

  player1Results = getScoreResults(player1, player2, 0, 1)
  player2Results = getScoreResults(player2, player1, 1, 1)

  updatedPlayer1 = player1:update(player1Results)
  updatedPlayer2 = player2:update(player2Results)

  assert(updatedPlayer1.Rating < updatedPlayer2.Rating)

end

testWeirdNumberStability()

local function testRatingPeriods() 
  
  -- DEFAULTS
  --Tau = 0.5, -- Slider for volatility, lower means RD changes more
	--InitialVolatility = 0.06

  -- Uncomment to set Tau
  --Glicko2.Tau = 0.01

  local initialVolatility = 0.06

  local player1 = Glicko2.g1(1500, 350, initialVolatility)
  local player2 = Glicko2.g1(1500, 350, initialVolatility)
  local player3 = Glicko2.g1(1500, 350, initialVolatility)

  local updatedPlayer1 = player1:copy()
  local updatedPlayer2 = player2:copy()
  local updatedPlayer3 = player3:copy()
  for i = 1, 60, 1 do
    local player1Results = getScoreResults(updatedPlayer1, updatedPlayer2, 6, 10)
    local player2Results = getScoreResults(updatedPlayer2, updatedPlayer1, 4, 10)

    table.appendToList(player1Results, getScoreResults(updatedPlayer1, updatedPlayer3, 4, 5))
    local player3Results = getScoreResults(updatedPlayer1, updatedPlayer3, 1, 5)

    table.appendToList(player2Results, getScoreResults(updatedPlayer2, updatedPlayer3, 3, 5))
    table.appendToList(player3Results, getScoreResults(updatedPlayer3, updatedPlayer2, 2, 5))

    updatedPlayer1 = updatedPlayer1:update(player1Results)
    updatedPlayer2 = updatedPlayer2:update(player2Results)
    updatedPlayer3 = updatedPlayer3:update(player3Results)
  end

  assert(updatedPlayer1.Rating > updatedPlayer2.Rating)
  assert(updatedPlayer1.Rating > updatedPlayer3.Rating)
  assert(updatedPlayer2.Rating > updatedPlayer3.Rating)

  assert(updatedPlayer1.RD < updatedPlayer3.RD)
  assert(updatedPlayer2.RD < updatedPlayer3.RD)

end 

testRatingPeriods()

local function testFarming() 
  
  -- DEFAULTS
  --Tau = 0.5, -- Slider for volatility, lower means RD changes more
	--InitialVolatility = 0.06

  -- Uncomment to set Tau
  --Glicko2.Tau = 0.01

  local initialVolatility = 0.06

  local player1 = Glicko2.g1(1500, 350, initialVolatility)
  local player2 = Glicko2.g1(1500, 350, initialVolatility)
  local player3 = Glicko2.g1(1500, 350, initialVolatility)

  local updatedPlayer1 = player1:copy()
  local updatedPlayer2 = player2:copy()

  -- Player 1 and 2 play normal sets to get a standard
  for i = 1, 60, 1 do
    local player1Results = getScoreResults(updatedPlayer1, updatedPlayer2, 11, 20)
    local player2Results = getScoreResults(updatedPlayer2, updatedPlayer1, 9, 20)

    updatedPlayer1 = updatedPlayer1:update(player1Results)
    updatedPlayer2 = updatedPlayer2:update(player2Results)
  end

  -- Farm newcomers to see how much rating you can gain
  for i = 1, 20, 1 do
    local updatedPlayer3 = player3:copy()
    local player2Results = getScoreResults(updatedPlayer2, updatedPlayer3, 10, 10)
    updatedPlayer2 = updatedPlayer2:update(player2Results)
  end
  local min, max = updatedPlayer2:percent(0.95)
  assert(min < 1800, "Should not be able to farm that high....")

end 

testFarming()

local function invertedGameResult(gameResult)
  if gameResult == 0 then
    return 1
  end
  if gameResult == 1 then
    return 0
  end
  return gameResult
end

local function ratingPeriodForTimeStamp(timestamp)
  local ratingPeriodInSeconds = 60 * 20
  local hour = math.floor(timestamp / (ratingPeriodInSeconds))
  return hour
end

local function runRatingPeriods(firstRatingPeriod, lastRatingPeriod, players, glickoResultsTable)
  -- Run each rating period (the later ones will just increase RD)
  for i = firstRatingPeriod, lastRatingPeriod, 1 do
    for playerID, playerTable in pairs(players) do
      playerTable.glicko = playerTable.glicko:update(playerTable.gameResults)
      playerTable.gameResults = {}
    end

    if i == firstRatingPeriod then
      for playerID, playerTable in pairs(players) do
        local row = {}
        row[#row+1] = i
        row[#row+1] = playerID
        row[#row+1] = playerTable.glicko.Rating
        row[#row+1] = playerTable.glicko.RD
        glickoResultsTable[#glickoResultsTable+1] = row
      end
    end
  end
end

local function testRealWorldData() 
  
  -- DEFAULTS
  --Tau = 0.5, -- Slider for volatility, lower means RD changes more
	--InitialVolatility = 0.06

  -- Uncomment to set Tau
  --Glicko2.Tau = 0.01

  local initialRating = 1500
  local initialRD = 350
  local initialVolatility = 0.06

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

    latestRatingPeriodFound = ratingPeriodForTimeStamp(timestamp)
    if ratingPeriodNeedingRun == nil then
      ratingPeriodNeedingRun = latestRatingPeriodFound
    end

    -- if we just passed the rating period, time to update ratings
    if ratingPeriodNeedingRun ~= latestRatingPeriodFound then
      assert(latestRatingPeriodFound > ratingPeriodNeedingRun)
      runRatingPeriods(ratingPeriodNeedingRun, latestRatingPeriodFound-1, players, glickoResultsTable)
      ratingPeriodNeedingRun = latestRatingPeriodFound
    end

    if not players[player1ID] then
      players[player1ID] = {}
      players[player1ID].glicko = Glicko2.g1(initialRating, initialRD, initialVolatility)
      players[player1ID].gameResults = {}
    end
    if not players[player2ID] then
      players[player2ID] = {}
      players[player2ID].glicko = Glicko2.g1(initialRating, initialRD, initialVolatility)
      players[player2ID].gameResults = {}
    end
      
    players[player1ID].gameResults[#players[player1ID].gameResults+1] = players[player2ID].glicko:score(winResult)
    players[player2ID].gameResults[#players[player2ID].gameResults+1] = players[player1ID].glicko:score(invertedGameResult(winResult))    
    ::continue::
  end

  -- Handle the last rating period
  assert(ratingPeriodNeedingRun == latestRatingPeriodFound)
  runRatingPeriods(ratingPeriodNeedingRun, latestRatingPeriodFound, players, glickoResultsTable)

  simpleCSV.write("Glicko.csv", glickoResultsTable)
end 

testRealWorldData()