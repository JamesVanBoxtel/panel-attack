local logger = require("logger")
local Health = require("Health")
require("queue")

-- A simulated stack sends attacks and takes damage from a player, it "loses" if it takes too many attacks.
SimulatedStack =
  class(
  function(self, playerNumber, character)
    self:moveForPlayerNumber(playerNumber)
    self.framesBehindArray = {}
    self.framesBehind = 0
    self.clock = 0
    self.character = CharacterLoader.resolveCharacterSelection(character)
    self.rollbackCopies = {}
    self.rollbackCopyPool = Queue()
    self.panels_dir = config.panels
    CharacterLoader.load(self.character)
    CharacterLoader.wait()
  end
)

function SimulatedStack:moveForPlayerNumber(playerNumber)
  -- Position of elements should ideally be on even coordinates to avoid non pixel alignment
  if playerNumber == 1 then
    self.mirror_x = 1
  elseif playerNumber == 2 then
    self.mirror_x = -1
  end
  local centerX = (canvas_width / 2)
  local stackWidth = self:stackCanvasWidth()
  local innerStackXMovement = 100
  local outerStackXMovement = stackWidth + innerStackXMovement
  local frameOriginNonScaled = centerX - (outerStackXMovement * self.mirror_x)
  if self.mirror_x == -1 then
    frameOriginNonScaled = frameOriginNonScaled - stackWidth
  end
  self.frameOriginX = frameOriginNonScaled / GFX_SCALE -- The left X value where the frame is drawn
  self.frameOriginY = 108 / GFX_SCALE
end

-- adds an attack engine to the simulated opponent
function SimulatedStack:addAttackEngine(attackSettings, shouldPlayAttackSfx)
  self.telegraph = Telegraph(self)

  if shouldPlayAttackSfx then
    self.attackEngine = AttackEngine(attackSettings, self.telegraph, characters[self.character])
  else
    self.attackEngine = AttackEngine(attackSettings, self.telegraph)
  end

  return self.attackEngine
end

function SimulatedStack:addHealth(healthSettings)
  self.health = Health(
    healthSettings.secondsToppedOutToLose,
    healthSettings.lineClearGPM,
    healthSettings.lineHeightToKill,
    healthSettings.riseSpeed
  )
end

function SimulatedStack:stackCanvasWidth()
  return 288
end

function SimulatedStack:run()
  if self.health then
    self.health:run()
  end
  if not self:game_ended() then
    if self.attackEngine then
      self.attackEngine:run()
    end
    self.clock = self.clock + 1
  end
end

function SimulatedStack:shouldRun(runsSoFar)
  return runsSoFar < 1
end

function SimulatedStack:game_ended()
  if not self.health then
    return false
  end
  return self.health:isFullyDepleted()
end

function SimulatedStack:drawCharacter()
  local characterObject = characters[self.character]
  characterObject:drawPortrait(2, self.frameOriginX, self.frameOriginY, 0)
end

local healthBarXOffset = -56
function SimulatedStack.render(self)

  if self.health then
    self:drawCharacter()
    self.health:render(self.frameOriginX * GFX_SCALE + healthBarXOffset)
  end

  if self.attackEngine then
    self.attackEngine:render()
  end

end

function SimulatedStack:receiveGarbage(frameToReceive, garbageList)
  if self.health and self.health:isFullyDepleted() == false then
    self.health:receiveGarbage(frameToReceive, garbageList)
  end
end

function SimulatedStack:saveForRollback()
  local copy = {}

  if self.health then
    self.health:saveRollbackCopy()
  end

  if self.telegraph then
    -- this is pretty stupid, telegraph should just save its own rollback on itself
    -- so that when rollback happens we just telegraph:rollbackToFrame
    copy.telegraph = self.telegraph:rollbackCopy()
  end

  self.rollbackCopies[self.clock] = copy
end

function SimulatedStack:rollbackToFrame(frame)
  local copy = self.rollbackCopies[frame]

  if copy then
    if self.telegraph then
      copy.telegraph:rollbackCopy(self.telegraph)
    end
  end

  if self.health then
    self.health:rollbackToFrame(frame)
  end
end

function SimulatedStack:starting_state()
end

function SimulatedStack:setGarbageTarget(garbageTarget)
  if garbageTarget ~= nil then
    assert(garbageTarget.frameOriginX ~= nil)
    assert(garbageTarget.frameOriginY ~= nil)
    assert(garbageTarget.mirror_x ~= nil)
    assert(garbageTarget.stackCanvasWidth ~= nil)
    assert(garbageTarget.receiveGarbage ~= nil)
  end
  self.garbageTarget = garbageTarget
  if self.telegraph then
    self.attackEngine:setGarbageTarget(garbageTarget)
    self.telegraph:updatePositionForGarbageTarget(garbageTarget)
  end
end

return SimulatedStack