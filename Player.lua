local class = require("class")
local GameModes = require("GameModes")
local LevelPresets = require("LevelPresets")
local input = require("inputManager")

-- A player is mostly a data representation of a Panel Attack player
-- It holds data pertaining to their online status (like name, public id)
-- It holds data pertaining to their client status (like character, stage, panels, level etc)
-- Player implements a lot of setters that feed into an observer-like pattern, notifying possible subscribers about property changes
-- Due to this, unless for a good reason, all properties on Player should be set using the setters
local Player = class(function(self, name, publicId, isLocal)
  self.name = name
  self.wins = 0
  self.modifiedWins = 0
  self.settings = {
    -- these need to all be initialized so subscription works
    level = 1,
    difficulty = 1,
    speed = 1,
    levelData = LevelPresets.getModern(1),
    style = GameModes.Styles.MODERN,
    characterId = "",
    stageId = "",
    panelId = "",
    wantsReady = false,
    wantsRanked = true,
    inputMethod = "controller"
  }
  -- planned for the future, players don't have public ids yet
  self.publicId = publicId or -1
  self.trainingModeSettings = nil
  self.rating = nil
  self.stack = nil
  self.playerNumber = nil
  self.isLocal = isLocal or false
  -- a player has only one configuration at a time
  -- this is either keys or a single input configuration
  self.inputConfiguration = input.allKeys
  self.subscriptionList = {}
end)

-- returns the count of wins modified by the `modifiedWins` property
function Player:getWinCountForDisplay()
  return self.wins + self.modifiedWins
end

function Player:setWinCount(count)
  self.wins = count
end

function Player:incrementWinCount()
  self.wins = self.wins + 1
end

-- creates a stack for the given match according to the player's settings and returns it
-- the stack is also saved as a reference on player
function Player:createStackFromSettings(match, which)
  local args = {}
  args.which = which
  args.player_number = self.playerNumber
  args.match = match
  args.is_local = self.isLocal
  args.panels_dir = self.settings.panelId
  args.character = self.settings.characterId
  if self.settings.style == GameModes.Styles.MODERN then
    args.level = self.settings.level
    if match.battleRoom.mode.stackInteraction == GameModes.StackInteraction.NONE then
      args.allowAdjacentColors = true
    else
      args.allowAdjacentColors = args.level < 8
    end
  else
    args.difficulty = self.settings.difficulty
    args.allowAdjacentColors = true
  end

  args.levelData = self.settings.levelData

  if match.isFromReplay and self.settings.allowAdjacentColors ~= nil then
    args.allowAdjacentColors = self.settings.allowAdjacentColors
  end
  args.inputMethod = self.settings.inputMethod

  self.stack = Stack(args)

  return self.stack
end

function Player:getRatingDiff()
  return self.rating.new - self.rating.old
end

-- Other elements (ui, network) can subscribe to properties in Player.settings by passing a callback
function Player:subscribe(subscriber, property, callback)
  if self.settings[property] ~= nil then
    if not self.subscriptionList[property] then
      self.subscriptionList[property] = {}
    end
    self.subscriptionList[property][subscriber] = callback
    return true
  end

  return false
end

function Player:unsubscribe(subscriber, property)
  if property then
    self.subscriptionList[property][subscriber] = nil
  else
    -- if no property is given, unsubscribe everything for that subscriber
    for property, _ in pairs(self.subscriptionList) do
      self.subscriptionList[property][subscriber] = nil
    end
  end
end

-- the callback is executed with the new property value as the argument whenever a property is modified via its setter
function Player:onPropertyChanged(property)
  if self.subscriptionList[property] then
    for subscriber, callback in pairs(self.subscriptionList[property]) do
      callback(subscriber, self.settings[property])
    end
  end
end

function Player:setStage(stageId)
  if stageId ~= self.settings.stageId then
    stageId = StageLoader.resolveStageSelection(stageId)
    self.settings.stageId = stageId
    StageLoader.load(stageId)

    self:onPropertyChanged("stageId")
  end
end

function Player:setCharacter(characterId)
  if characterId ~= self.settings.characterId then
    characterId = CharacterLoader.resolveCharacterSelection(characterId)
    self.settings.characterId = characterId
    CharacterLoader.load(characterId)

    self:onPropertyChanged("characterId")
  end
end

function Player:setPanels(panelId)
  if panelId ~= self.settings.panelId then
    if panels[panelId] then
      self.settings.panelId = panelId
    else
      -- default back to config panels always
      self.settings.panelId = config.panels
    end
    -- panels are always loaded so no loading is necessary

    self:onPropertyChanged("panelId")
  end
end

function Player:setWantsRanked(wantsRanked)
  if wantsRanked ~= self.settings.wantsRanked then
    self.settings.wantsRanked = wantsRanked
    self:onPropertyChanged("wantsRanked")
  end
end

function Player:setWantsReady(wantsReady)
  if wantsReady ~= self.settings.wantsReady then
    self.settings.wantsReady = wantsReady
    self:onPropertyChanged("wantsReady")
  end
end

function Player:setLoaded(hasLoaded)
  -- loaded is only set for non-local players to determine if they are ready for the match
  -- the battleRoom is in charge of checking whether all assets have been loaded locally
  if not self.isLocal then
    if hasLoaded ~= self.settings.hasLoaded then
      self.settings.hasLoaded = hasLoaded
      self:onPropertyChanged("hasLoaded")
    end
  end
end

function Player:setDifficulty(difficulty)
  if difficulty ~= self.settings.difficulty then
    self.settings.difficulty = difficulty
    self:setLevelData(LevelPresets.getClassic(difficulty))
    self:onPropertyChanged("difficulty")
  end
end

function Player:setLevelData(levelData)
  self.settings.levelData = levelData
  self:onPropertyChanged("levelData")
end

function Player:setSpeed(speed)
  if speed ~= self.settings.speed or speed ~= self.settings.levelData.startingSpeed then
    self.settings.levelData.startingSpeed = speed
    self.settings.speed = speed
    self:onPropertyChanged("speed")
  end
end

function Player:setColorCount(colorCount)
  if colorCount ~= self.settings.colorCount or colorCount ~= self.settings.levelData.colors  then
    self.settings.levelData.colors = colorCount
    self.settings.colorCount = colorCount
    self:onPropertyChanged("colorCount")
  end
end

function Player:setLevel(level)
  if level ~= self.settings.level then
    self.settings.level = level
    self:setLevelData(LevelPresets.getModern(level))
    self:onPropertyChanged("level")
  end
end

function Player:setInputMethod(inputMethod)
  if inputMethod ~= self.settings.inputMethod then
    self.settings.inputMethod = inputMethod
    self:onPropertyChanged("inputMethod")
  end
end

-- sets the style of "level" presets the player selects from
-- 1 = classic
-- 2 = modern
function Player:setStyle(style)
  if style ~= self.settings.style then
    self.settings.style = style
    if style == GameModes.Styles.MODERN then
      self:setLevelData(LevelPresets.getModern(self.settings.level or config.level))
    else
      self:setLevelData(LevelPresets.getClassic(self.settings.difficulty or config.difficulty))
      self:setSpeed(self.settings.speed)
    end
    -- reset color count while we don't have an established caching mechanism for it
    self:setColorCount(self.settings.levelData.colors)
    self:onPropertyChanged("style")
  end
end

function Player:setPuzzleSet(puzzleSet)
  if puzzleSet ~= self.settings.puzzleSet then
    self.settings.puzzleSet = puzzleSet
    self:onPropertyChanged("puzzleSet")
  end
end

function Player:restrictInputs(inputConfiguration)
  if inputConfiguration.usedByPlayer ~= nil and inputConfiguration.usedByPlayer ~= self then
    error("Trying to assign input configuration to player " .. self.playerNumber ..
      " that is already in use by player " .. inputConfiguration.usedByPlayer.playerNumber)
  end
  self.inputConfiguration = inputConfiguration
  self.inputConfiguration.usedByPlayer = self
end

function Player:unrestrictInputs()
  self.inputConfiguration.usedByPlayer = nil
  self.inputConfiguration = input.allKeys
end

function Player.getLocalPlayer()
  local player = Player(config.name)

  player:setDifficulty(config.endless_difficulty)
  player:setSpeed(config.endless_speed)
  player:setLevel(config.level)
  player:setCharacter(config.character)
  player:setStage(config.stage)
  player:setPanels(config.panels)
  player:setWantsReady(false)
  player:setWantsRanked(config.ranked)
  player:setInputMethod(config.inputMethod)
  if config.endless_level then
    player:setStyle(GameModes.Styles.MODERN)
  else
    player:setStyle(GameModes.Styles.CLASSIC)
  end

  player.isLocal = true

  return player
end

function Player:updateWithMenuState(menuState)
  if characters[menuState.characterId] then
    -- if we have their character, use it
    self:setCharacter(menuState.characterId)
  elseif menuState.selectedCharacterId and characters[menuState.selectedCharacterId] then
    -- if we don't have their character rolled from their bundle, but the bundle itself, use that
    -- very unlikely tbh
    self:setCharacter(menuState.selectedCharacterId)
  elseif self.settings.characterId == "" then
    -- we don't have their character and we didn't roll them a random character yet
    self:setCharacter(random_character_special_value)
  end

  if stages[menuState.stageId] then
    -- if we have their stage, use it
    self:setStage(menuState.stageId)
  elseif menuState.selectedStageId and stages[menuState.selectedStageId] then
    -- if we don't have their stage rolled from their bundle, but the bundle itself, use that
    -- very unlikely tbh
    self:setStage(menuState.selectedStageId)
  elseif self.settings.stageId == "" then
    -- we don't have their stage and we didn't roll them a random stage yet
    self:setStage(random_stage_special_value)
  end

  self:setWantsRanked(menuState.wantsRanked)
  if menuState.panelId then
    -- panelId may be absent in some messages due to a server bug
    self:setPanels(menuState.panelId)
  end

  self:setLevel(menuState.level)
  self:setInputMethod(menuState.inputMethod)
end

return Player