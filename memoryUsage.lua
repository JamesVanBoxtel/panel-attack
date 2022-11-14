local logger = require("logger")
local batteries = require("batteries")

local baseGarbage = 0
local currentGarbage = 0

function memoryStart()
    batteries(10, 200, nil)
    batteries(10, 200, nil)
    batteries(10, 200, nil)
    batteries(10, 200, nil)
    baseGarbage = collectgarbage("count")
end

function memoryEnd()

    local beforeGarbage = collectgarbage("count")
    batteries(10, 200, nil)
    batteries(10, 200, nil)
    batteries(10, 200, nil)
    batteries(10, 200, nil)
    local afterGarbage = collectgarbage("count")
    local memoryCollected = beforeGarbage - afterGarbage
    if memoryCollected > 0 then
      logger.warn("Garbage Collected: " .. memoryCollected .. " kb")
    end

    pcall(
    function()
        io.stdout:flush()
    end
    )
end