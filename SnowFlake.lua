local logger = require("logger")

local snowImages = {}
local snowflakes = {} -- this will hold all flakes
local snowSpawnTimer = 0
local maxSnowFlakes = 10000
local snowFlakesPerSecond = 2000
local snowFlakeSpawnSpeed = 1 / snowFlakesPerSecond -- a snow flake is created once every this amount of seconds

local minSnowIntensity = 0.05
local maxSnowIntensity = 1
local snowIntensity = ((maxSnowIntensity - minSnowIntensity) / 2) + minSnowIntensity
local snowIntensityVelocity = 0.8
local minSnowIntensityVelocity = -0.05
local maxSnowIntensityVelocity = 0.05
local snowIntensityVelocityChangePerSecond = 0.05

local peakWindDepth = 0.5 -- the depth that has the most 'wind' which cause more x movement
local peakWindDepthVelocity = 0
local minWindSpeedVelocity = -20
local maxWindSpeedVelocity = 20
local minWindSpeed = -100
local maxWindSpeed = 200
local maxWindChangePerSecond = 0.2
local maxWindSpeedChangePerSecond = 10
local windSpeedVelocity = 0
local windSpeed = ((maxWindSpeed - minWindSpeed) / 2) + minWindSpeed

local minDX = 0
local maxDX = 100
local maxScale = 1/4

local maxX = 1280
local maxY = 720

local function pickRandomScale()
  local randomValue = love.math.random()
  local maxSize = 6
  local scalePick = maxSize
  if randomValue < 0.7 then
    scalePick = 1
  elseif randomValue < 0.9 then
    scalePick = 2
  elseif randomValue < 0.95 then
    scalePick = 3
  elseif randomValue < 0.98 then
    scalePick = 4
  elseif randomValue < 0.995 then
    scalePick = 5
  end
  local scale = scalePick / maxSize * snowIntensity * maxScale
  return scale
end

-- A visual representation of a snow flake with transparency and movement.
SnowFlake =
  class(
  function(self)
    local scale = pickRandomScale()
    local percentScale = (scale / maxScale)
    local percentScaleInverted = 1 - percentScale
    local dx = (maxDX - minDX) / 2 + minDX --love.math.random(minDX, maxDX)
    local depth = love.math.random()
    local dy = (percentScaleInverted ^ 1.5) * 40 + (depth * 120) + 60

    self.flakeImageIndex = love.math.random(1, 8) -- image to use
    local maxRotationVelocity = 0.2
    self.rotationVelocity = love.math.random() * maxRotationVelocity * 2 - maxRotationVelocity
    self.rotation = 0 -- current rotation
    self.scale = scale -- flake scale
    self.x = love.math.random(-300, maxX) -- x coordinate
    self.y = -50 -- y coordinate, starts offscreen at the top
    self.depth = depth
    self.dx = dx
    self.dy = dy
    self.alpha = love.math.random() * 0.2 + 0.5 + .3 * snowIntensity
  end
)

function SnowFlake.loadImages()
  for x = 1, 8 do
    snowImages[x] = love.graphics.newImage('/images/snow' .. x .. '.png')
  end
end

function SnowFlake.flakeCount()
  return #snowflakes
end

function SnowFlake.windSpeed()
  return windSpeed
end

function SnowFlake.peakWindDepth()
  return peakWindDepth
end

function SnowFlake.windSpeedVelocity()
  return windSpeedVelocity
end

function SnowFlake.peakWindDepthVelocity()
  return peakWindDepthVelocity
end

function SnowFlake.snowIntensity()
  return snowIntensity
end

function SnowFlake.snowIntensityVelocity()
  return snowIntensityVelocity
end

function SnowFlake.randomizeIntensity(seed)
  love.math.setRandomSeed(seed)
  snowIntensity = love.math.random() * (maxSnowIntensity - minSnowIntensity) + minSnowIntensity
end

function SnowFlake.updateIntensity(dt)
  local change = ((love.math.random() * snowIntensityVelocityChangePerSecond * 2) - snowIntensityVelocityChangePerSecond) * dt
  snowIntensityVelocity = snowIntensityVelocity + change
  snowIntensityVelocity = math.min(snowIntensityVelocity, maxSnowIntensityVelocity)
  snowIntensityVelocity = math.max(snowIntensityVelocity, minSnowIntensityVelocity)

  snowIntensity = snowIntensity + snowIntensityVelocity * dt
  snowIntensity = math.min(snowIntensity, maxSnowIntensity)
  snowIntensity = math.max(snowIntensity, minSnowIntensity)
end

function SnowFlake.updateWind(dt)
  local currentWindIntensity = snowIntensity
  local peakWindChange = ((currentWindIntensity * maxWindChangePerSecond * 2) - maxWindChangePerSecond) * dt

  peakWindDepthVelocity = peakWindDepthVelocity + peakWindChange
  peakWindDepthVelocity = math.min(peakWindDepthVelocity, 0.2)
  peakWindDepthVelocity = math.max(peakWindDepthVelocity, -0.2)

  peakWindDepth = peakWindDepth + peakWindDepthVelocity * dt
  peakWindDepth = math.min(peakWindDepth, 1)
  peakWindDepth = math.max(peakWindDepth, 0)

  local windSpeedChange = ((currentWindIntensity * maxWindSpeedChangePerSecond * 2) - maxWindSpeedChangePerSecond) * dt
  windSpeedVelocity = windSpeedVelocity + windSpeedChange 
  windSpeedVelocity = math.min(windSpeedVelocity, maxWindSpeedVelocity)
  windSpeedVelocity = math.max(windSpeedVelocity, minWindSpeedVelocity)

  windSpeed = windSpeed + windSpeedVelocity * dt
  windSpeed = math.min(windSpeed, maxWindSpeed)
  windSpeed = math.max(windSpeed, minWindSpeed)
end

function SnowFlake.updateFlakes(dt)

	snowSpawnTimer = snowSpawnTimer + dt

  SnowFlake.updateIntensity(dt)
  SnowFlake.updateWind(dt)

	for x = #snowflakes, 1, -1 do --iterate over all snowflakes, updating...
    local flake = snowflakes[x]
    flake:update(dt)
		if flake.y > maxY + 50 then -- snowflake is offscreen at bottom, it will be destroyed
			table.remove(snowflakes, x)
		end
	end
  local currentSnowFlakeSpawnSpeed = snowFlakeSpawnSpeed / snowIntensity
	while #snowflakes < maxSnowFlakes and snowSpawnTimer > currentSnowFlakeSpawnSpeed do
    snowSpawnTimer = snowSpawnTimer - currentSnowFlakeSpawnSpeed
	  snowflakes[#snowflakes + 1] = SnowFlake()
	end
end

function SnowFlake:update(dt)
  local depthDistance = math.abs(peakWindDepth - self.depth)
  local dxChange = windSpeed * depthDistance * dt
  self.dx = self.dx + dxChange
  self.dx = math.min(self.dx, maxDX)
  self.dx = math.max(self.dx, minDX)
  self.x = self.x + (self.dx * dt) -- x position, flakes slowly drift to the right at random velocity
  self.y = self.y + (self.dy * dt) -- y position
  self.rotation = self.rotation + (self.rotationVelocity * dt) -- current rotation
  if self.x > 1970 then -- snowflake is offscreen on the right, it will reappear on the left
    self.x = -40
  end
end

function SnowFlake.drawFlakes()

	for _, flake in ipairs(snowflakes) do
    flake:draw()
	end

  love.graphics.setColor(1, 1, 1, 1)
end

function SnowFlake:draw()
  love.graphics.setColor(1, 1, 1, self.alpha)
  local snowImage = snowImages[self.flakeImageIndex]
  love.graphics.draw(snowImage,
  self.x,
  self.y,
  self.rotation,
  self.scale,
  self.scale,
  snowImage:getWidth() / 2,
  snowImage:getHeight() / 2)
end
