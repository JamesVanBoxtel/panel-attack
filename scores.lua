-- Holds on the current scores and records for game modes
Scores =
  class(
  function(self)
    self.vsSelf = {}
    for i = 1, 11, 1 do
      self.vsSelf[i] = {}
      self.vsSelf[i]["record"] = 0
      self.vsSelf[i]["last"] = 0
    end

    self.timeAttack1P = {}
    for i = 1, #difficulty_to_ncolors_1Ptime, 1 do
      self.timeAttack1P[i] = {}
      self.timeAttack1P[i]["record"] = 0
      self.timeAttack1P[i]["last"] = 0
    end

    self.endless = {}
    for i = 1, #difficulty_to_ncolors_1Ptime, 1 do
      self.endless[i] = {}
      self.endless[i]["record"] = 0
      self.endless[i]["last"] = 0
    end
    
  end
)

function Scores.saveVsSelfScoreForLevel(self, score, level)
  self.vsSelf[level]["last"] = score
  if self.vsSelf[level]["record"] < score then
    self.vsSelf[level]["record"] = score
  end
  write_score_file(self)
end

function Scores.lastVsScoreForLevel(self, level)
  return self.vsSelf[level]["last"]
end

function Scores.recordVsScoreForLevel(self, level)
  return self.vsSelf[level]["record"]
end

function Scores.saveTimeAttack1PScoreForLevel(self, score, level)
  self.timeAttack1P[level]["last"] = score
  if self.timeAttack1P[level]["record"] < score then
    self.timeAttack1P[level]["record"] = score
  end
  write_score_file(self)
end

function Scores.lastTimeAttack1PForLevel(self, level)
  return self.timeAttack1P[level]["last"]
end

function Scores.recordTimeAttack1PForLevel(self, level)
  return self.timeAttack1P[level]["record"]
end

function Scores.saveEndlessScoreForLevel(self, score, level)
  self.endless[level]["last"] = score
  if self.endless[level]["record"] < score then
    self.endless[level]["record"] = score
  end
  write_score_file(self)
end

function Scores.lastEndlessForLevel(self, level)
  return self.endless[level]["last"]
end

function Scores.recordEndlessForLevel(self, level)
  return self.endless[level]["record"]
end

function read_score_file()
  local scores = Scores()
  pcall(
    function()
      local file = love.filesystem.newFile("scores.json")
      file:open("r")
      local read_data = {}
      local teh_json = file:read(file:getSize())
      for k, v in pairs(json.decode(teh_json)) do
        read_data[k] = v
      end

      -- do stuff using read_data.version for retrocompatibility here

      --if type(read_data.vs1PRecord) == "number" then scores.vs1PRecord = read_data.vs1PRecord end
      --if type(read_data.vs1PCurrent) == "number" then scores.vs1PCurrent = read_data.vs1PCurrent end

      -- Ignore the scores save file if its the old format
      if read_data.vsSelf["last"] == nil then
        if read_data.vsSelf then scores.vsSelf = read_data.vsSelf end
        if read_data.timeAttack1P then scores.timeAttack1P = read_data.timeAttack1P end
        if read_data.endless then scores.endless = read_data.endless end
      end

      file:close()
    end
  )
  return scores
end

function write_score_file(scores)
  pcall(
    function()
      local file = love.filesystem.newFile("scores.json")
      file:open("w")
      file:write(json.encode(scores))
      file:close()
    end
  )
end

local scores = read_score_file()

return scores