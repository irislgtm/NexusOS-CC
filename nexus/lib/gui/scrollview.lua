-- ============================================================================
-- NEXUS-OS  /lib/gui/scrollview.lua
-- Scrollable container with clipping
-- ============================================================================

local Container = require("gui.container")
local Screen    = require("gui.screen")
local T         = require("theme")

local ScrollView = setmetatable({}, {__index = Container})
ScrollView.__index = ScrollView

function ScrollView.new(x, y, w, h, contentHeight)
  local self = Container.new(x, y, w, h)
  setmetatable(self, ScrollView)
  self.contentHeight = contentHeight or h
  self.scrollY       = 0
  return self
end

function ScrollView:draw(screen)
  if not self.visible then return end
  -- For now, draw children with offset (GPU clipping is not automatic,
  -- but we only draw children whose Y falls within our viewport)
  for _, child in ipairs(self.children) do
    if child.visible then
      local origY = child.y
      child.y = origY - self.scrollY
      if child.y + (child.height or 1) > 0 and child.y <= self.height then
        child:draw(screen)
      end
      child.y = origY
    end
  end

  -- Scrollbar
  local maxScroll = math.max(0, self.contentHeight - self.height)
  if maxScroll > 0 then
    local ax, ay = self:absolutePosition()
    local sbHeight = math.max(1, math.floor(self.height * self.height / self.contentHeight))
    local sbPos = math.floor(self.scrollY / maxScroll * (self.height - sbHeight))
    local sbX = ax + self.width - 1
    for i = 0, self.height - 1 do
      local ch = (i >= sbPos and i < sbPos + sbHeight) and "█" or "░"
      screen.drawChar(sbX, ay + i, ch, T.get("scrollbar_fg"), T.get("scrollbar_bg"))
    end
  end
end

function ScrollView:eventHandler(workspace, eventName, ...)
  if eventName == "scroll" then
    local args = {...}
    local screenAddr, px, py, direction = args[1], args[2], args[3], args[4]
    if self:contains(px, py) then
      local maxScroll = math.max(0, self.contentHeight - self.height)
      self.scrollY = math.max(0, math.min(maxScroll, self.scrollY - direction))
      self:invalidate()
      return true
    end
  end
  return Container.eventHandler(self, workspace, eventName, ...)
end

return ScrollView
