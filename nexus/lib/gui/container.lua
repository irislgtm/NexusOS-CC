-- ============================================================================
-- NEXUS-OS  /lib/gui/container.lua
-- Container widget: holds children, handles layout, clipping, event routing
-- ============================================================================

local Widget = require("gui.widget")

local Container = setmetatable({}, {__index = Widget})
Container.__index = Container

--- Create a new container.
function Container.new(x, y, w, h)
  local self = Widget.new(x, y, w, h)
  setmetatable(self, Container)
  self.children = {}
  self.needsRedraw = true
  return self
end

--- Add a child widget. Sets the child's parent reference.
-- @param child  Widget or Container to add
-- @return child (for chaining)
function Container:addChild(child)
  child.parent = self
  self.children[#self.children + 1] = child
  self.needsRedraw = true
  return child
end

--- Remove a specific child.
function Container:removeChild(child)
  for i, c in ipairs(self.children) do
    if c == child then
      table.remove(self.children, i)
      child.parent = nil
      self.needsRedraw = true
      return true
    end
  end
  return false
end

--- Remove all children.
function Container:removeChildren()
  for _, c in ipairs(self.children) do
    c.parent = nil
  end
  self.children = {}
  self.needsRedraw = true
end

--- Move a child to the top of the draw order (rendered last = on top).
function Container:moveToTop(child)
  for i, c in ipairs(self.children) do
    if c == child then
      table.remove(self.children, i)
      self.children[#self.children + 1] = child
      self.needsRedraw = true
      return true
    end
  end
  return false
end

--- Move a child to the bottom of the draw order.
function Container:moveToBottom(child)
  for i, c in ipairs(self.children) do
    if c == child then
      table.remove(self.children, i)
      table.insert(self.children, 1, child)
      self.needsRedraw = true
      return true
    end
  end
  return false
end

--- Find a child by ID.
function Container:findChild(id)
  for _, c in ipairs(self.children) do
    if c.id == id then return c end
    if c.children then
      local found = c:findChild(id)
      if found then return found end
    end
  end
  return nil
end

--- Draw all visible children (back to front).
-- Children are drawn relative to this container's absolute position.
function Container:draw(screen)
  if not self.visible then return end
  for _, child in ipairs(self.children) do
    if child.visible then
      child:draw(screen)
    end
  end
  self.needsRedraw = false
end

--- Route events to children (front to back for click priority).
-- @return boolean  true if any child consumed the event
function Container:eventHandler(workspace, eventName, ...)
  if not self.visible then return false end

  -- For touch/click events, route to topmost child that contains the point
  if eventName == "touch" or eventName == "drag" or eventName == "drop"
     or eventName == "scroll" then
    local args = {...}
    local screenAddr, px, py = args[1], args[2], args[3]

    -- Iterate in reverse (topmost child first)
    for i = #self.children, 1, -1 do
      local child = self.children[i]
      if child.visible and child:contains(px, py) then
        if child:eventHandler(workspace, eventName, ...) then
          return true
        end
      end
    end
  else
    -- Non-positional events: route to focused child or broadcast
    for i = #self.children, 1, -1 do
      local child = self.children[i]
      if child.visible then
        if child:eventHandler(workspace, eventName, ...) then
          return true
        end
      end
    end
  end

  return false
end

--- Get child count
function Container:childCount()
  return #self.children
end

return Container
