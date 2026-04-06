-- ============================================================================
-- NEXUS-OS  /lib/gui/button.lua
-- Clickable button widget
-- ============================================================================

local Widget = require("gui.widget")
local Screen = require("gui.screen")
local T      = require("theme")

local Button = setmetatable({}, {__index = Widget})
Button.__index = Button

--- Create a new button.
-- @param x,y     Position (relative to parent)
-- @param w,h     Size (h defaults to 1)
-- @param text    Button label
-- @param onClick Callback function()
function Button.new(x, y, w, h, text, onClick)
  local self = Widget.new(x, y, w, h or 1)
  setmetatable(self, Button)
  self.text     = text or ""
  self.onClick  = onClick
  self.pressed  = false
  self.disabled = false
  return self
end

function Button:draw(screen)
  if not self.visible then return end
  local ax, ay = self:absolutePosition()

  local bg, fg
  if self.disabled then
    bg = T.get("button_bg")
    fg = T.get("button_disabled_fg")
  elseif self.pressed then
    bg = T.get("button_active_bg")
    fg = T.get("button_fg")
  else
    bg = T.get("button_bg")
    fg = T.get("button_fg")
  end

  screen.fillRect(ax, ay, self.width, self.height, bg)

  -- Center text
  local label = self.text
  if #label > self.width - 2 then label = label:sub(1, self.width - 2) end
  local tx = ax + math.floor((self.width - #label) / 2)
  local ty = ay + math.floor(self.height / 2)
  screen.drawText(tx, ty, label, fg, bg)
end

function Button:eventHandler(workspace, eventName, ...)
  if not self.visible or self.disabled then return false end

  if eventName == "touch" then
    local args = {...}
    local screenAddr, px, py = args[1], args[2], args[3]
    if self:contains(px, py) then
      self.pressed = true
      self:invalidate()
      if self.onClick then
        self.onClick(self)
      end
      -- Auto-reset pressed state
      self.pressed = false
      return true
    end
  end
  return false
end

return Button
