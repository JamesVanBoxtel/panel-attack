Glicko2 = require("Glicko")

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

local function testRatingPeriods() 
  
  --Glicko2.Tau = 0.1

  local player1 = Glicko2.g1(1500, 350, 0.01)
  local player2 = Glicko2.g1(1500, 30, 0.01)

  local player1Results = {}
  for i = 1, 10, 1 do
    player1Results[#player1Results+1] = player2:score(1)
  end

  local outcomes = {}

  local matchSet = {1}
  for i = 1, 50, 1 do
    matchSet[#matchSet+1] = 0
  end
  outcomes[#outcomes+1] = matchSet

  for i = 1, 24 * 60, 1 do
    outcomes[#outcomes+1] = {}
  end

  local updatedPlayer1 = player1:copy()
  local updatedPlayer2 = player2:copy()
  for i = 1, #outcomes, 1 do
    updatedPlayer1, updatedPlayer2 = Glicko2.updatedRatings(updatedPlayer1, updatedPlayer2, outcomes[i])
    --logger.trace(updatedPlayer1.Rating)
  end

  --logger.trace(updatedPlayer1.Rating)
  --assert(round(allAtOncePlayer1.Rating, 2) == 1197.00)
end 

testRatingPeriods()