local logger = require("logger")

local snowImages = {}
local snowSpawnTimer = 0
local snowflakes = {} -- this will hold all flakes

local minDX = 0
local maxDX = 10
local maxScale = 1 / 8

local maxX = 1280
local maxY = 720

local function pickRandomScale()
  local randomValue = math.random()
  local scalePick = 1
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
  else
    scalePick = 6
  end
  local maxSize = 8
  local scale = scalePick / maxSize * maxScale
  return scale
end

-- A visual representation of a snow flake with transparency and movement.
SnowFlake =
  class(
  function(self)
    local depth = math.random() * 40 + 140
    local scale = pickRandomScale()
    local percentScale = (scale / maxScale)
    local percentScaleInverted = 1 - percentScale
    local dx = love.math.random(minDX, maxDX)
    local dy = (percentScaleInverted ^ 1.5) * 40 + depth

    self.flakeImageIndex = love.math.random(1, 8) -- image to use
    local maxRotationVelocity = 0.2
    self.rotationVelocity = love.math.random() * maxRotationVelocity * 2 - maxRotationVelocity
    self.rotation = 0 -- current rotation
    self.scale = scale -- flake scale
    self.x = love.math.random(0, maxX) -- x coordinate
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

function SnowFlake.updateFlakes(dt)

	snowSpawnTimer = snowSpawnTimer + dt

	for x = #snowflakes, 1, -1 do --iterate over all snowflakes, updating...
    local flake = snowflakes[x]
    flake:update(dt)
		if flake.y > maxY + 50 then -- snowflake is offscreen at bottom, it will be destroyed
			table.remove(snowflakes, x)
		end
	end
  local spawnSpeed = 0.0002
	if #snowflakes < 5000 and snowSpawnTimer > spawnSpeed then
    snowSpawnTimer = snowSpawnTimer - spawnSpeed
	  snowflakes[#snowflakes + 1] = SnowFlake()
	end
end

function SnowFlake:update(dt)
  self.dx = self.dx + love.math.random(-1, 1)
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
