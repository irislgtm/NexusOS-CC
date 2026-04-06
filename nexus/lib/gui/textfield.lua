-- ============================================================================
-- NEXUS-OS  /lib/gui/textfield.lua
-- Editable single-line text input with cursor
-- ============================================================================

local Widget = require("gui.widget")
local Screen = require("gui.screen")
local T      = require("theme")

local TextField = setmetatable({}, {__index = Widget})
TextField.__index = TextField

--- Create a text field.
-- @param x,y          Position
-- @param w            Width
-- @param placeholder  Placeholder text when empty
function TextField.new(x, y, w, placeholder)
  local self = Widget.new(x, y, w, 1)
  setmetatable(self, TextField)
  self.text        = ""
  self.placeholder = placeholder or ""
  self.cursorPos   = 0    -- position in text (0 = before first char)
  self.scrollOff   = 0    -- horizontal scroll offset
  self.active      = false
  self.onChange     = nil  -- callback(self, newText)
  self.onSubmit    = nil  -- callback(self, text) when Enter pressed
  return self
end

function TextField:draw(screen)
  if not self.visible then return end
  local ax, ay = self:absolutePosition()

  local bg = self.active and T.get("highlight_bg") or T.get("window_bg")
  local fg = T.get("text_input")

  screen.fillRect(ax, ay, self.width, 1, bg)

  local display
  if #self.text == 0 and not self.active then
    display = self.placeholder
    fg = T.get("text_muted")
  else
    display = self.text
  end

  -- Apply scroll offset
  local visible = display:sub(self.scrollOff + 1, self.scrollOff + self.width)
  screen.drawText(ax, ay, visible, fg, bg)

  -- Underline border
  screen.drawHLine(ax, ay, self.width, "▁",
    self.active and T.get("accent") or T.get("border_dim"), bg)
end

function TextField:eventHandler(workspace, eventName, ...)
  if not self.visible then return false end
  local args = {...}

  if eventName == "touch" then
    local screenAddr, px, py = args[1], args[2], args[3]
    if self:contains(px, py) then
      self.active = true
      -- Set cursor position based on click
      local ax = self:absolutePosition()
      self.cursorPos = math.min(#self.text, self.scrollOff + (px - ax))
      self:invalidate()
      return true
    else
      if self.active then
        self.active = false
        self:invalidate()
      end
      return false
    end

  elseif eventName == "key_down" and self.active then
    local kbAddr, char, code = args[1], args[2], args[3]

    if char == 13 then -- Enter
      if self.onSubmit then self.onSubmit(self, self.text) end
      return true
    elseif char == 8 or code == 14 then -- Backspace
      if self.cursorPos > 0 then
        self.text = self.text:sub(1, self.cursorPos - 1) .. self.text:sub(self.cursorPos + 1)
        self.cursorPos = self.cursorPos - 1
        if self.onChange then self.onChange(self, self.text) end
        self:invalidate()
      end
      return true
    elseif code == 211 then -- Delete
      if self.cursorPos < #self.text then
        self.text = self.text:sub(1, self.cursorPos) .. self.text:sub(self.cursorPos + 2)
        if self.onChange then self.onChange(self, self.text) end
        self:invalidate()
      end
      return true
    elseif code == 203 then -- Left arrow
      if self.cursorPos > 0 then
        self.cursorPos = self.cursorPos - 1
        self:invalidate()
      end
      return true
    elseif code == 205 then -- Right arrow
      if self.cursorPos < #self.text then
        self.cursorPos = self.cursorPos + 1
        self:invalidate()
      end
      return true
    elseif code == 199 then -- Home
      self.cursorPos = 0
      self:invalidate()
      return true
    elseif code == 207 then -- End
      self.cursorPos = #self.text
      self:invalidate()
      return true
    elseif char >= 32 and char < 127 then
      self.text = self.text:sub(1, self.cursorPos) .. string.char(char) .. self.text:sub(self.cursorPos + 1)
      self.cursorPos = self.cursorPos + 1
      if self.onChange then self.onChange(self, self.text) end
      self:invalidate()
      return true
    end
  end

  return false
end

return TextField
