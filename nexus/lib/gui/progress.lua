-- ============================================================================
-- NEXUS-OS  /lib/gui/progress.lua
-- Horizontal progress bar widget
-- ============================================================================

local Widget = require("gui.widget")
local Screen = require("gui.screen")
local T      = require("theme")

local Progress = setmetatable({}, {__index = Widget})
Progress.__index = Progress

--- Create a progress bar widget.
-- @param x,y   Position
-- @param w      Width (height is always 1)
-- @param value  Initial value 0..1
function Progress.new(x, y, w, value)
  local self = Widget.new(x, y, w, 1)
  setmetatable(self, Progress)
  self.value     = math.max(0, math.min(1, value or 0))
  self.showLabel = true
  self.fgColor   = nil  -- nil = theme default
  self.bgColor   = nil
  return self
end

--- Set progress value (0.0 .. 1.0)
function Progress:setValue(v)
  v = math.max(0, math.min(1, v or 0))
  if v ~= self.value then
    self.value = v
    self:invalidate()
  end
end

function Progress:draw(screen)
  if not self.visible then return end
  local ax, ay = self:absolutePosition()
  local w = self.width

  local fg = self.fgColor or T.get("accent")
  local bg = self.bgColor or T.get("window_bg")

  local filled = math.floor(self.value * w + 0.5)
  filled = math.max(0, math.min(w, filled))

  -- Filled portion
  if filled > 0 then
    screen.fillRect(ax, ay, filled, 1, fg)
  end
  -- Empty portion
  if filled < w then
    screen.fillRect(ax + filled, ay, w - filled, 1, bg)
  end

  -- Value label centered
  if self.showLabel then
    local label = tostring(math.floor(self.value * 100 + 0.5)) .. "%"
    local lx = ax + math.floor((w - #label) / 2)
    for i = 1, #label do
      local cx = lx + i - 1
      if cx >= ax and cx < ax + w then
        local inFilled = (cx - ax) < filled
        local ch = label:sub(i, i)
        local tfg = inFilled and bg or fg
        local tbg = inFilled and fg or bg
        screen.drawChar(cx, ay, ch, tfg, tbg)
      end
    end
  end
end

return Progress
