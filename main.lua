local launch_type = arg[2]
if launch_type == "test" or launch_type == "debug" then
    require "lldebugger"
    TESTS_ENABLED = 1
    if launch_type == "debug" then
        lldebugger.start()
    end
end
require("class")
socket = require("socket")
json = require("dkjson")
GAME = require("game")
require("match")
require("BattleRoom")
require("util")
require("table_util")
require("consts")
require("queue")
require("globals")
require("character") -- after globals!
require("stage") -- after globals!
require("save")
require("engine")
require("AttackEngine")
require("localization")
require("graphics")
GAME.input = require("input")
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
require("rich_presence.RichPresence")
local logger = require("logger")
GAME.scores = require("scores")
GAME.rich_presence = RichPresence()

global_canvas = love.graphics.newCanvas(canvas_width, canvas_height)

local last_x = 0
local last_y = 0
local input_delta = 0.0
local pointer_hidden = false
local mainloop = nil

-- Called at the beginning to load the game
function love.load()
  math.randomseed(os.time())
  for i = 1, 4 do
    math.random()
  end
  read_key_file()
  GAME.rich_presence:initialize("902897593049301004")
  mainloop = coroutine.create(fmainloop)
end

function love.focus(f)
  GAME.focused = f
end

function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0

	-- Main loop time.
	return function()
		-- Process events.
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				love.handlers[name](a,b,c,d,e,f)
			end
		end

		-- Update dt, as we'll be passing it to update
		if love.timer then dt = love.timer.step() end

    love.graphics.origin()
    love.graphics.clear(love.graphics.getBackgroundColor())

		-- Call update and draw
		if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled

		if love.graphics and love.graphics.isActive() then

			if love.draw then love.draw() end
      
      local startTime = love.timer.getTime()
			love.graphics.present()
      local endTime = love.timer.getTime()

      local average = string.format("%0.4f", round(endTime - startTime, 4))
      logger.warn("present: " .. average)
  

		end

		if love.timer then love.timer.sleep(0.001) end
	end
end

-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
function love.update(dt)

  local x, y, w, h = scale_letterbox(love.graphics.getWidth(), love.graphics.getHeight(), 16, 9)
  love.graphics.translate(x, y)
  love.graphics.scale(w / canvas_width, h / canvas_height)

  -- draw background and its overlay
  local scale = canvas_width / math.max(GAME.backgroundImage:getWidth(), GAME.backgroundImage:getHeight()) -- keep image ratio
  menu_drawf(GAME.backgroundImage, canvas_width / 2, canvas_height / 2, "center", "center", 0, scale, scale)
  if GAME.background_overlay then
    local scale = canvas_width / math.max(GAME.background_overlay:getWidth(), GAME.background_overlay:getHeight()) -- keep image ratio
    menu_drawf(GAME.background_overlay, canvas_width / 2, canvas_height / 2, "center", "center", 0, scale, scale)
  end
  
  if love.mouse.getX() == last_x and love.mouse.getY() == last_y then
    if not pointer_hidden then
      if input_delta > mouse_pointer_timeout then
        pointer_hidden = true
        love.mouse.setVisible(false)
      else
        input_delta = input_delta + dt
      end
    end
  else
    last_x = love.mouse.getX()
    last_y = love.mouse.getY()
    input_delta = 0.0
    if pointer_hidden then
      pointer_hidden = false
      love.mouse.setVisible(true)
    end
  end

  if GAME.match and leftover_time + dt > (1/60.0) then
    --local average = string.format("%0.4f", round(dt, 4))
    logger.error("slowness: " .. string.format("%0.4f", round(((leftover_time + dt) - (1/60)) / (1/60), 4)))
    --logger.error("DT: " .. string.format("%0.4f", round(dt, 4)) .. " leftover before:" .. string.format("%0.4f", round(leftover_time, 4)) .. " slowness: " .. string.format("%0.4f", round(leftover_time + dt - (1 / 60), 4)))
  end
  leftover_time = leftover_time + dt  

  local status, err = coroutine.resume(mainloop)
  if not status then
    local errorData = Game.errorData(err, debug.traceback(mainloop))
    if GAME_UPDATER_GAME_VERSION then
      send_error_report(errorData)
    end
    error(err .. "\n\n" .. dump(errorData, true))
  end
  if server_queue and server_queue:size() > 0 then
    logger.trace("Queue Size: " .. server_queue:size() .. " Data:" .. server_queue:to_short_string())
  end
  this_frame_messages = {}

  update_music()
  GAME.rich_presence:runCallbacks()
end

-- Called whenever the game needs to draw.
function love.draw()

  if GAME.foreground_overlay then
    local scale = canvas_width / math.max(GAME.foreground_overlay:getWidth(), GAME.foreground_overlay:getHeight()) -- keep image ratio
    menu_drawf(GAME.foreground_overlay, canvas_width / 2, canvas_height / 2, "center", "center", 0, scale, scale)
  end

  if GAME.match then
    GAME.match:draw()
  end

  if GAME.sceneDraw then
    GAME.sceneDraw()
  end

  Click_menu.drawMenus()

  -- Draw the FPS if enabled
  if config ~= nil and config.show_fps then
    love.graphics.print("FPS: " .. love.timer.getFPS(), 1, 1)
  end

end

-- Transform from window coordinates to game coordinates
local function transform_coordinates(x, y)
  local lbx, lby, lbw, lbh = scale_letterbox(love.graphics.getWidth(), love.graphics.getHeight(), 16, 9)
  return (x - lbx) / 1 * canvas_width / lbw, (y - lby) / 1 * canvas_height / lbh
end

-- Handle a mouse or touch press
function love.mousepressed(x, y)
  for menu_name, menu in pairs(CLICK_MENUS) do
    menu:click_or_tap(transform_coordinates(x, y))
  end
end

-- Handle a touch press
-- Note we are specifically not implementing this because mousepressed above handles mouse and touch
-- function love.touchpressed(id, x, y, dx, dy, pressure)
-- local _x, _y = transform_coordinates(x, y)
-- click_or_tap(_x, _y, {id = id, x = _x, y = _y, dx = dx, dy = dy, pressure = pressure})
-- end
