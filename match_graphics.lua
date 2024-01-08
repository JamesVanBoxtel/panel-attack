local GameModes = require("GameModes")
local tableUtils = require("tableUtils")

function Match:matchelementOriginX()
  local x = 375 + (464) / 2
  if themes[config.theme]:offsetsAreFixed() then
    x = 0
  end
  return x
end

function Match:matchelementOriginY()
  local y = 118
  if themes[config.theme]:offsetsAreFixed() then
    y = 0
  end
  return y
end

function Match:drawMatchLabel(drawable, themePositionOffset, scale)
  local x = self:matchelementOriginX() + themePositionOffset[1]
  local y = self:matchelementOriginY() + themePositionOffset[2]

  local hAlign = "left"
  local vAlign = "left"
  if themes[config.theme]:offsetsAreFixed() then
    hAlign = "center"
  end
  menu_drawf(drawable, x, y, hAlign, vAlign, 0, scale, scale)
end

function Match:drawMatchTime(timeString, quads, themePositionOffset, scale)
  local x = self:matchelementOriginX() + themePositionOffset[1]
  local y = self:matchelementOriginY() + themePositionOffset[2]
  GraphicsUtil.draw_time(timeString, quads, x, y, scale)
end

function Match:drawTimer()
  local stack = self.stacks[1]
  if stack == nil or stack.game_stopwatch == nil or tonumber(stack.game_stopwatch) == nil then
    -- Make sure we have a valid time to base off of
    return
  end

  -- Draw the timer for time attack
  if self.puzzle then
    -- puzzles don't have a timer...yet?
  else
    local frames = stack.game_stopwatch
    if self.timeLimit then
      frames = (self.timeLimit * 60) - stack.game_stopwatch
      if frames < 0 then
        frames = 0
      end
    end

    local timeString = frames_to_time_string(frames, self.ended)

    self:drawMatchLabel(stack.theme.images.IMG_time, stack.theme.timeLabel_Pos, stack.theme.timeLabel_Scale)
    self:drawMatchTime(timeString, self.time_quads, stack.theme.time_Pos, stack.theme.time_Scale)
  end
end

function Match:drawMatchType()
  if match_type ~= "" then
    local matchImage = nil
    if match_type == "Ranked" then
      matchImage = themes[config.theme].images.IMG_ranked
    end
    if match_type == "Casual" then
      matchImage = themes[config.theme].images.IMG_casual
    end
    if matchImage then
      self:drawMatchLabel(matchImage, themes[config.theme].matchtypeLabel_Pos, themes[config.theme].matchtypeLabel_Scale)
    end
  end
end

function Match:drawCommunityMessage()
  -- Draw the community message
  if not config.debug_mode then
    gprintf(join_community_msg or "", 0, 668, canvas_width, "center")
  end
end

function Match:render()
  if GAME.droppedFrames > 0 and config.show_fps then
    gprint("Dropped Frames: " .. GAME.droppedFrames, 1, 12)
  end

  if config.show_fps and #self.stacks > 1 then
    local drawY = 23
    for i = 1, #self.stacks do
      local stack = self.stacks[i]
      gprint("P" .. stack.which .." Average Latency: " .. stack.framesBehind, 1, drawY)
      drawY = drawY + 11
    end

    if self:hasLocalPlayer() then
      if tableUtils.trueForAny(self.stacks, function(s) return s.framesBehind > GARBAGE_DELAY_LAND_TIME end) then
        -- let the player know that rollback is active
        local iconSize = 20
        local icon_width, icon_height = themes[config.theme].images.IMG_bug:getDimensions()
        local x = 5
        local y = 30
        draw(themes[config.theme].images.IMG_bug, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height)
      end
    else
      if tableUtils.trueForAny(self.stacks, function(s) return s.framesBehind > MAX_LAG * 0.75 end) then
        -- let the spectator know the game is about to die
        local iconSize = 20
        local icon_width, icon_height = themes[config.theme].images.IMG_bug:getDimensions()
        local x = (canvas_width / 2) - (iconSize / 2)
        local y = (canvas_height / 2) - (iconSize / 2)
        draw(themes[config.theme].images.IMG_bug, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height)
      end
    end
  end

  self:drawCommunityMessage()

  if config.debug_mode then
    local padding = 14
    local drawX = 500
    local drawY = -4

    -- drawY = drawY + padding
    -- gprintf("Time Spent Running " .. self.timeSpentRunning * 1000, drawX, drawY)

    -- drawY = drawY + padding
    -- local totalTime = love.timer.getTime() - self.createTime
    -- gprintf("Total Time " .. totalTime * 1000, drawX, drawY)

    drawY = drawY + padding
    local totalTime = love.timer.getTime() - self.createTime
    local timePercent = round(self.timeSpentRunning / totalTime, 5)
    gprintf("Time Percent Running Match: " .. timePercent, drawX, drawY)

    drawY = drawY + padding
    local maxTime = round(self.maxTimeSpentRunning, 5)
    gprintf("Max Stack Update: " .. maxTime, drawX, drawY)

    drawY = drawY + padding
    gprintf("Seed " .. self.seed, drawX, drawY)

    if self.gameOverClock and self.gameOverClock > 0 then
      drawY = drawY + padding
      gprintf("gameOverClock " .. self.gameOverClock, drawX, drawY)
    end
  end

  if self.isPaused then
    self:draw_pause()
  end

  if self.isPaused == false or self.renderDuringPause then
    -- Don't allow rendering if either player is loading for spectating
    local renderingAllowed = tableUtils.trueForAll(self.stacks, function(s) return not s.play_to_end end)

    if renderingAllowed then
      for i = 1, #self.stacks do
        local stack = self.stacks[i]
        stack:render()
        if stack.telegraph then
          stack.telegraph:render()
        end
      end

      -- local challengeMode = self.battleRoom and self.battleRoom.trainingModeSettings and self.battleRoom.trainingModeSettings.challengeMode
      -- if challengeMode then
      --   challengeMode:render()
      -- end


      -- Draw VS HUD
      if self.stackInteraction == GameModes.StackInteractions.VERSUS then
        if not config.debug_mode then -- this is printed in the same space as the debug details
          -- TODO: get spectator string from battleRoom
          -- gprint(spectators_string, themes[config.theme].spectators_Pos[1], themes[config.theme].spectators_Pos[2])
        end

        self:drawMatchType()
      end

      self:drawTimer()
    end
  end
end

-- a helper function for tests
-- prevents running graphics related processes, e.g. cards, popFX
function Match:removeCanvases()
  for i = 1, #self.players do
    self.players[i].stack.canvas = nil
  end
end

  -- Draw the pause menu
function Match:draw_pause()
  if not self.renderDuringPause then
    local image = themes[config.theme].images.pause
    local scale = canvas_width / math.max(image:getWidth(), image:getHeight()) -- keep image ratio
    menu_drawf(image, canvas_width / 2, canvas_height / 2, "center", "center", 0, scale, scale)
  end
  gprintf(loc("pause"), 0, 330, canvas_width, "center", nil, 1, large_font)
  gprintf(loc("pl_pause_help"), 0, 360, canvas_width, "center", nil, 1)
end