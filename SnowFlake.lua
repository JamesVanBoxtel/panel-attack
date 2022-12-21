local logger = require("logger")

local snowImages = {}
local snowflakes = {} -- this will hold all flakes
local snowSpawnTimer = 0
local maxSnowFlakes = 5000
local snowFlakesPerSecond = 600
local snowFlakeSpawnSpeed = 1 / snowFlakesPerSecond -- a snow flake is created once every this amount of seconds

local peakWindDepth = 0 -- the depth that has the most 'wind' which cause more x movement
local minWindSpeed = 0
local maxWindSpeed = 300
local maxWindChangePerSecond = 0.2
local maxWindSpeedChangePerSecond = 100
local windSpeedVelocity = 0
local windSpeed = maxWindSpeed / 2

local minDX = 0
local maxDX = 100
local maxScale = 1/8

local maxX = 1280
local maxY = 720

local function pickRandomScale()
  local randomValue = math.random()
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
  local scale = scalePick / maxSize * maxScale
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
    local depth = 0.5 -- math.random()
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
    self.alpha = math.random() * 0.2 + 0.5
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

function SnowFlake.updateWind(dt)
  local peakWindChange = ((math.random() * maxWindChangePerSecond * 2) - maxWindChangePerSecond) * dt
  peakWindDepth = peakWindDepth + peakWindChange
  while peakWindDepth < 0 do
    peakWindDepth = peakWindDepth + 1
  end
  if peakWindDepth > 1 then
    peakWindDepth = peakWindDepth % 1
  end

  local windSpeedChange = ((math.random() * maxWindSpeedChangePerSecond * 2) - maxWindSpeedChangePerSecond) * dt
  windSpeed = windSpeed + windSpeedChange
  windSpeed = math.min(windSpeed, maxWindSpeed)
  windSpeed = math.max(windSpeed, minWindSpeed)
end

function SnowFlake.updateFlakes(dt)

	snowSpawnTimer = snowSpawnTimer + dt

  SnowFlake.updateWind(dt)

	for x = #snowflakes, 1, -1 do --iterate over all snowflakes, updating...
    local flake = snowflakes[x]
    flake:update(dt)
		if flake.y > maxY + 50 then -- snowflake is offscreen at bottom, it will be destroyed
			table.remove(snowflakes, x)
		end
	end
	while #snowflakes < maxSnowFlakes and snowSpawnTimer > snowFlakeSpawnSpeed do
    snowSpawnTimer = snowSpawnTimer - snowFlakeSpawnSpeed
	  snowflakes[#snowflakes + 1] = SnowFlake()
	end
end

function SnowFlake:update(dt)
  local depthDistance = math.abs(peakWindDepth - self.depth)
  local dxChange = windSpeed * depthDistance
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
