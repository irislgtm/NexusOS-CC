-- ============================================================================
-- NEXUS-OS  /lib/gui/tabbar.lua
-- Horizontal tab strip widget
-- ============================================================================

local Widget = require("gui.widget")
local Screen = require("gui.screen")
local T      = require("theme")

local TabBar = setmetatable({}, {__index = Widget})
TabBar.__index = TabBar

--- Create a tab bar.
-- @param x,y   Position
-- @param w     Width
-- @param tabs  Array of { name = "Tab Name" }
function TabBar.new(x, y, w, tabs)
  local self = Widget.new(x, y, w, 1)
  setmetatable(self, TabBar)
  self.tabs       = tabs or {}
  self.activeTab  = 1
  self.onTabChanged = nil  -- callback(self, tabIndex, tabData)
  return self
end

function TabBar:draw(screen)
  if not self.visible then return end
  local ax, ay = self:absolutePosition()

  screen.fillRect(ax, ay, self.width, 1, T.get("window_bg"))

  local x = ax
  for i, tab in ipairs(self.tabs) do
    local label = " " .. (tab.name or "Tab") .. " "
    local bg = i == self.activeTab and T.get("highlight_bg") or T.get("window_bg")
    local fg = i == self.activeTab and T.get("highlight_fg") or T.get("text_muted")
    if x + #label > ax + self.width then break end
    screen.drawText(x, ay, label, fg, bg)
    tab._x = x
    tab._w = #label
    x = x + #label
  end
end

function TabBar:eventHandler(workspace, eventName, ...)
  if eventName == "touch" then
    local args = {...}
    local screenAddr, px, py = args[1], args[2], args[3]
    if not self:contains(px, py) then return false end
    for i, tab in ipairs(self.tabs) do
      if tab._x and px >= tab._x and px < tab._x + tab._w then
        if i ~= self.activeTab then
          self.activeTab = i
          if self.onTabChanged then
            self.onTabChanged(self, i, tab)
          end
          self:invalidate()
        end
        return true
      end
    end
  end
  return false
end

return TabBar
