local Scene = require("scenes.Scene")
local tableUtils = require("tableUtils")
local TextButton = require("ui.TextButton")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local sceneManager = require("scenes.sceneManager")
local Menu = require("ui.Menu")
local consts = require("consts")
local input = require("inputManager")
local joystickManager = require("joystickManager")
local util = require("util")
local class = require("class")

--@module inputConfigMenu
-- Scene for configuring input
local InputConfigMenu = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_main
    self.settingKey = false
    self.menu = nil -- set in load
    
    self:load(sceneParams)
  end,
  Scene
)

InputConfigMenu.name = "InputConfigMenu"
sceneManager:addScene(InputConfigMenu)

-- Sometimes controllers register buttons as "pressed" even though they aren't. If they have been pressed longer than this they don't count.
local MAX_PRESS_DURATION = 0.5
local KEY_NAME_LABEL_WIDTH = 180
local PADDING = 8
local pendingInputText = "__"

local function shortenControllerName(name)
  local nameToShortName = {
    ["Nintendo Switch Pro Controller"] = "Switch Pro Con"
  }
  return nameToShortName[name] or name
end

-- Represents the state of love.run while the key in isDown/isUp is active
-- NOT_SETTING: when we are not polling for a new key
-- SETTING_KEY_TRANSITION: skip a frame so we don't use the button activation key as the configured key
-- SETTING_KEY: currently polling for a single key
-- SETTING_ALL_KEYS: currently polling for all keys
-- This is only used within this file, external users should simply treat isDown/isUp as a boolean
local KEY_SETTING_STATE = { NOT_SETTING = nil, SETTING_KEY_TRANSITION = 1, SETTING_KEY = 2, SETTING_ALL_KEYS_TRANSITION = 3, SETTING_ALL_KEYS = 4 }

function InputConfigMenu:setSettingKeyState(keySettingState)
  self.settingKey = keySettingState ~= KEY_SETTING_STATE.NOT_SETTING
  self.settingKeyState = keySettingState
  self.menu:setEnabled(not self.settingKey)
end

function InputConfigMenu:getKeyDisplayName(key)
  local keyDisplayName = key
  if key and string.match(key, ":") then
    local controllerKeySplit = util.split(key, ":")
    local controllerName = shortenControllerName(joystickManager.guidToName[controllerKeySplit[1]] or "Unplugged Controller")
    keyDisplayName = string.format("%s (%s-%s)", controllerKeySplit[3], controllerName, controllerKeySplit[2])
  end
  return keyDisplayName or loc("op_none")
end

function InputConfigMenu:updateInputConfigMenuLabels(index)
  self.configIndex = index
  for i, key in ipairs(consts.KEY_NAMES) do
    local keyDisplayName = self:getKeyDisplayName(GAME.input.inputConfigurations[self.configIndex][key])
    self:currentKeyLabelForIndex(i + 1):setText(keyDisplayName)
  end
end

function InputConfigMenu:updateKey(key, pressedKey, index)
  Menu.playValidationSfx()
  GAME.input.inputConfigurations[self.configIndex][key] = pressedKey
  local keyDisplayName = self:getKeyDisplayName(pressedKey)
  self:currentKeyLabelForIndex(index + 1):setText(keyDisplayName)
  write_key_file()
end

function InputConfigMenu:setKey(key, index)
  local pressedKey = next(input.allKeys.isDown)
  if pressedKey then
    self:updateKey(key, pressedKey, index)
    self:setSettingKeyState(KEY_SETTING_STATE.NOT_SETTING)
  end
end

function InputConfigMenu:setAllKeys()
  local pressedKey = next(input.allKeys.isDown)
  if pressedKey then
    self:updateKey(consts.KEY_NAMES[self.index], pressedKey, self.index)
    if self.index < #consts.KEY_NAMES then
      self.index = self.index + 1
      self:currentKeyLabelForIndex(self.index + 1):setText(pendingInputText)
      self.menu.selectedIndex = self.index + 1
      self:setSettingKeyState(KEY_SETTING_STATE.SETTING_ALL_KEYS_TRANSITION)
    else
      self:setSettingKeyState(KEY_SETTING_STATE.NOT_SETTING)
    end
  end
end

function InputConfigMenu:currentKeyLabelForIndex(index)
  return self.menu.menuItems[index].children[2].children[1]
end

function InputConfigMenu:setKeyStart(key)
  Menu.playValidationSfx()
  self.key = key
  self.index = nil
  for i, k in ipairs(consts.KEY_NAMES) do
    if k == key then
      self.index = i
      break
    end
  end
  self:currentKeyLabelForIndex(self.index + 1):setText(pendingInputText)
  self.menu.selectedIndex = self.index + 1
  self:setSettingKeyState(KEY_SETTING_STATE.SETTING_KEY_TRANSITION)
end

function InputConfigMenu:setAllKeysStart()
  Menu.playValidationSfx()
  self.index = 1
  self:currentKeyLabelForIndex(self.index + 1):setText(pendingInputText)
  self.menu:setSelectedIndex(self.index + 1)
  self:setSettingKeyState(KEY_SETTING_STATE.SETTING_ALL_KEYS_TRANSITION)
end

function InputConfigMenu:clearAllInputs()
  Menu.playValidationSfx()
  for i, key in ipairs(consts.KEY_NAMES) do
    GAME.input.inputConfigurations[self.configIndex][key] = nil
    local keyName = loc("op_none")
    self:currentKeyLabelForIndex(i + 1):setText(keyName)
  end
  write_key_file()
end

function InputConfigMenu:resetToDefault(menuOptions) 
  Menu.playValidationSfx() 
  local i = 1 
  for keyName, key in pairs(input.defaultKeys) do 
    GAME.input.inputConfigurations[1][keyName] = key
    self:currentKeyLabelForIndex(i + 1):setText(GAME.input.inputConfigurations[1][keyName])
    i = i + 1 
  end
  for j = 2, input.maxConfigurations do
    for _, key in ipairs(consts.KEY_NAMES) do
      GAME.input.inputConfigurations[j][key] = nil
    end
  end
  Menu.playMoveSfx()
  self.slider:setValue(1)
  self:updateInputConfigMenuLabels(1)
  write_key_file() 
end

local function exitMenu()
  Menu.playValidationSfx()
  sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
end

function InputConfigMenu:load(sceneParams)
  self.configIndex = 1
  local menuOptions = {}
  self.slider = Slider({
    min = 1,
    max = input.maxConfigurations,
    value = 1,
    tickLength = 10,
    onValueChange = function(slider) self:updateInputConfigMenuLabels(slider.value) end})
  menuOptions[1] = Menu.createMenuItem(Label({text = "configuration"}), self.slider)
  for i, key in ipairs(consts.KEY_NAMES) do
    local clickFunction = function() 
      if not self.settingKey then
        self:setKeyStart(key)
      end
    end
    local keyName = self:getKeyDisplayName(GAME.input.inputConfigurations[self.configIndex][key])
    local keyNameButton = TextButton({
      width = KEY_NAME_LABEL_WIDTH,
      height = Menu.DEFAULT_BUTTON_HEIGHT,
      label = Label({
        text = key,
        translate = false
      }),
      onClick = clickFunction
    })
    local changeKeyButton = TextButton({
      x = keyNameButton.width + PADDING,
      vAlign = "center",
      width = KEY_NAME_LABEL_WIDTH,
      height = Menu.DEFAULT_BUTTON_HEIGHT,
      label = Label({
        text = keyName,
        translate = false
      }),
      onClick = clickFunction
    })
    keyNameButton:addChild(changeKeyButton)
    menuOptions[#menuOptions + 1] = Menu.createMenuItem(keyNameButton)
  end
  menuOptions[#menuOptions + 1] = Menu.createMenuItem(TextButton({label = Label({text = "op_all_keys"}),
    onClick = function() self:setAllKeysStart() end}))
  menuOptions[#menuOptions + 1] = Menu.createMenuItem(TextButton({label = Label({text = "Clear All Inputs", translate = false}),
    onClick = function() self:clearAllInputs() end}))
  menuOptions[#menuOptions + 1] = Menu.createMenuItem(TextButton({label = Label({text = "Reset Keys To Default", translate = false}),
    onClick = function() self:resetToDefault(menuOptions) end}))
  menuOptions[#menuOptions + 1] = Menu.createMenuItem(TextButton({label = Label({text = "back"}), onClick = exitMenu}))
  
  self.menu = Menu.createCenteredMenu(menuOptions)

  self.uiRoot:addChild(self.menu)

  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
end

function InputConfigMenu:update(dt)
  self.backgroundImg:update(dt)
  self.menu:update()

  local noKeysHeld = (tableUtils.first(input.allKeys.isPressed, function (value)
    return value < MAX_PRESS_DURATION
  end)) == nil

  if self.settingKeyState == KEY_SETTING_STATE.SETTING_KEY_TRANSITION then
    if noKeysHeld then
      self:setSettingKeyState(KEY_SETTING_STATE.SETTING_KEY)
    end
  elseif self.settingKeyState == KEY_SETTING_STATE.SETTING_ALL_KEYS_TRANSITION then
    if noKeysHeld then
      self:setSettingKeyState(KEY_SETTING_STATE.SETTING_ALL_KEYS)
    end
  elseif self.settingKeyState == KEY_SETTING_STATE.SETTING_KEY then
    self:setKey(self.key, self.index)
  elseif self.settingKeyState == KEY_SETTING_STATE.SETTING_ALL_KEYS then
    self:setAllKeys()
  end
end

function InputConfigMenu:draw()
  themes[config.theme].images.bg_main:draw()
  self.uiRoot:draw()
end

return InputConfigMenu