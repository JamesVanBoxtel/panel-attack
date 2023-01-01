require("class")
socket = require("socket")
GAME = require("game")
require("match")
local manualGC = require("libraries.batteries.manual_gc")
local RunTimeGraph = require("RunTimeGraph")
require("BattleRoom")
require("util")
require("table_util")
local consts = require("consts")
require("FileUtil")
require("queue")
require("globals")
require("character_loader") -- after globals!
require("stage") -- after globals!
require("save")
require("engine/GarbageQueue")
require("engine/telegraph")
require("engine")
require("AttackEngine")
require("localization")
require("graphics")
GAME.input = require("input")
require("replay")
require("network")
require("Puzzle")
require("PuzzleSet")
require("puzzles")
require("mainloop")
require("sound")
require("timezones")
require("gen_panels")
require("panels")
require("theme")
require("click_menu")
require("computerPlayers.computerPlayer")
require("rich_presence.RichPresence")

if PROFILING_ENABLED then
  GAME.profiler = require("profiler")
end

local logger = require("logger")
GAME.scores = require("scores")
GAME.rich_presence = RichPresence()


local last_x = 0
local last_y = 0
local input_delta = 0.0
local pointer_hidden = false
local mainloop = nil

local server = nil
function love.load()
  server = require("server.server")
end

function love.update(dt)
  server:update()
end
