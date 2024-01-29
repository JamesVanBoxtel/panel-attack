local class = require("class")
local UIElement = require("ui.UIElement")
local GraphicsUtil = require("graphics_util")

--@module Label
local Label = class(
  function(self, options)
    self.hAlign = options.hAlign or "left"
    self.vAlign = options.vAlign or "top"

    self:setText(options.text, options.extraLabels, options.translate)

    self.TYPE = "Label"
  end,
  UIElement
)

function Label:setText(text, replacementTable, translate)
  -- whether we should translate the label or not
  if translate ~= nil then
    self.translate = translate
  elseif self.translate == nil then
    self.translate = true
  end

  if replacementTable then
    -- list of parameters for translating the label (e.g. numbers/names to replace placeholders with)
    self.replacementTable = replacementTable
  elseif not self.replacementTable then
    self.replacementTable = {}
  end

  if text then
    self.text = text
  end

  if self.translate then
    -- always need a new text cause the font might have changed
    self.drawable = love.graphics.newText(love.graphics.getFont(), loc(self.text, unpack(self.replacementTable)))
  else
    if self.drawable then
      self.drawable:set(self.text)
    else
      self.drawable = love.graphics.newText(love.graphics.getFont(), self.text)
    end
  end

  self.width, self.height = self.drawable:getDimensions()
end

function Label:refreshLocalization()
  if self.translate then
    -- always need a new text cause the font might have changed
    self.drawable = love.graphics.newText(love.graphics.getFont(), loc(self.text, unpack(self.replacementTable)))
    self.width, self.height = self.drawable:getDimensions()
  end
end

function Label:drawSelf()
  GraphicsUtil.drawClearText(self.drawable, self.x, self.y)
end

return Label