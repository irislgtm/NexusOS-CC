-- ============================================================================
-- NEXUS-OS  /lib/gui/widget.lua
-- Base Widget class: position, size, visibility, event handling
-- ============================================================================

local Widget = {}
Widget.__index = Widget

--- Create a new base widget.
-- @param x,y    Position relative to parent (1-indexed)
-- @param w,h    Width and height
-- @return Widget instance
function Widget.new(x, y, w, h)
  local self = setmetatable({}, Widget)
  self.x       = x or 1
  self.y       = y or 1
  self.width   = w or 1
  self.height  = h or 1
  self.visible = true
  self.parent  = nil
  self.focused = false
  self.id      = nil    -- optional identifier
  self.data    = nil    -- arbitrary user data
  return self
end

--- Get absolute screen position by walking up the parent chain.
function Widget:absolutePosition()
  local ax, ay = self.x, self.y
  local p = self.parent
  while p do
    ax = ax + p.x - 1
    ay = ay + p.y - 1
    p = p.parent
  end
  return ax, ay
end

--- Check if a screen-absolute point is inside this widget.
function Widget:contains(px, py)
  local ax, ay = self:absolutePosition()
  return px >= ax and px < ax + self.width
     and py >= ay and py < ay + self.height
end

--- Draw the widget. Override in subclasses.
-- @param screen  The screen module (lib/gui/screen)
function Widget:draw(screen)
  -- Base widget draws nothing
end

--- Handle an event. Override in subclasses.
-- @param workspace  The root workspace
-- @param eventName  Signal name
-- @param ...        Signal arguments
-- @return boolean   true if event was consumed
function Widget:eventHandler(workspace, eventName, ...)
  return false
end

--- Mark this widget as needing redraw
function Widget:invalidate()
  -- Walk up to workspace and tell it to redraw
  local p = self.parent
  while p do
    if p.needsRedraw ~= nil then
      p.needsRedraw = true
    end
    p = p.parent
  end
end

return Widget
