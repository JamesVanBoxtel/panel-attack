require("match")
require("panels")
require("theme")
require("click_menu")
local select_screen = require("select_screen")
local replay_browser = require("replay_browser")
local options = require("options")
local utf8 = require("utf8")
local analytics = require("analytics")
local main_config_input = require("config_inputs")

local wait, resume = coroutine.yield, coroutine.resume

local main_endless, make_main_puzzle, main_net_vs_setup, main_select_puzz, main_local_vs_computer_setup, main_local_vs_setup, main_set_name, main_local_vs_yourself_setup, main_options, main_replay_browser, exit_game
-- main_select_mode, main_dumb_transition, main_net_vs, main_net_vs_lobby, main_local_vs_yourself, main_local_vs, main_replay_endless, main_replay_puzzle, main_replay_vs are not local since they are also used elsewhere

local PLAYING = "playing" -- room states
local CHARACTERSELECT = "character select" -- room states
currently_spectating = false -- whether or not you are spectating a game
connection_up_time = 0 -- connection_up_time counts "E" messages, not seconds
logged_in = 0
connected_server_ip = nil -- the ip address of the server you are connected to
my_user_id = nil -- your user id
leaderboard_report = nil
replay_of_match_so_far = nil -- current replay of spectatable replay
spectator_list = nil
spectators_string = ""
leftover_time = 0
main_menu_screen_pos = {300 + (canvas_width - legacy_canvas_width) / 2, 195 + (canvas_height - legacy_canvas_height) / 2}
wait_game_update = nil
has_game_update = false
local arrow_padding = 12
local main_menu_last_index = 1

P1_win_quads = {}
P1_rating_quads = {}
P1_health_quad = {}

P2_rating_quads = {}
P2_win_quads = {}
P2_health_quad = {}

function fmainloop()
  local func, arg = main_select_mode, nil
  -- clear replay contents
  replay = {}
  -- loading various assets into the game
  gprint("Reading config file", unpack(main_menu_screen_pos))
  wait()
  read_conf_file()
  local x, y, display = love.window.getPosition()
  love.window.setPosition(config.window_x or x, config.window_y or y, config.display or display)
  love.window.setFullscreen(config.fullscreen or false)
  love.window.setVSync(config.vsync and 1 or 0)
  gprint("Loading localization...", unpack(main_menu_screen_pos))
  wait()
  Localization.init(localization)
  gprint(loc("ld_puzzles"), unpack(main_menu_screen_pos))
  wait()
  copy_file("readme_puzzles.txt", "puzzles/README.txt")
  gprint(loc("ld_replay"), unpack(main_menu_screen_pos))
  wait()
  read_replay_file()
  gprint(loc("ld_theme"), unpack(main_menu_screen_pos))
  wait()
  theme_init()
  -- stages and panels before characters since they are part of their loading!
  gprint(loc("ld_stages"), unpack(main_menu_screen_pos))
  wait()
  stages_init()
  gprint(loc("ld_panels"), unpack(main_menu_screen_pos))
  wait()
  panels_init()
  gprint(loc("ld_characters"), unpack(main_menu_screen_pos))
  wait()
  characters_init()
  gprint(loc("ld_analytics"), unpack(main_menu_screen_pos))
  wait()
  analytics.init()
  apply_config_volume()
  -- create folders in appdata for those who don't have them already
  love.filesystem.createDirectory("characters")
  love.filesystem.createDirectory("panels")
  love.filesystem.createDirectory("themes")
  love.filesystem.createDirectory("stages")

  --check for game updates
  if GAME_UPDATER_CHECK_UPDATE_INGAME then
    wait_game_update = GAME_UPDATER:async_download_latest_version()
  end

  while true do
    leftover_time = 1 / 120
    func, arg = func(unpack(arg or {}))
    collectgarbage("collect")
  end
end

-- Wrapper for doing something at 60hz
-- The rest of the stuff happens at whatever rate is convenient
function variable_step(f)
  for i = 1, 4 do
    if leftover_time >= 1 / 60 then
      joystick_ax()
      f()
      key_counts()
      this_frame_keys = {}
      this_frame_released_keys = {}
      this_frame_unicodes = {}
      leftover_time = leftover_time - 1 / 60
    end
  end
end

do
  function main_select_mode()
    click_menus = {}
    currently_spectating = false
    if themes[config.theme].musics["main"] then
      find_and_add_music(themes[config.theme].musics, "main")
    end
    character_loader_clear()
    stage_loader_clear()
    close_socket()
    background = themes[config.theme].images.bg_main
    reset_filters()
    logged_in = 0
    connection_up_time = 0
    connected_server_ip = ""
    current_server_supports_ranking = false
    match_type = ""
    local k = K[1]
    local menu_x, menu_y = unpack(main_menu_screen_pos)
    local main_menu
    local ret = nil
    
    local function goEscape()
      main_menu:set_active_idx(#main_menu.buttons)
    end
  
    local function selectFunction(myFunction, args)
      local function constructedFunction()
        main_menu_last_index = main_menu.active_idx
        main_menu:remove_self()
        ret = {myFunction, args}
      end
      return constructedFunction
    end

    match_type_message = ""
    local items = {
      {loc("mm_1_endless"), main_endless_setup},
      {loc("mm_1_puzzle"), main_select_puzz},
      {loc("mm_1_time"), main_timeattack_setup},
      {loc("mm_1_vs"), main_local_vs_yourself_setup},
      --{loc("mm_2_vs_online", "burke.ro"), main_net_vs_setup, {"burke.ro"}},
      {loc("mm_2_vs_online", "Jon's server"), main_net_vs_setup, {"18.188.43.50"}},
      --{loc("mm_2_vs_online", "betaserver.panelattack.com"), main_net_vs_setup, {"betaserver.panelattack.com"}},
      --{loc("mm_2_vs_online", "(USE ONLY WITH OTHER CLIENTS ON THIS TEST BUILD 025beta)"), main_net_vs_setup, {"18.188.43.50"}},
      --{loc("mm_2_vs_online", "This test build is for offline-use only"), main_select_mode},
      --{loc("mm_2_vs_online", "domi1819.xyz"), main_net_vs_setup, {"domi1819.xyz"}},
      --{loc("mm_2_vs_online", "(development-use only)"), main_net_vs_setup, {"localhost"}},
      --{loc("mm_2_vs_online", "LittleEndu's server"), main_net_vs_setup, {"51.15.207.223"}},
      {loc("mm_2_vs_online", "server for ranked Ex Mode"), main_net_vs_setup, {"exserver.panelattack.com", 49568}},
      {"Vs Computer", main_local_vs_computer_setup},
      {loc("mm_2_vs_local"), main_local_vs_setup},
      {loc("mm_replay_browser"), replay_browser.main},
      {loc("mm_configure"), main_config_input},
      {loc("mm_set_name"), main_set_name},
      {loc("mm_options"), options.main}
    }

    main_menu = Click_menu(menu_x, menu_y, nil, love.graphics.getHeight() - menu_y - 10, main_menu_last_index)
    for i = 1, #items do
      main_menu:add_button(items[i][1], selectFunction(items[i][2], items[i][3]), goEscape)
    end
    main_menu:add_button(loc("mm_fullscreen", "(LAlt+Enter)"), fullscreen, goEscape)
    main_menu:add_button(loc("mm_quit"), exit_game, exit_game)

    while true do
      main_menu:draw()
      if wait_game_update ~= nil then
        has_game_update = wait_game_update:pop()
        if has_game_update ~= nil and has_game_update then
          wait_game_update = nil
          GAME_UPDATER_GAME_VERSION = "NEW VERSION FOUND! RESTART THE GAME!"
        end
      end

      if GAME_UPDATER_GAME_VERSION then
        gprintf("version: " .. GAME_UPDATER_GAME_VERSION, -2, 705, canvas_width, "right")
        if has_game_update then
          menu_draw(panels[config.panels].images.classic[1][1], 1262, 685)
        end
      end

      wait()
      variable_step(
        function()          
          main_menu:update()
        end
      )
      if ret then
        return unpack(ret)
      end
    end
  end
end

function main_endless_setup()
  GAME.match = Match("endless")
  return unpack({main_select_speed_99, {main_endless}})
end

function main_timeattack_setup()
  GAME.match = Match("time")
  return unpack({main_select_speed_99, {main_time_attack}})
end

function main_select_speed_99(next_func)
  -- stack rise speed
  local speed = config.endless_speed or 1
  local difficulty = config.endless_difficulty or 1
  local active_idx = 1
  local k = K[1]
  local ret = nil
  local loc_difficulties = {loc("easy"), loc("normal"), loc("hard"), "EX Mode"} -- TODO: localize "EX Mode"

  background = themes[config.theme].images.bg_main

  local gameSettingsMenu

  local function goEscape()
    gameSettingsMenu:set_active_idx(#gameSettingsMenu.buttons)
  end

  local function exitSettings()
    ret = {main_select_mode}
  end

  local function updateMenuSpeed()
    gameSettingsMenu:set_button_setting(1, speed)
  end

  local function updateMenuDifficulty()
    gameSettingsMenu:set_button_setting(2, loc_difficulties[difficulty])
  end
  
  local function increaseSpeed()
    speed = bound(1, speed + 1, 99)
    updateMenuSpeed()
  end

  local function increaseDifficulty()
    difficulty = bound(1, difficulty + 1, 4)
    updateMenuDifficulty()
  end

  local function decreaseSpeed()
    speed = bound(1, speed - 1, 99)
    updateMenuSpeed()
  end

  local function decreaseDifficulty()
    difficulty = bound(1, difficulty - 1, 4)
    updateMenuDifficulty()
  end
    
  local function startGame()
    if config.endless_speed ~= speed or config.endless_difficulty ~= difficulty then
      config.endless_speed = speed
      config.endless_difficulty = difficulty
      gprint("saving settings...", unpack(main_menu_screen_pos))
      wait()
      write_conf_file()
    end
    stop_the_music()
    ret = {next_func, {speed, difficulty}}
  end

  local function nextMenu()
    gameSettingsMenu:selectNextIndex()
  end

  local menu_x, menu_y = unpack(main_menu_screen_pos)
  menu_y = menu_y + 70
  gameSettingsMenu = Click_menu(menu_x, menu_y, nil, love.graphics.getHeight() - menu_y - 10, 1)
  gameSettingsMenu:add_button(loc("speed"), nextMenu, goEscape, decreaseSpeed, increaseSpeed)
  gameSettingsMenu:add_button(loc("difficulty"), nextMenu, goEscape, decreaseDifficulty, increaseDifficulty)
  gameSettingsMenu:add_button(loc("go_"), startGame, goEscape)
  gameSettingsMenu:add_button(loc("back"), exitSettings, exitSettings)
  updateMenuSpeed()
  updateMenuDifficulty()

  while true do
    -- Draw the current score and record
    local record = 0
    local lastScore = 0
    if GAME.match.mode == "time" then
      lastScore = GAME.scores:lastTimeAttack1PForLevel(difficulty)
      record = GAME.scores:recordTimeAttack1PForLevel(difficulty)
    elseif GAME.match.mode == "endless" then
      lastScore = GAME.scores:lastEndlessForLevel(difficulty)
      record = GAME.scores:recordEndlessForLevel(difficulty)
    end
    local xPosition1 = 520
    local xPosition2 = xPosition1 + 150
    local yPosition = 270

    lastScore = tostring(lastScore)
    record = tostring(record)
    draw_pixel_font("last score", themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition1, yPosition, 0.5, 1.0)
    draw_pixel_font(lastScore,    themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition1, yPosition + 24, 0.5, 1.0)
    draw_pixel_font("record",     themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition2, yPosition, 0.5, 1.0)
    draw_pixel_font(record,       themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition2, yPosition + 24, 0.5, 1.0)

    gameSettingsMenu:draw()

    wait()
    variable_step(
      function()
        gameSettingsMenu:update()
      end
    )

    if ret then
      return unpack(ret)
    end
  end
end

local function use_current_stage()
  stage_loader_load(current_stage)
  stage_loader_wait()
  background = stages[current_stage].images.background
  background_overlay = themes[config.theme].images.bg_overlay
  foreground_overlay = themes[config.theme].images.fg_overlay
end

local function pick_random_stage()
  current_stage = uniformly(stages_ids_for_current_theme)
  if stages[current_stage]:is_bundle() then -- may pick a bundle!
    current_stage = uniformly(stages[current_stage].sub_stages)
  end
  use_current_stage()
end

local function pick_use_music_from()
  if config.use_music_from == "stage" or config.use_music_from == "characters" then
    current_use_music_from = config.use_music_from
    return
  end
  local percent = math.random(1, 4)
  if config.use_music_from == "either" then
    current_use_music_from = percent <= 2 and "stage" or "characters"
  elseif config.use_music_from == "often_stage" then
    current_use_music_from = percent == 1 and "characters" or "stage"
  else
    current_use_music_from = percent == 1 and "stage" or "characters"
  end
end

function Stack.wait_for_random_character(self)
  if self.character == random_character_special_value then
    self.character = uniformly(characters_ids_for_current_theme)
  elseif characters[self.character]:is_bundle() then -- may have picked a bundle
    self.character = uniformly(characters[self.character].sub_characters)
  end
  character_loader_load(self.character)
  character_loader_wait()
end

function Stack.handle_pause(self)
  local k = K[self.which]

  if self.wait_for_not_pausing then
    if not keys[k.pause] and not this_frame_keys[k.pause] then
      self.wait_for_not_pausing = false
    else
      return
    end
  end

  if keys[k.pause] or this_frame_keys[k.pause] then
    game_is_paused = not game_is_paused
    self.wait_for_not_pausing = true

    if game_is_paused then
      stop_the_music()
    end
  end
end

function main_endless(...)
  pick_random_stage()
  pick_use_music_from()
  replay = {}
  replay.endless = {}
  local replay = replay.endless
  replay.pan_buf = ""
  replay.in_buf = ""
  replay.gpan_buf = ""
  replay.mode = "endless"
  P1 = Stack(1, GAME.match, true, config.panels, ...)
  P1:wait_for_random_character()
  P1.do_countdown = config.ready_countdown_1P or false
  P2 = nil
  replay.do_countdown = P1.do_countdown or false
  replay.speed = P1.speed
  replay.difficulty = P1.difficulty
  replay.cur_wait_time = P1.cur_wait_time or default_input_repeat_delay
  make_local_panels(P1, "000000")
  make_local_gpanels(P1, "000000")
  P1:starting_state()
  while true do
    if game_is_paused then
      draw_pause()
    else
      P1:render()
    end
    wait()
    local ret = nil
    if P1:game_ended() then
      local now = os.date("*t", to_UTC(os.time()))
      local sep = "/"
      local path = "replays" .. sep .. "v" .. VERSION .. sep .. string.format("%04d" .. sep .. "%02d" .. sep .. "%02d", now.year, now.month, now.day)
      path = path .. sep .. "Endless"
      local filename = "v" .. VERSION .. "-" .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec) .. "-Spd" .. P1.speed .. "-Dif" .. P1.difficulty .. "-" .. config.name .. "-endless"
      filename = filename .. ".txt"
      write_replay_file()
      write_replay_file(path, filename)

      GAME.scores:saveEndlessScoreForLevel(P1.score, P1.difficulty)
      return game_over_transition, {main_endless_setup, nil, P1:pick_win_sfx()}
    end
    variable_step(
      function()
        P1:run()
        P1:handle_pause()
        if menu_escape_game(K[1]) then
          ret = {main_dumb_transition, {main_endless_setup, "", 0, 0}}
        end
      end
    )
    --groundhogday mode
    --[[if P1.CLOCK == 1001 then
      local prev_states = P1.prev_states
      P1 = prev_states[600]
      P1.prev_states = prev_states
    end--]]
    if ret then
      return unpack(ret)
    end
  end
end

function main_time_attack(...)
  pick_random_stage()
  pick_use_music_from()
  P1 = Stack(1, GAME.match, true, config.panels, ...)
  P1:wait_for_random_character()
  make_local_panels(P1, "000000")
  P1:starting_state()
  P2 = nil
  while true do
    if game_is_paused then
      draw_pause()
    else
      P1:render()
    end
    wait()
    local ret = nil
    if P1:game_ended() then
      GAME.scores:saveTimeAttack1PScoreForLevel(P1.score, P1.difficulty)
      return game_over_transition, {main_timeattack_setup, nil, P1:pick_win_sfx()}
    end
    variable_step(
      function()
        if P1:game_ended() == false then
          P1:run()
          P1:handle_pause()
          if menu_escape_game(K[1]) then
            ret = {main_dumb_transition, {main_timeattack_setup, "", 0, 0}}
          end
        end
      end
    )
    if ret then
      return unpack(ret)
    end
  end
end

function main_net_vs_lobby()
  if themes[config.theme].musics.main then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  background = themes[config.theme].images.bg_main
  reset_filters()
  character_loader_clear()
  stage_loader_clear()
  local items
  local unpaired_players = {} -- list
  local willing_players = {} -- set
  local spectatable_rooms = {}
  local k = K[1]
  my_player_number = nil
  op_player_number = nil
  local notice = {[true] = loc("lb_select_player"), [false] = loc("lb_alone")}
  local leaderboard_string = ""
  local my_rank
  match_type = ""
  match_type_message = ""
  --attempt login
  read_user_id_file()
  if not my_user_id then
    my_user_id = "need a new user id"
  end
  local login_status_message = "   " .. loc("lb_login")
  local login_status_message_duration = 2
  local login_denied = false
  local showing_leaderboard = false
  local lobby_menu_x = {[true] = main_menu_screen_pos[1] - 200, [false] = main_menu_screen_pos[1]} --will be used to make room in case the leaderboard should be shown.
  local lobby_menu_y = main_menu_screen_pos[2] + 50
  local sent_requests = {}
  if connection_up_time <= login_status_message_duration then
    json_send({login_request = true, user_id = my_user_id})
  end
  local lobby_menu = nil
  local items = {}
  local lastPlayerIndex = 0
  local updated = true -- need update when first entering
  local ret = nil

  while true do
    if connection_up_time <= login_status_message_duration then
      gprint(login_status_message, lobby_menu_x[showing_leaderboard], lobby_menu_y - 120)
      local messages = server_queue:pop_all_with("login_successful", "login_denied")
      for _, msg in ipairs(messages) do
        if msg.login_successful then
          current_server_supports_ranking = true
          logged_in = true
          if msg.new_user_id then
            my_user_id = msg.new_user_id
            print("about to write user id file")
            write_user_id_file()
            login_status_message = loc("lb_user_new", my_name)
          elseif msg.name_changed then
            login_status_message = loc("lb_user_update", msg.old_name, msg.new_name)
            login_status_message_duration = 5
          else
            login_status_message = loc("lb_welcome_back", my_name)
          end
        elseif msg.login_denied then
          current_server_supports_ranking = true
          login_denied = true
          --TODO: create a menu here to let the user choose "continue unranked" or "get a new user_id"
          --login_status_message = "Login for ranked matches failed.\n"..msg.reason.."\n\nYou may continue unranked,\nor delete your invalid user_id file to have a new one assigned."
          login_status_message_duration = 10
          return main_dumb_transition, {main_select_mode, loc("lb_error_msg") .. "\n\n" .. json.encode(msg), 60, 600}
        end
      end
      if connection_up_time == 2 and not current_server_supports_ranking then
        login_status_message = loc("lb_login_timeout")
        login_status_message_duration = 7
      end
    end
    local messages = server_queue:pop_all_with("choose_another_name", "create_room", "unpaired", "game_request", "leaderboard_report", "spectate_request_granted")
    for _, msg in ipairs(messages) do
      updated = true
      items = {}
      if msg.choose_another_name and msg.choose_another_name.used_names then
        return main_dumb_transition, {main_select_mode, loc("lb_used_name"), 60, 600}
      elseif msg.choose_another_name and msg.choose_another_name.reason then
        return main_dumb_transition, {main_select_mode, "Error: " .. msg.choose_another_name.reason, 60, 300}
      end
      if msg.create_room or msg.spectate_request_granted then
        global_initialize_room_msg = msg
        select_screen.character_select_mode = "2p_net_vs"
        love.window.requestAttention()
        play_optional_sfx(themes[config.theme].sounds.notification)
        return select_screen.main
      end
      if msg.unpaired then
        unpaired_players = msg.unpaired
        -- players who leave the unpaired list no longer have standing invitations to us.\
        -- we also no longer have a standing invitation to them, so we'll remove them from sent_requests
        local new_willing = {}
        local new_sent_requests = {}
        for _, player in ipairs(unpaired_players) do
          new_willing[player] = willing_players[player]
          new_sent_requests[player] = sent_requests[player]
        end
        willing_players = new_willing
        sent_requests = new_sent_requests
        if msg.spectatable then
          spectatable_rooms = msg.spectatable
        end
      end
      if msg.game_request then
        willing_players[msg.game_request.sender] = true
        love.window.requestAttention()
        play_optional_sfx(themes[config.theme].sounds.notification)
      end
      if msg.leaderboard_report then
        showing_leaderboard = true
        if lobby_menu then
          lobby_menu:show_controls(true)
        end
        leaderboard_report = msg.leaderboard_report
        for k, v in ipairs(leaderboard_report) do
          if v.is_you then
            my_rank = k
          end
        end
        leaderboard_first_idx_to_show = math.max((my_rank or 1) - 8, 1)
        leaderboard_last_idx_to_show = math.min(leaderboard_first_idx_to_show + 20, #leaderboard_report)
        leaderboard_string = build_viewable_leaderboard_string(leaderboard_report, leaderboard_first_idx_to_show, leaderboard_last_idx_to_show)
      end
    end
    local print_x, print_y = unpack(main_menu_screen_pos)
    local to_print = ""
    local arrow = ""

    local function toggleLeaderboard()
      updated = true
      if not showing_leaderboard then
        json_send({leaderboard_request = true})
        --lobby_menu:set_button_text(#lobby_menu.buttons - 1, loc("lb_hide_board"))
      else
        --lobby_menu:set_button_text(#lobby_menu.buttons - 1, loc("lb_show_board"))
        showing_leaderboard = false
        lobby_menu:move(lobby_menu_x[showing_leaderboard], lobby_menu_y)
      end
    end

    -- If we got an update to the lobby, refresh the menu
    if updated then
      local oldLobbyMenu = nil
      if lobby_menu then
        oldLobbyMenu = lobby_menu
        lobby_menu:remove_self()
        lobby_menu = nil
      end

      local function commonSelectLobby()
        updated = true
        spectator_list = {}
        spectators_string = ""
      end

      local function goEscape()
        lobby_menu:set_active_idx(#lobby_menu.buttons)
      end

      local function exitLobby()
        commonSelectLobby()
        ret = {main_select_mode}
      end

      local function requestGameFunction(opponentName)
        return function ()
          my_name = config.name
          op_name = opponentName
          currently_spectating = false
          sent_requests[op_name] = true
          request_game(opponentName)
          updated = true
        end
      end
        
      local function requestSpectateFunction(room)
        return function ()
          my_name = room.a
          op_name = room.b
          currently_spectating = true
          room_number_last_spectated = room.roomNumber
          request_spectate(room.roomNumber)
        end
      end

      lobby_menu = Click_menu(lobby_menu_x[showing_leaderboard], lobby_menu_y, nil, love.graphics.getHeight() - lobby_menu_y - 10, 1)
      for _, v in ipairs(unpaired_players) do
        if v ~= config.name then
          local unmatchedPlayer = v .. (sent_requests[v] and " " .. loc("lb_request") or "") .. (willing_players[v] and " " .. loc("lb_received") or "")
          lobby_menu:add_button(unmatchedPlayer, requestGameFunction(v), goEscape)
        end
      end
      for _, room in ipairs(spectatable_rooms) do
        if room.name then
          local roomName = loc("lb_spectate") .. " " .. room.name .. " (" .. room.state .. ")" --printing room names
          lobby_menu:add_button(roomName, requestSpectateFunction(room), goEscape)
        end
      end
      if showing_leaderboard then
        lobby_menu:add_button(loc("lb_hide_board"), toggleLeaderboard, toggleLeaderboard)
      else
        lobby_menu:add_button(loc("lb_show_board"), toggleLeaderboard, goEscape)
      end
      lobby_menu:add_button(loc("lb_back"), exitLobby, exitLobby)

      -- Restore the lobby selection
      if oldLobbyMenu then
        if oldLobbyMenu.active_idx == #oldLobbyMenu.buttons then
          lobby_menu:set_active_idx(#lobby_menu.buttons)
        elseif oldLobbyMenu.active_idx == #oldLobbyMenu.buttons - 1 and #lobby_menu.buttons >= 2 then
          lobby_menu:set_active_idx(#lobby_menu.buttons - 1) --the position of the "hide leaderboard" menu item
        else
          for i = 1, #lobby_menu.buttons do
            if #oldLobbyMenu.buttons >= i then
              if lobby_menu.buttons[i].stringText == oldLobbyMenu.buttons[i].stringText then
                lobby_menu:set_active_idx(i)
                break
              end
            end
          end
        end

        oldLobbyMenu = nil
      end
    end

    if lobby_menu then
      gprint(notice[#lobby_menu.buttons > 2], lobby_menu_x[showing_leaderboard], lobby_menu_y - 30)
      gprint(arrow, lobby_menu_x[showing_leaderboard], lobby_menu_y)
      gprint(to_print, lobby_menu_x[showing_leaderboard], lobby_menu_y)
      if showing_leaderboard then
        gprint(leaderboard_string, lobby_menu_x[showing_leaderboard] + 400, lobby_menu_y - 120)
      end
      gprint(join_community_msg, main_menu_screen_pos[1] + 30, love.graphics.getHeight() - 50)
      lobby_menu:draw()
    end
    updated = false
    wait()
    variable_step(
      function()
        if showing_leaderboard then
          if menu_up(k) then
            if showing_leaderboard then
              if leaderboard_first_idx_to_show > 1 then
                leaderboard_first_idx_to_show = leaderboard_first_idx_to_show - 1
                leaderboard_last_idx_to_show = leaderboard_last_idx_to_show - 1
                leaderboard_string = build_viewable_leaderboard_string(leaderboard_report, leaderboard_first_idx_to_show, leaderboard_last_idx_to_show)
              end
            end
          elseif menu_down(k) then
            if showing_leaderboard then
              if leaderboard_last_idx_to_show < #leaderboard_report then
                leaderboard_first_idx_to_show = leaderboard_first_idx_to_show + 1
                leaderboard_last_idx_to_show = leaderboard_last_idx_to_show + 1
                leaderboard_string = build_viewable_leaderboard_string(leaderboard_report, leaderboard_first_idx_to_show, leaderboard_last_idx_to_show)
              end
            end
          elseif menu_escape(k) or menu_enter(k) then
            toggleLeaderboard()
          end
        elseif lobby_menu then
          lobby_menu:update()
        end
      end
    )
    if ret then
      json_send({logout = true})
      return unpack(ret)
    end
    if not do_messages() then
      return main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}
    end
    drop_old_data_messages() -- We are in the lobby, we shouldn't have any game data messages
  end
end

-- creates a leaderboard string that is sorted by rank
function build_viewable_leaderboard_string(report, first_viewable_idx, last_viewable_idx)
  str = loc("lb_header_board") .. "\n"
  first_viewable_idx = math.max(first_viewable_idx, 1)
  last_viewable_idx = math.min(last_viewable_idx, #report)
  for i = first_viewable_idx, last_viewable_idx do
    if report[i].is_you then
      str = str .. loc("lb_you") .. "-> "
    else
      str = str .. "      "
    end
    str = str .. i .. "    " .. report[i].rating .. "    " .. report[i].user_name
    if i < #report then
      str = str .. "\n"
    end
  end
  return str
end
-- connects to the server using the given ip address and network port
function main_net_vs_setup(ip, network_port)
  if not config.name then
    return main_set_name
  else
    my_name = config.name
  end
  while config.name == "defaultname" do
    if main_set_name() == {main_select_mode} and config.name ~= "defaultname" then
      return main_net_vs_setup
    end
  end
  P1, P1_level, P2_level, got_opponent = nil
  P2 = {panel_buffer = "", gpanel_buffer = ""}
  server_queue = ServerQueue(SERVER_QUEUE_CAPACITY)
  gprint(loc("lb_set_connect"), unpack(main_menu_screen_pos))
  wait()
  network_init(ip, network_port)
  local timeout_counter = 0
  while not connection_is_ready() do
    gprint(loc("lb_connecting"), unpack(main_menu_screen_pos))
    wait()
    if not do_messages() then
      return main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}
    end
  end
  connected_server_ip = ip
  logged_in = false
  return main_net_vs_lobby
end

-- online match
function main_net_vs()
  --Uncomment below to induce lag
  --STONER_MODE = true
  if current_stage then
    use_current_stage()
  else
    pick_random_stage()
  end
  pick_use_music_from()
  local k = K[1] --may help with spectators leaving games in progress
  local op_name_y = 40
  if string.len(my_name) > 12 then
    op_name_y = 55
  end
  while true do
    -- Uncomment this to cripple your game :D
    -- love.timer.sleep(0.030)
    local messages = server_queue:pop_all_with("taunt", "leave_room")
    for _, msg in ipairs(messages) do
      if msg.taunt then -- send taunts
        local taunts = nil
        -- P1.character and P2.character are supposed to be already filtered with current mods, taunts may differ though!
        if msg.player_number == my_player_number then
          taunts = characters[P1.character].sounds[msg.type]
        elseif msg.player_number == op_player_number then
          taunts = characters[P2.character].sounds[msg.type]
        end
        if taunts then
          for _, t in ipairs(taunts) do
            t:stop()
          end
          if msg.index <= #taunts then
            taunts[msg.index]:play()
          elseif #taunts ~= 0 then
            taunts[math.random(#taunts)]:play()
          end
        end
      elseif msg.leave_room then --reset win counts and go back to lobby
        my_win_count = 0
        op_win_count = 0
        return main_dumb_transition, {main_net_vs_lobby, "", 0, 0} -- someone left the game, quit to lobby
      end
    end
    --draw graphics
    local name_and_score = {(my_name or "") .. "\n" .. loc("ss_wins") .. " " .. my_win_count, (op_name or "") .. "\n" .. loc("ss_wins") .. " " .. op_win_count}
    gprint((my_name or ""), P1.score_x + themes[config.theme].name_Pos[1], P1.score_y + themes[config.theme].name_Pos[2])
    gprint((op_name or ""), P2.score_x + themes[config.theme].name_Pos[1], P2.score_y + themes[config.theme].name_Pos[2])
    draw_label(themes[config.theme].images.IMG_wins, (P1.score_x + themes[config.theme].winLabel_Pos[1]) / GFX_SCALE, (P1.score_y + themes[config.theme].winLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].winLabel_Scale)
    draw_number(my_win_count, themes[config.theme].images.IMG_timeNumber_atlas, 12, P1_win_quads, P1.score_x + themes[config.theme].win_Pos[1], P1.score_y + themes[config.theme].win_Pos[2], themes[config.theme].win_Scale, 20 / themes[config.theme].images.timeNumberWidth * themes[config.theme].time_Scale, 26 / themes[config.theme].images.timeNumberHeight * themes[config.theme].time_Scale, "center")

    draw_label(themes[config.theme].images.IMG_wins, (P2.score_x + themes[config.theme].winLabel_Pos[1]) / GFX_SCALE, (P2.score_y + themes[config.theme].winLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].winLabel_Scale)
    draw_number(op_win_count, themes[config.theme].images.IMG_timeNumber_atlas, 12, P2_win_quads, P2.score_x + themes[config.theme].win_Pos[1], P2.score_y + themes[config.theme].win_Pos[2], themes[config.theme].win_Scale, 20 / themes[config.theme].images.timeNumberWidth * themes[config.theme].time_Scale, 26 / themes[config.theme].images.timeNumberHeight * themes[config.theme].time_Scale, "center")

    if not config.debug_mode then --this is printed in the same space as the debug details
      gprint(spectators_string, themes[config.theme].spectators_Pos[1], themes[config.theme].spectators_Pos[2])
    end
    if match_type == "Ranked" then
      if global_current_room_ratings[my_player_number] and global_current_room_ratings[my_player_number].new then
        local rating_to_print = loc("ss_rating") .. "\n"
        if global_current_room_ratings[my_player_number].new > 0 then
          rating_to_print = global_current_room_ratings[my_player_number].new
        end
        --gprint(rating_to_print, P1.score_x, P1.score_y-30)
        draw_label(themes[config.theme].images.IMG_rating_1P, (P1.score_x + themes[config.theme].ratingLabel_Pos[1]) / GFX_SCALE, (P1.score_y + themes[config.theme].ratingLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].ratingLabel_Scale)
        if type(rating_to_print) == "number" then
          draw_number(rating_to_print, themes[config.theme].images.IMG_number_atlas_1P, 10, P1_rating_quads, P1.score_x + themes[config.theme].rating_Pos[1], P1.score_y + themes[config.theme].rating_Pos[2], themes[config.theme].rating_Scale, (15 / themes[config.theme].images.numberWidth_1P * themes[config.theme].rating_Scale), (19 / themes[config.theme].images.numberHeight_1P * themes[config.theme].rating_Scale), "center")
        end
      end
      if global_current_room_ratings[op_player_number] and global_current_room_ratings[op_player_number].new then
        local op_rating_to_print = loc("ss_rating") .. "\n"
        if global_current_room_ratings[op_player_number].new > 0 then
          op_rating_to_print = global_current_room_ratings[op_player_number].new
        end
        --gprint(op_rating_to_print, P2.score_x, P2.score_y-30)
        draw_label(themes[config.theme].images.IMG_rating_2P, (P2.score_x + themes[config.theme].ratingLabel_Pos[1]) / GFX_SCALE, (P2.score_y + themes[config.theme].ratingLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].ratingLabel_Scale)
        if type(op_rating_to_print) == "number" then
          draw_number(op_rating_to_print, themes[config.theme].images.IMG_number_atlas_2P, 10, P2_rating_quads, P2.score_x + themes[config.theme].rating_Pos[1], P2.score_y + themes[config.theme].rating_Pos[2], themes[config.theme].rating_Scale, (15 / themes[config.theme].images.numberWidth_2P * themes[config.theme].rating_Scale), (19 / themes[config.theme].images.numberHeight_2P * themes[config.theme].rating_Scale), "center")
        end
      end
    end
    -- don't spend time rendering when catching up to a current match in replays
    if not (P1 and P1.play_to_end) and not (P2 and P2.play_to_end) then
      P1:render()
      P2:render()
      wait()
    end

    if currently_spectating and menu_escape(K[1]) then
      print("spectator pressed escape during a game")
      my_win_count = 0
      op_win_count = 0
      json_send({leave_room = true})
      return main_dumb_transition, {main_net_vs_lobby, "", 0, 0} -- spectator leaving the match
    end
    if not do_messages() then
      return main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}
    end
    process_all_data_messages() -- main game play processing

    --print(P1.CLOCK, P2.CLOCK)
    if (P1 and P1.play_to_end) or (P2 and P2.play_to_end) then
      P1:run()
      P2:run()
    else
      variable_step(
        function()
          P1:run()
          P2:run()
        end
      )
    end

    local outcome_claim = nil
    local winSFX = nil
    local end_text = nil
    -- We can't call it until someone has lost and everyone has played up to that point in time.
    if GAME_ENDED_CLOCK > 0 and P1.CLOCK >= GAME_ENDED_CLOCK and P2.CLOCK >= GAME_ENDED_CLOCK then
      if P1.game_over_clock == GAME_ENDED_CLOCK and P2.game_over_clock == GAME_ENDED_CLOCK then -- draw
        end_text = loc("ss_draw")
        outcome_claim = 0
      elseif P1.game_over_clock == GAME_ENDED_CLOCK then -- opponent wins
        winSFX = P2:pick_win_sfx()
        end_text = loc("ss_p_wins", op_name)
        op_win_count = op_win_count + 1 -- leaving these in just in case used with an old server that doesn't keep score.  win_counts will get overwritten after this by the server anyway.
        outcome_claim = P2.player_number
      elseif P2.game_over_clock == GAME_ENDED_CLOCK then -- client wins
        winSFX = P1:pick_win_sfx()
        end_text = loc("ss_p_wins", my_name)
        my_win_count = my_win_count + 1 -- leave this in
        outcome_claim = P1.player_number
      end
    end
    if end_text then
      undo_stonermode()
      json_send({game_over = true, outcome = outcome_claim})
      local now = os.date("*t", to_UTC(os.time()))
      local sep = "/"
      local path = "replays" .. sep .. "v" .. VERSION .. sep .. string.format("%04d" .. sep .. "%02d" .. sep .. "%02d", now.year, now.month, now.day)
      local rep_a_name, rep_b_name = my_name, op_name
      --sort player names alphabetically for folder name so we don't have a folder "a-vs-b" and also "b-vs-a"
      if rep_b_name < rep_a_name then
        path = path .. sep .. rep_b_name .. "-vs-" .. rep_a_name
      else
        path = path .. sep .. rep_a_name .. "-vs-" .. rep_b_name
      end
      local filename = "v" .. VERSION .. "-" .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec) .. "-" .. rep_a_name .. "-L" .. P1.level .. "-vs-" .. rep_b_name .. "-L" .. P2.level
      if match_type and match_type ~= "" then
        filename = filename .. "-" .. match_type
      end
      if outcome_claim == 1 or outcome_claim == 2 then
        filename = filename .. "-P" .. outcome_claim .. "wins"
      elseif outcome_claim == 0 then
        filename = filename .. "-draw"
      end
      filename = filename .. ".txt"
      write_replay_file()
      print("saving replay as " .. path .. sep .. filename)
      write_replay_file(path, filename)

      select_screen.character_select_mode = "2p_net_vs"
      if currently_spectating then --transition to game over.
        return game_over_transition, {select_screen.main, end_text, winSFX, 60 * 8}
      else
        return game_over_transition, {select_screen.main, end_text, winSFX, 60 * 8}
      end
    end
  end
end

-- sets up globals for local vs
function main_local_vs_setup()
  currently_spectating = false
  my_name = config.name or "Player 1"
  op_name = "Player 2"
  op_state = nil
  select_screen.character_select_mode = "2p_local_vs"
  return select_screen.main
end

-- sets up globals for local vs computer
function main_local_vs_computer_setup()
  currently_spectating = false
  my_name = config.name or "Player 1"
  op_name = "Computer"
  op_state = nil
  select_screen.character_select_mode = "2p_local_computer_vs"
  return select_screen.main
end

-- local 2pvs mode
function main_local_vs()
  -- TODO: replay!
  use_current_stage()
  pick_use_music_from()
  local end_text = nil
  while true do
    if game_is_paused then
      draw_pause()
    else
      P1:render()
      P2:render()
    end
    wait()
    variable_step(
      function()
        P1:run()
        P2:run()
        P1:handle_pause()
        P2:handle_pause()
      end
    )

    --TODO: refactor this so it isn't duplicated
    local winSFX = nil
    local end_text = nil
    -- We can't call it until someone has lost and everyone has played up to that point in time.
    if GAME_ENDED_CLOCK > 0 and P1.CLOCK >= GAME_ENDED_CLOCK and P2.CLOCK >= GAME_ENDED_CLOCK then
      if P1.game_over_clock == GAME_ENDED_CLOCK and P2.game_over_clock == GAME_ENDED_CLOCK then
        end_text = loc("ss_draw")
        outcome_claim = 0
      elseif P1.game_over_clock == GAME_ENDED_CLOCK then
        winSFX = P2:pick_win_sfx()
        end_text = loc("pl_2_win", op_name)
        op_win_count = op_win_count + 1
      elseif P2.game_over_clock == GAME_ENDED_CLOCK then
        winSFX = P1:pick_win_sfx()
        end_text = loc("pl_1_win", my_name)
        my_win_count = my_win_count + 1
      end
    end

    if end_text then
      return game_over_transition, {select_screen.main, end_text, winSFX}
    end
  end
end

-- sets up globals for vs yourself
function main_local_vs_yourself_setup()
  currently_spectating = false
  my_name = config.name or loc("player_n", "1")
  op_name = nil
  op_state = nil
  select_screen.character_select_mode = "1p_vs_yourself"
  return select_screen.main
end

-- 1vs against yourself
function main_local_vs_yourself()
  -- TODO: replay!
  use_current_stage()
  pick_use_music_from()
  while true do
    if game_is_paused then
      draw_pause()
    else
      P1:render()
    end
    wait()
    local ret = nil
    variable_step(
      function()
        if P1:game_ended() == false then
          P1:run()
          P1:handle_pause()
          if menu_escape_game(K[1]) then
            ret = {main_dumb_transition, {main_local_vs_yourself_setup, "", 0, 0}}
          end
        end
      end
    )
    if P1:game_ended() then
      GAME.scores:saveVsSelfScoreForLevel(P1.analytic.data.sent_garbage_lines, P1.level)

      return game_over_transition, {select_screen.main, nil, P1:pick_win_sfx()}
    end
    if ret then
      return unpack(ret)
    end
  end
end

-- shows debug info for mouse hover
local function draw_debug_mouse_panel()
  if debug_mouse_panel then
    local str = loc("pl_panel_info", debug_mouse_panel[1], debug_mouse_panel[2])
    for k, v in spairs(debug_mouse_panel[3]) do
      str = str .. "\n" .. k .. ": " .. tostring(v)
    end
    gprintf(str, 10, 10)
  end
end

-- replay for 2pvs match
function main_replay_vs()
  local replay = replay.vs
  if replay == nil then
    return main_dumb_transition, {replay_browser.main, loc("rp_no_replay"), 0, -1}
  end
  stop_the_music()
  pick_random_stage()
  pick_use_music_from()
  select_screen.fallback_when_missing = {nil, nil}
  GAME.match = Match("vs")
  P1 = Stack(1, GAME.match, false, config.panels, replay.P1_level or 5)
  P2 = Stack(2, GAME.match, false, config.panels, replay.P2_level or 5)
  P1.do_countdown = replay.do_countdown or false
  P2.do_countdown = replay.do_countdown or false
  P1.ice = true
  P1.garbage_target = P2
  P2.garbage_target = P1
  move_stack(P2, 2)
  P1.input_buffer = replay.in_buf
  P1.panel_buffer = replay.P
  P1.gpanel_buffer = replay.Q
  P2.input_buffer = replay.I
  P2.panel_buffer = replay.O
  P2.gpanel_buffer = replay.R
  P1.max_runs_per_frame = 1
  P2.max_runs_per_frame = 1
  P1.character = replay.P1_char
  P2.character = replay.P2_char
  P1.cur_wait_time = replay.P1_cur_wait_time or default_input_repeat_delay
  P2.cur_wait_time = replay.P2_cur_wait_time or default_input_repeat_delay
  refresh_based_on_own_mods(P1)
  refresh_based_on_own_mods(P2, true)
  character_loader_load(P1.character)
  character_loader_load(P2.character)
  character_loader_wait()
  my_name = replay.P1_name or loc("player_n", "1")
  op_name = replay.P2_name or loc("player_n", "2")
  if replay.ranked then
    match_type = "Ranked"
  else
    match_type = "Casual"
  end

  P1:starting_state()
  P2:starting_state()
  local end_text = nil
  local run = true
  while true do
    debug_mouse_panel = nil
    gprint(my_name or "", P1.score_x, P1.score_y - 28)
    gprint(op_name or "", P2.score_x, P2.score_y - 28)
    P1:render()
    P2:render()
    draw_debug_mouse_panel()
    if game_is_paused then
      draw_pause()
    end
    wait()
    local ret = nil
    variable_step(
      function()
        if menu_escape(K[1]) then
          ret = {main_dumb_transition, {replay_browser.main, "", 0, 0}}
        end
        if menu_enter(K[1]) then
          run = not run
        end
        if this_frame_keys["\\"] then
          run = false
        end
        if run or this_frame_keys["\\"] then
          P1:run()
          P1:handle_pause()
          P2:run()
        end
      end
    )
    if ret then
      return unpack(ret)
    end
    local winSFX = nil

    --TODO: refactor this so it isn't duplicated
    local winSFX = nil
    local end_text = nil
    -- We can't call it until someone has lost and everyone has played up to that point in time.
    if GAME_ENDED_CLOCK > 0 and P1.CLOCK >= GAME_ENDED_CLOCK and P2.CLOCK >= GAME_ENDED_CLOCK then
      if P1.game_over_clock == GAME_ENDED_CLOCK and P2.game_over_clock == GAME_ENDED_CLOCK then
        end_text = loc("ss_draw")
      elseif P1.game_over_clock == GAME_ENDED_CLOCK then
        winSFX = P2:pick_win_sfx()
        if replay.P2_name and replay.P2_name ~= "anonymous" then
          end_text = loc("ss_p_wins", replay.P2_name)
        else
          end_text = loc("pl_2_win")
        end
      elseif P2.game_over_clock == GAME_ENDED_CLOCK then
        winSFX = P1:pick_win_sfx()
        if replay.P1_name and replay.P1_name ~= "anonymous" then
          end_text = loc("ss_p_wins", replay.P1_name)
        else
          end_text = loc("pl_1_win")
        end
      end
    end

    if end_text then
      return game_over_transition, {main_select_mode, end_text, 0, -1, winSFX}
    end
  end
end

-- replay endless game
function main_replay_endless()
  local replay = replay.endless
  if replay == nil or replay.speed == nil then
    return main_dumb_transition, {replay_browser.main, loc("rp_no_endless"), 0, -1}
  end
  stop_the_music()
  pick_random_stage()
  pick_use_music_from()
  GAME.match = Match("endless")
  P1 = Stack(1, GAME.match, false, config.panels, replay.speed, replay.difficulty)
  P1:wait_for_random_character()
  P1.do_countdown = replay.do_countdown or false
  P1.max_runs_per_frame = 1
  P1.input_buffer = table.concat({replay.in_buf})
  P1.panel_buffer = replay.pan_buf
  P1.gpanel_buffer = replay.gpan_buf
  P1.speed = replay.speed
  P1.difficulty = replay.difficulty
  P1.cur_wait_time = replay.cur_wait_time or default_input_repeat_delay
  P1:starting_state()
  P2 = nil
  local run = true
  while true do
    P1:render()
    if game_is_paused then
      draw_pause()
    end
    wait()
    local ret = nil
    variable_step(
      function()
        if menu_escape(K[1]) then
          ret = {main_dumb_transition, {replay_browser.main, "", 0, 0}}
        end
        if menu_enter(K[1]) then
          run = not run
        end
        if this_frame_keys["\\"] then
          run = false
        end
        if run or this_frame_keys["\\"] then
          if P1:game_ended() then
            local end_text = loc("rp_score", P1.score, frames_to_time_string(P1.game_stopwatch, true))
            ret = {game_over_transition, {replay_browser.main, end_text, P1:pick_win_sfx()}}
          end
          P1:run()
          P1:handle_pause()
        end
      end
    )
    if ret then
      return unpack(ret)
    end
  end
end

-- replay for endless game
function main_replay_puzzle()
  local replay = replay.puzzle
  if not replay or replay.in_buf == nil or replay.in_buf == "" then
    return main_dumb_transition, {replay_browser.main, loc("rp_no_puzzle"), 0, -1}
  end
  stop_the_music()
  pick_random_stage()
  pick_use_music_from()

  GAME.match = Match("puzzle")
  P1 = Stack(1, GAME.match, false, config.panels)
  P1:wait_for_random_character()
  P1.do_countdown = replay.do_countdown or false
  P1.max_runs_per_frame = 1
  P1.input_buffer = replay.in_buf
  P1.cur_wait_time = replay.cur_wait_time or default_input_repeat_delay
  P1:set_puzzle_state(unpack(replay.puzzle))
  P2 = nil
  local run = true
  while true do
    debug_mouse_panel = nil
    P1:render()
    draw_debug_mouse_panel()
    if game_is_paused then
      draw_pause()
    end
    wait()
    local ret = nil
    variable_step(
      function()
        if menu_escape(K[1]) then
          ret = {main_dumb_transition, {replay_browser.main, "", 0, 0}}
        end
        if menu_enter(K[1]) then
          run = not run
        end
        if this_frame_keys["\\"] then
          run = false
        end
        if run or this_frame_keys["\\"] then
          if P1.n_active_panels == 0 and P1.prev_active_panels == 0 then
            if P1:puzzle_done() then
              ret = {main_dumb_transition, {replay_browser.main, loc("pl_you_win"), 30, -1, P1:pick_win_sfx()}}
            elseif P1.puzzle_moves == 0 then
              ret = {main_dumb_transition, {replay_browser.main, loc("pl_you_lose"), 30, -1}}
            end
          end
          P1:run()
          P1:handle_pause()
        end
      end
    )
    if ret then
      return unpack(ret)
    end
  end
end
-- creates a puzzle game
function make_main_puzzle(puzzles)
  local awesome_idx, next_func = 1, nil
  function next_func()
    stop_the_music()
    pick_random_stage()
    pick_use_music_from()
    -- clear replay contents
    replay = {}
    -- instantiate a puzzle replay
    replay.puzzle = {}
    local replay = replay.puzzle
    GAME.match = Match("puzzle")
    P1 = Stack(1, GAME.match, true, config.panels)
    P1:wait_for_random_character()
    P1.do_countdown = config.ready_countdown_1P or false
    P2 = nil
    local start_delay = 0
    if awesome_idx == nil then
      awesome_idx = math.random(#puzzles)
    end
    P1:set_puzzle_state(unpack(puzzles[awesome_idx]))
    replay.cur_wait_time = P1.cur_wait_time or default_input_repeat_delay
    replay.puzzle = puzzles[awesome_idx]
    replay.in_buf = ""
    while true do
      if game_is_paused then
        draw_pause()
      else
        P1:render()
      end
      wait()
      local ret = nil
      variable_step(
        function()
          if this_frame_keys["escape"] then
            ret = {main_dumb_transition, {main_select_puzz, "", 0, 0}}
          else
            if P1.n_active_panels == 0 and P1.prev_active_panels == 0 then
              if P1:puzzle_done() then -- writes successful puzzle replay and ends game
                awesome_idx = (awesome_idx % #puzzles) + 1
                local now = os.date("*t", to_UTC(os.time()))
                local sep = "/"
                local path = "replays" .. sep .. "v" .. VERSION .. sep .. string.format("%04d" .. sep .. "%02d" .. sep .. "%02d", now.year, now.month, now.day)
                path = path .. sep .. "Puzzles"
                local filename = "v" .. VERSION .. "-" .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec) .. "-" .. config.name .. "-Successful" .. "-Puzzle"
                filename = filename .. ".txt"
                write_replay_file()
                write_replay_file(path, filename)
                if awesome_idx == 1 then
                  ret = {main_dumb_transition, {main_select_puzz, loc("pl_you_win"), 30, -1, P1:pick_win_sfx()}}
                else
                  ret = {main_dumb_transition, {next_func, loc("pl_you_win"), 30, -1, P1:pick_win_sfx()}}
                end
              elseif P1.puzzle_moves == 0 then -- writes failed puzzle replay and returns to menu
                local now = os.date("*t", to_UTC(os.time()))
                local sep = "/"
                local path = "replays" .. sep .. "v" .. VERSION .. sep .. string.format("%04d" .. sep .. "%02d" .. sep .. "%02d", now.year, now.month, now.day)
                path = path .. sep .. "Puzzles"
                local filename = "v" .. VERSION .. "-" .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec) .. "-" .. config.name .. "-Failed" .. "-Puzzle"
                filename = filename .. ".txt"
                write_replay_file()
                write_replay_file(path, filename)
                ret = {main_dumb_transition, {main_select_puzz, loc("pl_you_lose"), 30, -1}}
              end
            end
            if P1.n_active_panels ~= 0 or P1.prev_active_panels ~= 0 or P1.puzzle_moves ~= 0 then
              P1:run()
              P1:handle_pause()
              if menu_escape_game(K[1]) then
                ret = {main_dumb_transition, {main_select_puzz, "", 0, 0}}
              end
            end
          end
        end
      )
      if ret then
        return unpack(ret)
      end
    end
  end
  return next_func
end

do
  local items = {}
  for key, val in spairs(puzzle_sets) do
    items[#items + 1] = {key, make_main_puzzle(val)}
  end
  items[#items + 1] = {"back", main_select_mode}
  function main_select_puzz()
    if themes[config.theme].musics.main then
      find_and_add_music(themes[config.theme].musics, "main")
    end
    background = themes[config.theme].images.bg_main
    reset_filters()
    local active_idx = last_puzzle_idx or 1
    local k = K[1]
    while true do
      local to_print = ""
      local arrow = ""
      for i = 1, #items do
        if active_idx == i then
          arrow = arrow .. ">"
        else
          arrow = arrow .. "\n"
        end
        local loc_item = (items[i][1] == "back") and loc("back") or items[i][1]
        to_print = to_print .. "   " .. loc_item .. "\n"
      end
      gprint(loc("pz_puzzles"), unpack(main_menu_screen_pos))
      gprint(loc("pz_info"), main_menu_screen_pos[1] - 280, main_menu_screen_pos[2] + 220)
      gprint(arrow, main_menu_screen_pos[1] + 100, main_menu_screen_pos[2])
      gprint(to_print, main_menu_screen_pos[1] + 100, main_menu_screen_pos[2])
      wait()
      local ret = nil
      variable_step(
        function()
          if menu_up(k) then
            active_idx = wrap(1, active_idx - 1, #items)
          elseif menu_down(k) then
            active_idx = wrap(1, active_idx + 1, #items)
          elseif menu_enter(k) then
            last_puzzle_idx = active_idx
            ret = {items[active_idx][2], items[active_idx][3]}
          elseif menu_escape(k) then
            if active_idx == #items then
              ret = {items[active_idx][2], items[active_idx][3]}
            else
              active_idx = #items
            end
          end
        end
      )
      if ret then
        return unpack(ret)
      end
    end
  end
end


-- menu for setting the username
function main_set_name()
  local name = config.name or ""
  love.keyboard.setTextInput(true) -- enables user to type
  while true do
    local to_print = loc("op_enter_name") .. "\n" .. name
    if (love.timer.getTime() * 3) % 2 > 1 then
      to_print = to_print .. "|"
    end
    gprint(to_print, unpack(main_menu_screen_pos))
    wait()
    local ret = nil
    variable_step(
      function()
        if this_frame_keys["escape"] then
          ret = {main_select_mode}
        end
        if menu_enter(K[1]) then
          config.name = name
          write_conf_file()
          ret = {main_select_mode}
        end
        if menu_backspace(K[1]) then
          -- Remove the last character.
          -- This could be a UTF-8 character, so handle it properly.
          local utf8offset = utf8.offset(name, -1)
          if utf8offset then
            name = string.sub(name, 1, utf8offset - 1)
          end
        end
        for _, v in ipairs(this_frame_unicodes) do
          name = name .. v
        end
      end
    )
    if ret then
      love.keyboard.setTextInput(false)
      return unpack(ret)
    end
  end
end

-- opens up music test menue
function main_music_test()
  gprint(loc("op_music_load"), unpack(main_menu_screen_pos))
  wait()
  -- load music for characters/stages that are not fully loaded
  for _, character_id in ipairs(characters_ids_for_current_theme) do
    if not characters[character_id].fully_loaded then
      characters[character_id]:sound_init(true, false)
    end
  end
  for _, stage_id in ipairs(stages_ids_for_current_theme) do
    if not stages[stage_id].fully_loaded then -- we perform the same although currently no stage are being loaded at this point
      stages[stage_id]:sound_init(true, false)
    end
  end

  local index = 1
  local tracks = {}

  for _, character_id in ipairs(characters_ids_for_current_theme) do
    local character = characters[character_id]
    if character.musics.normal_music then
      tracks[#tracks + 1] = {
        is_character = true,
        name = character.display_name .. ": normal_music",
        id = character_id,
        type = "normal_music",
        start = character.musics.normal_music_start or zero_sound,
        loop = character.musics.normal_music
      }
    end
    if character.musics.danger_music then
      tracks[#tracks + 1] = {
        is_character = true,
        name = character.display_name .. ": danger_music",
        id = character_id,
        type = "danger_music",
        start = character.musics.danger_music_start or zero_sound,
        loop = character.musics.danger_music
      }
    end
  end
  for _, stage_id in ipairs(stages_ids_for_current_theme) do
    local stage = stages[stage_id]
    if stage.musics.normal_music then
      tracks[#tracks + 1] = {
        is_character = false,
        name = stage.display_name .. ": normal_music",
        id = stage_id,
        type = "normal_music",
        start = stage.musics.normal_music_start or zero_sound,
        loop = stage.musics.normal_music
      }
    end
    if stage.musics.danger_music then
      tracks[#tracks + 1] = {
        is_character = false,
        name = stage.display_name .. ": danger_music",
        id = stage_id,
        type = "danger_music",
        start = stage.musics.danger_music_start or zero_sound,
        loop = stage.musics.danger_music
      }
    end
  end

  -- stop main music
  stop_all_audio()

  -- initial song starts here
  find_and_add_music(tracks[index].is_character and characters[tracks[index].id].musics or stages[tracks[index].id].musics, tracks[index].type)

  while true do
    tp = loc("op_music_current") .. tracks[index].name
    tp = tp .. (table.getn(currently_playing_tracks) == 1 and "\n" .. loc("op_music_intro") .. "\n" or "\n" .. loc("op_music_loop") .. "\n")
    min_time = math.huge
    for k, _ in pairs(music_t) do
      if k and k < min_time then
        min_time = k
      end
    end
    tp = tp .. string.format("%d", min_time - love.timer.getTime())
    tp = tp .. "\n\n\n" .. loc("op_music_nav", "<", ">", "ESC")
    gprint(tp, unpack(main_menu_screen_pos))
    wait()
    local ret = nil
    variable_step(
      function()
        if menu_left(K[1]) or menu_right(K[1]) or menu_escape(K[1]) then
          stop_the_music()
        end
        if menu_left(K[1]) then
          index = index - 1
        end
        if menu_right(K[1]) then
          index = index + 1
        end
        if index > #tracks then
          index = 1
        end
        if index < 1 then
          index = #tracks
        end
        if menu_left(K[1]) or menu_right(K[1]) then
          find_and_add_music(tracks[index].is_character and characters[tracks[index].id].musics or stages[tracks[index].id].musics, tracks[index].type)
        end

        if menu_escape(K[1]) then
          -- unloads music for characters/stages that are not fully loaded (they have been loaded when entering this submenu)
          for _, character_id in ipairs(characters_ids_for_current_theme) do
            if not characters[character_id].fully_loaded then
              characters[character_id]:sound_uninit()
            end
          end
          for _, stage_id in ipairs(stages_ids_for_current_theme) do
            if not stages[stage_id].fully_loaded then
              stages[stage_id]:sound_uninit()
            end
          end

          ret = {main_select_mode}
        end
      end
    )
    if ret then
      return unpack(ret)
    end
  end
end

-- toggles fullscreen
function fullscreen()
  love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
  return main_select_mode
end

-- returns true if the user input to exit a local game in progress
function menu_escape_game(k) 
  if game_is_paused and menu_escape(K[1]) then
    return true
  end
  return false
end


-- dumb transition that shows a black screen
function main_dumb_transition(next_func, text, timemin, timemax, winnerSFX)
  if P1 and P1.character then
    characters[P1.character]:stop_sounds()
  end
  if P2 and P2.character then
    characters[P2.character]:stop_sounds()
  end
  game_is_paused = false
  stop_all_audio()
  winnerSFX = winnerSFX or nil
  if not SFX_mute then
    -- TODO: somehow winnerSFX can be 0 instead of nil
    if winnerSFX ~= nil and winnerSFX ~= 0 then
      winnerSFX:play()
    elseif SFX_GameOver_Play == 1 then
      print(debug.traceback(""))
      themes[config.theme].sounds.game_over:play()
    end
  end
  SFX_GameOver_Play = 0

  reset_filters()
  text = text or ""
  timemin = timemin or 0
  timemax = timemax or -1 -- negative values means the user needs to press enter/escape to continue
  local t = 0
  local k = K[1]
  local font = love.graphics.getFont()
  while true do
    gprint(text, (canvas_width - font:getWidth(text)) / 2, (canvas_height - font:getHeight(text)) / 2)
    wait()
    local ret = nil
    variable_step(
      function()
        if t >= timemin and ((t >= timemax and timemax >= 0) or (menu_enter(k) or menu_escape(k))) then
          ret = {next_func}
        end
        t = t + 1
        --if network_connected() then
        --  if not do_messages() then
        --    -- do something? probably shouldn't drop back to the main menu transition since we're already here
        --  end
        --end
      end
    )
    if ret then
      return unpack(ret)
    end
  end
end
-- show game over screen, last frame of gameplay
function game_over_transition(next_func, text, winnerSFX, timemax)
  game_is_paused = false
  
  timemax = timemax or -1 -- negative values means the user needs to press enter/escape to continue
  text = text or ""
  button_text = loc("continue_button")
  button_text = button_text or ""

  timemin = 60 -- the minimum amount of frames the game over screen will be displayed for

  local t = 0 -- the amount of frames that have passed since the game over screen was displayed
  local k = K[1]
  local font = love.graphics.getFont()

  if SFX_GameOver_Play == 1 then
    themes[config.theme].sounds.game_over:play()
    SFX_GameOver_Play = 0
  end

  while true do
    if P1 then
      P1:render()
    end
    if P2 then
      P2:render()
    end
    gprint(text, (canvas_width - font:getWidth(text)) / 2, (canvas_height - font:getHeight(text)) / 2)
    gprint(button_text, (canvas_width - font:getWidth(button_text)) / 2, ((canvas_height - font:getHeight(button_text)) / 2) + 30)
    wait()
    local ret = nil
    variable_step(
      function()
        -- Fade the music out over time
        local fadeMusicLength = 3 * 60
        if t <= fadeMusicLength then
          set_music_fade_percentage((fadeMusicLength - t) / fadeMusicLength)
        else
          if t == fadeMusicLength + 1 then
            set_music_fade_percentage(1) -- reset the music back to normal config volume
            stop_all_audio()
          end
        end

        -- Play the winner sound effect after a delay
        winnerSFX = winnerSFX or nil
        if not SFX_mute then
          local winnerTime = 60
          if t >= winnerTime then
            -- TODO: somehow winnerSFX can be 0 instead of nil
            if winnerSFX ~= nil and winnerSFX ~= 0 then -- play winnerSFX then nil it so it doesn't loop
              print(winnerSFX)
              winnerSFX:play()
              winnerSFX = nil
            end
          end
        end

        if P1 then
          P1:run()
        end
        if P2 then
          P2:run()
        end

        if network_connected() then
          do_messages() -- recieve messages so we know if the next game is in the queue
        end

        local new_match_started = false -- Whether a message has been sent that indicates a match has started
        if this_frame_messages then
          for _, msg in ipairs(this_frame_messages) do
            -- if a new match has started flag the match started variable
            if msg.match_start or replay_of_match_so_far then
              new_match_started = true
            end
          end
        end

        -- if conditions are met, leave the game over screen
        if t >= timemin and ((t >= timemax and timemax >= 0) or (menu_enter(k) or menu_escape(k))) or new_match_started then
          set_music_fade_percentage(1) -- reset the music back to normal config volume
          stop_all_audio()
          SFX_GameOver_Play = 0
          analytics.game_ends(P1.analytic)
          ret = {next_func}
        end
        t = t + 1
      end
    )
    if ret then
      GAME.match = nil
      P1 = nil
      P2 = nil
      return unpack(ret)
    end
  end
end

-- quits the game
function exit_game(...)
  love.event.quit()
  return main_select_mode
end
-- quit handling
function love.quit()
  love.audio.stop()
  if love.window.getFullscreen() == true then
    null, null, config.display = love.window.getPosition()
  else
    config.window_x, config.window_y, config.display = love.window.getPosition()
    config.window_x = math.max(config.window_x, 0)
    config.window_y = math.max(config.window_y, 30) --don't let 'y' be zero, or the title bar will not be visible on next launch.
  end
  config.fullscreen = love.window.getFullscreen()
  write_conf_file()
end
