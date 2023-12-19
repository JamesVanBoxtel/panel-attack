local Scene = require("scenes.Scene")
local TextButton = require("ui.TextButton")
local Label = require("ui.Label")
local consts = require("consts")
local Menu = require("ui.Menu")
local sceneManager = require("scenes.sceneManager")
local GraphicsUtil = require("graphics_util")
local class = require("class")
local GameModes = require("GameModes")

-- @module MainMenu
-- Scene for the main menu
local MainMenu = class(function(self, sceneParams)
  self.menu = nil -- set in load
  self.backgroundImg = themes[config.theme].images.bg_main
  self:load(sceneParams)
end, Scene)

MainMenu.name = "MainMenu"
sceneManager:addScene(MainMenu)

local function switchToScene(scene, sceneParams)
  Menu.playValidationSfx()
  sceneManager:switchToScene(scene, sceneParams)
end

local BUTTON_WIDTH = 140
local function createMainMenuButton(text, onClick, extraLabels, translate)
  if translate == nil then
    translate = true
  end
  return TextButton({label = Label({text = text, extraLabels = extraLabels, translate = translate, hAlign = "center", vAlign = "center"}), onClick = onClick, width = BUTTON_WIDTH})
end

local menuItems = {
  {
    createMainMenuButton("mm_1_endless", function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_ENDLESS"))
      switchToScene("EndlessMenu", {battleRoom = GAME.battleRoom})
    end)
  }, {
    createMainMenuButton("mm_1_puzzle", function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_PUZZLE"))
      switchToScene("PuzzleMenu", {battleRoom = GAME.battleRoom})
    end)
  }, {
    createMainMenuButton("mm_1_time", function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_TIME_ATTACK"))
      switchToScene("TimeAttackMenu", {battleRoom = GAME.battleRoom})
    end)
  }, {
    createMainMenuButton("mm_1_vs", function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_VS_SELF"))
      switchToScene("CharacterSelectVsSelf", {battleRoom = GAME.battleRoom})
    end)
  }, {
    createMainMenuButton("mm_1_training", function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_TRAINING"))
      switchToScene("TrainingMenu", {battleRoom = GAME.battleRoom})
    end)
  }, {
    createMainMenuButton("mm_1_challenge_mode", function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_CHALLENGE"))
      switchToScene("ChallengeModeMenu", {battleRoom = GAME.battleRoom})
    end)
  }, {
    createMainMenuButton("mm_2_vs_online", function()
      switchToScene("Lobby", {serverIp = "panelattack.com"})
    end, {""})
  }, {
    createMainMenuButton("mm_2_vs_local", function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("TWO_PLAYER_VS"))
      switchToScene("CharacterSelectLocal2p", {battleRoom = GAME.battleRoom})
    end)
  }, {
    createMainMenuButton("mm_replay_browser", function()
      switchToScene("ReplayBrowser")
    end)
  }, {
    createMainMenuButton("mm_configure", function()
      switchToScene("InputConfigMenu")
    end)
  }, {
    createMainMenuButton("mm_set_name", function()
      Menu.playValidationSfx()
      sceneManager:switchToScene("SetNameMenu", {prevScene = "MainMenu"})
    end)
  }, {
    createMainMenuButton("mm_options", function()
      switchToScene("OptionsMenu")
    end)
  }, {
    createMainMenuButton("mm_fullscreen", function()
      Menu.playValidationSfx()
      love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
    end, {"\n(Alt+Enter)"})
  }, {createMainMenuButton("mm_quit", love.event.quit)}
}

local debugMenuItems = {
  {createMainMenuButton("Beta Server", switchToScene("Lobby", {serverIp = "betaserver.panelattack.com", serverPort = 59569}), {""}, false)},
  {createMainMenuButton("Localhost Server", switchToScene("Lobby", {serverIp = "Localhost"}), {""}, false)}
}

function MainMenu:addDebugMenuItems()
  if config.debugShowServers then
    for i, menuItem in ipairs(debugMenuItems) do
      self.menu:addMenuItem(i + 7, menuItem)
    end
  end
  if config.debugShowDesignHelper then
    self.menu:addMenuItem(#self.menu.menuItems, {
      createMainMenuButton("Design Helper", function()
        switchToScene("DesignHelper")
      end)
    })
  end
end

function MainMenu:removeDebugMenuItems()
  for i, menuItem in ipairs(debugMenuItems) do
    self.menu:removeMenuItem(menuItem[1].id)
  end
end

function MainMenu:load(sceneParams)
  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  self.menu = Menu({
    x = (consts.CANVAS_WIDTH / 2) - BUTTON_WIDTH / 2,
    y = y,
    menuItems = menuItems,
    maxHeight = themes[config.theme].main_menu_max_height
  })
  self.menu:setVisibility(true)

  self:addDebugMenuItems()

  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  CharacterLoader.clear()
  StageLoader.clear()
  GAME.tcpClient:resetNetwork()
  GAME.battleRoom = nil
  --GAME.input:clearInputConfigurationsForPlayers()
  --GAME.input:requestPlayerInputConfigurationAssignments(1)
  match_type_message = ""
end

function MainMenu:update(dt)
  if wait_game_update ~= nil then
    has_game_update = wait_game_update:pop()
    if has_game_update ~= nil and has_game_update then
      wait_game_update = nil
      GAME_UPDATER_GAME_VERSION = "NEW VERSION FOUND! RESTART THE GAME!"
    end
  end

  self.backgroundImg:update(dt)
  self.menu:update()
end

function MainMenu:draw()
  self.backgroundImg:draw()
  self.menu:draw()
  local fontHeight = GraphicsUtil.getGlobalFont():getHeight()
  local infoYPosition = 705 - fontHeight / 2

  local loveString = GAME:loveVersionString()
  if loveString == "11.3.0" then
    gprintf(loc("love_version_warning"), -5, infoYPosition, canvas_width, "right")
    infoYPosition = infoYPosition - fontHeight
  end

  if GAME_UPDATER_GAME_VERSION then
    gprintf("PA Version: " .. GAME_UPDATER_GAME_VERSION, -5, infoYPosition, canvas_width, "right")
    infoYPosition = infoYPosition - fontHeight
    if has_game_update then
      menu_draw(panels[config.panels].images.classic[1][1], 1262, 685)
    end
  end
end

function MainMenu:unload()
  self.menu:setVisibility(false)
end

return MainMenu
