require("consts")

local function load_img(path_and_name)
  print(path_and_name)
  local img = nil
  pcall(
    function()
      img = love.image.newImageData(path_and_name)
    end
  )
  if img == nil then
    return nil
  end
  -- print("loaded asset: "..path_and_name)
  local ret = love.graphics.newImage(img)
  ret:setFilter("nearest","nearest")
  return ret
end

function load_img_from_supported_extensions(path_and_name)
  local supported_img_formats = { ".png", ".jpg" }
  for _, extension in ipairs(supported_img_formats) do
    if love.filesystem.getInfo(path_and_name..extension) then
      return load_img(path_and_name..extension)
    end
  end
  return nil
end

-- Draws an image at the given spot
-- TODO rename
function draw(img, x, y, rot, x_scale, y_scale)
  rot = rot or 0
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  gfx_q:push({love.graphics.draw, {img, x*GFX_SCALE, y*GFX_SCALE,
  rot, x_scale*GFX_SCALE, y_scale*GFX_SCALE}})
end

-- Draws a label image at the given spot.
-- TODO consolidate with above
function draw_label(img, x, y, rot, scale, mirror)
  rot = rot or 0
  mirror = mirror or 0
  x = x - (img:getWidth()/GFX_SCALE*scale)*mirror
  gfx_q:push({love.graphics.draw, {img, x*GFX_SCALE, y*GFX_SCALE,
  rot, scale, scale}})
end

-- Draws a number via a font image
-- TODO consolidate with draw_pixel_font which should encompass all this API
function draw_number(number, atlas, frameCount, quads, x, y, scale, x_scale, y_scale, align, mirror)
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  align = align or "left"
  mirror = mirror or 0
  
  local width = atlas:getWidth()
  local height = atlas:getHeight()
  local numberWidth = atlas:getWidth()/frameCount
  local numberHeight = atlas:getHeight()
  
  x = x - (numberWidth*GFX_SCALE*scale)*mirror

  if number == nil or atlas == nil or numberHeight == nil or numberWidth == nil then return end

  while #quads < #tostring(number) do
    table.insert(quads, love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height))
  end

  for i = 1, #tostring(number), 1 do
    local c = tostring(number):sub(i,i)
    if c == nil then return end
    quads[i]:setViewport(tonumber(c)*numberWidth, 0, numberWidth, numberHeight, width, height)
    if align == "left" then
      gfx_q:push({love.graphics.draw, {atlas, quads[i], ((x+(i*(13*scale)))-(13*scale)), y,
        0, x_scale, y_scale}})
    end
    if align == "center" then
      gfx_q:push({love.graphics.draw, {atlas, quads[i], (x+((i-(#tostring(number)/2))*(13*scale))), y,
        0, x_scale, y_scale}})
    end
    if align == "right" then
      gfx_q:push({love.graphics.draw, {atlas, quads[i], (x+((i-#tostring(number))*(13*scale))), y,
        0, x_scale, y_scale}})
    end
  end

end

-- Draws a time using a pixel font
-- TODO consolidate with draw_pixel_font which should encompass all this API
function draw_time(time, quads, x, y, x_scale, y_scale)
  x_scale = x_scale or 1
  y_scale = y_scale or 1

  if #quads == 0 then
    width = themes[config.theme].images.IMG_timeNumber_atlas:getWidth()
    height = themes[config.theme].images.IMG_timeNumber_atlas:getHeight()
    numberWidth = themes[config.theme].images.timeNumberWidth
    numberHeight = themes[config.theme].images.timeNumberHeight
    quads =
    {
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height)
    }

    symbolEnum = {[":"]=10, ["'"]=11, ["-"]=13}
    for i = 1, #time, 1 do
      local c = time:sub(i,i)

      if c ~= ":" and c ~= "'" and c ~= "-" then
        quads[i]:setViewport(tonumber(c)*numberWidth, 0, numberWidth, numberHeight, width, height)
      else
        quads[i]:setViewport(symbolEnum[c]*numberWidth, 0, numberWidth, numberHeight, width, height)
      end
      gfx_q:push({love.graphics.draw, {themes[config.theme].images.IMG_timeNumber_atlas, quads[i], ((x+(i*(20*themes[config.theme].time_Scale)))-(20*themes[config.theme].time_Scale))+((7-#time)*10), y,
          0, x_scale, y_scale}})
    end

  end
end

-- Returns the pixel font map for the pixel fonts that contain numbers and letters
-- a font map is a dictionary of a character mapped to the column number in the pixel font image
function standard_pixel_font_map()

  -- Special Characters
  local fontMap = {["&"]=36, ["?"]=37, ["!"]=38, ["%"]=39, ["*"]=40, ["."]=41}

  --0-9 = 0-9
  for i = 0, 9, 1 do
    fontMap[tostring(i)] = i
  end

  --10-35 = A-Z
  for i = 10, 35, 1 do
    local characterString = string.char(97+(i-10))
    fontMap[characterString] = i
    --print(characterString .. " = " .. fontMap[characterString])
  end

  return fontMap
end

-- Draws the given string with the given pixel font image atlas
-- string - the string to draw
-- TODO support both upper and lower case
-- atlas - the image to use as the pixel font
-- font map - a dictionary of a character mapped to the column number in the pixel font image
function draw_pixel_font(string, atlas, font_map, x, y, x_scale, y_scale, align, mirror)
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  align = align or "left"
  mirror = mirror or 0
  font_map = font_map or standard_pixel_font_map()

  local atlasFrameCount = tableLength(font_map)
  local atlasWidth = atlas:getWidth()
  local atlasHeight = atlas:getHeight()
  local characterWidth = atlasWidth/atlasFrameCount
  local characterHeight = atlasHeight
  local characterSpacing = 2 -- 3 -- 7 for time
  local characterDistance = characterWidth + characterSpacing

  x = x - (characterWidth*GFX_SCALE*x_scale)*mirror

  if string == nil or atlas == nil or atlasFrameCount == nil or characterWidth == nil or characterHeight == nil then
    print("Error initalizing draw pixel font")
    return 
  end

  local quads = {}

  while #quads < #string do
    table.insert(quads, love.graphics.newQuad(0, 0, characterWidth, characterHeight, atlasWidth, atlasHeight))
  end

  for i = 1, #string, 1 do
    local c = string:sub(i,i)
    if c == nil or c == " " then
      goto continue
    end

    local frameNumber = font_map[c]

    -- Select the portion of the atlas that is the current character
    quads[i]:setViewport(frameNumber*characterWidth, 0, characterWidth, characterHeight, atlasWidth, atlasHeight)

    local characterX = ((x+(i*(characterDistance*x_scale)))-(characterDistance*x_scale))
    if align == "center" then
      characterX = (x+((i-(#string/2))*(characterDistance*x_scale)))
    elseif align == "right" then
      characterX = (x+((i-#string)*(characterDistance*x_scale)))
    end

    -- Render it at the proper digit location
    gfx_q:push({love.graphics.draw, {atlas, quads[i], characterX, y, 0, x_scale, y_scale}})
    ::continue::
  end

end

-- Draws an image at the given position, using the quad for the viewport
function qdraw(img, quad, x, y, rot, x_scale, y_scale, x_offset, y_offset, mirror)
  rot = rot or 0
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  x_offset = x_offset or 0
  y_offset = y_offset or 0
  mirror = mirror or 0

  qX, qY, qW, qH = quad:getViewport()
  if mirror == 1 then
    x = x - (qW*x_scale)
  end
  gfx_q:push({love.graphics.draw, {img, quad, x*GFX_SCALE, y*GFX_SCALE,
    rot, x_scale*GFX_SCALE, y_scale*GFX_SCALE, x_offset, y_offset}})
end

function menu_draw(img, x, y, rot, x_scale,y_scale)
  rot = rot or 0
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  gfx_q:push({love.graphics.draw, {img, x, y,
    rot, x_scale, y_scale}})
end

function menu_drawf(img, x, y, halign, valign, rot, x_scale, y_scale)
  rot = rot or 0
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  halign = halign or "left"
  if halign == "center" then
    x = x - math.floor(img:getWidth() * 0.5 * x_scale)
  elseif halign == "right" then
    x = x - math.floor(img:getWidth() * x_scale)
  end
  valign = valign or "top"
  if valign == "center" then
    y = y - math.floor(img:getHeight() * 0.5 * y_scale)
  elseif valign == "bottom" then
    y = y - math.floor(img:getHeight() * y_scale)
  end
  gfx_q:push({love.graphics.draw, {img, x, y,
    rot, x_scale, y_scale}})
end

function menu_drawq(img, quad, x, y, rot, x_scale,y_scale)
  rot = rot or 0
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  gfx_q:push({love.graphics.draw, {img, quad, x, y,
    rot, x_scale, y_scale}})
end

-- Draws a rectangle at the given coordinates
function grectangle(mode, x, y, w, h)
  gfx_q:push({love.graphics.rectangle, {mode, x, y, w, h}})
end

-- Draws a colored rectangle at the given coordinates
function grectangle_color(mode, x, y, w, h, r, g, b, a)
  a = a or 1
  gfx_q:push({love.graphics.setColor, {r, g, b, a}})
  gfx_q:push({love.graphics.rectangle, {mode, x*GFX_SCALE, y*GFX_SCALE, w*GFX_SCALE, h*GFX_SCALE}})
  gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
end

-- Draws text at the given spot
-- TODO: Using color is broken...
function gprint(str, x, y, color, scale)
  x = x or 0
  y = y or 0
  scale = scale or 1
  color = color or nil
  set_color(0, 0, 0, 1)
  gfx_q:push({love.graphics.print, {str, x+1, y+1, 0, scale}})
  local r, g, b, a = 1,1,1,1
  if color ~= nil then
    r,g,b,a = unpack(color)
  end
  set_color(r,g,b,a)
  gfx_q:push({love.graphics.print, {str, x, y, 0, scale}})
end

-- font file to use
local font_file = nil
local font_size = 12
local font_cache = {}

function set_global_font(filepath, size)
  font_cache = {}
  font_file = filepath
  font_size = size
  local f
  if font_file then
    f = love.graphics.newFont(font_file, font_size)
  else
    f = love.graphics.newFont(font_size)
  end
  f:setFilter("nearest", "nearest")
  love.graphics.setFont(f)
end

-- Creates a new font based on the current font and a delta
local function get_font_delta(with_delta_size)
  local font_size = font_size + with_delta_size
  local f = font_cache[font_size]
  if not f then
    if font_file then
      f = love.graphics.newFont(font_file, font_size)
    else
      f = love.graphics.newFont(font_size)
    end
    font_cache[font_size] = f
  end
  return f
end

function set_font(font)
  gfx_q:push({love.graphics.setFont, {font}})
end

function set_shader(shader)
  gfx_q:push({love.graphics.setShader, {shader}})
end

-- Draws a font with a given font delta from the standard font
-- TODO: Using color is broken...
function gprintf(str, x, y, limit, halign, color, scale, font_delta_size)
  x = x or 0
  y = y or 0
  scale = scale or 1
  color = color or nil
  limit = limit or canvas_width
  font_delta_size = font_delta_size or 0
  halign = halign or "left"
  set_color(0, 0, 0, 1)
  local old_font = love.graphics.getFont()
  if font_delta_size ~= 0 then
    set_font(get_font_delta(font_delta_size)) 
  end
  gfx_q:push({love.graphics.printf, {str, x+1, y+1, limit, halign, 0, scale}})
  local r, g, b, a = 1,1,1,1
  if color ~= nil then
    r,g,b,a = unpack(color)
  end
  set_color(r,g,b,a)
  gfx_q:push({love.graphics.printf, {str, x, y, limit, halign, 0, scale}})
  if font_delta_size ~= 0 then set_font(old_font) end
end

local _r, _g, _b, _a
function set_color(r, g, b, a)
  a = a or 1
  -- only do it if this color isn't the same as the previous one...
  if _r~=r or _g~=g or _b~=b or _a~=a then
      _r,_g,_b,_a = r,g,b,a
      gfx_q:push({love.graphics.setColor, {r, g, b, a}})
  end
end

-- TODO this should be in a util file
function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function reset_filters()
  background_overlay = nil
  foreground_overlay = nil
end
