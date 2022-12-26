local logger = require("logger")
local Glicko2 = require("Glicko")

ALLOWABLE_RATING_SPREAD = 400
DEFAULT_RATING = 1500

local DEFAULT_RATING_DEVIATION = 250
local MAX_DEVIATION = DEFAULT_RATING_DEVIATION
local PROVISIONAL_DEVIATION = DEFAULT_RATING_DEVIATION * 0.5

local DEFAULT_VOLATILITY = 0.06
local MAX_VOLATILITY = DEFAULT_VOLATILITY

local RATING_PERIOD_IN_SECONDS = 60 * 60 * 16

-- Represents the rating for a player
PlayerRating =
  class(
  function(self, rating, ratingDeviation, volatility)
    rating = rating or DEFAULT_RATING
    ratingDeviation = ratingDeviation or DEFAULT_RATING_DEVIATION
    volatility = volatility or DEFAULT_VOLATILITY
    self.glicko = Glicko2.g1(rating, ratingDeviation, volatility)
  end
)

function PlayerRating.ratingPeriodForTimeStamp(timestamp)
  local ratingPeriod = math.floor(timestamp / (RATING_PERIOD_IN_SECONDS))
  return ratingPeriod
end

function PlayerRating:copy()
  local result = deepcpy(self)
  return result
end

function PlayerRating:getRating()
  return self.glicko.Rating
end

function PlayerRating:expectedOutcome(opponent)
  return self.glicko:expectedOutcome(opponent.glicko)
end

function PlayerRating:isProvisional()
  return self.glicko.RD >= PROVISIONAL_DEVIATION
end

-- Returns an array of result objects representing the players wins against the given player
function PlayerRating:createSetResults(opponent, player1WinCount, gameCount)
  
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
    local gameResult = self:createGameResult(opponent, matchOutcome)
    if gameResult then
      player1Results[#player1Results+1] = gameResult
    end
  end

  return player1Results
end

function PlayerRating:createGameResult(opponent, matchOutcome)
  local result = nil

  if math.abs(self:getRating() - opponent:getRating()) <= ALLOWABLE_RATING_SPREAD then
    result = opponent.glicko:score(matchOutcome)
  end

  return result
end

function PlayerRating:newRatingWithResults(gameResults)
  local updatedGlicko = self.glicko:update(gameResults)
  if updatedGlicko.RD > MAX_DEVIATION then
    updatedGlicko.RD = MAX_DEVIATION
  end
  if updatedGlicko.Vol > MAX_VOLATILITY then
    updatedGlicko.Vol = MAX_VOLATILITY
  end
  local updatedPlayer = self:copy()
  updatedPlayer.glicko = updatedGlicko
  return updatedPlayer
end


return PlayerRating
