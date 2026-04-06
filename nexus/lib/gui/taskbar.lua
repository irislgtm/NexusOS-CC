-- ============================================================================
-- NEXUS-OS  /lib/gui/taskbar.lua
-- Auto-populated taskbar from WM.windows[], clock, status indicators
-- ============================================================================

local Container = require("gui.container")
local Screen    = require("gui.screen")
local T         = require("theme")

local Taskbar = setmetatable({}, {__index = Container})
Taskbar.__index = Taskbar

function Taskbar.new()
  local W, H = Screen.getSize()
  local self = Container.new(1, H, W, 1)
  setmetatable(self, Taskbar)
  self._items = {}  -- cached button data
  return self
end

--- Rebuild taskbar items from WM window list.
function Taskbar:refresh()
  self._items = {}
  local WM = require("gui.window")
  for _, win in ipairs(WM.windows) do
    self._items[#self._items + 1] = {
      title     = win.meta.title,
      minimized = win.meta.minimized,
      win       = win,
    }
  end
  self.needsRedraw = true
end

--- Draw the taskbar.
function Taskbar:draw(screen)
  if not self.visible then return end

  local ax, ay = self:absolutePosition()
  local w = self.width

  -- Taskbar background
  screen.fillRect(ax, ay, w, 1, T.get("taskbar_bg"))

  -- Left: NEXUS logo
  screen.drawText(ax, ay, " ◆ NEXUS ", T.get("text_bright"), T.get("taskbar_active_bg"))

  -- Window buttons
  local x = ax + 10
  for _, item in ipairs(self._items) do
    local label = " " .. item.title:sub(1, 12) .. " "
    local bg = item.minimized and T.get("taskbar_bg") or T.get("taskbar_active_bg")
    local fg = item.minimized and T.get("text_muted") or T.get("taskbar_fg")
    if x + #label > w - 20 then break end  -- leave room for clock
    screen.drawText(x, ay, label, fg, bg)
    item._x = x
    item._w = #label
    x = x + #label + 1
  end

  -- Right: clock + status
  local computer = computer or require("computer")
  local uptime = computer.uptime()
  local h = math.floor(uptime / 3600)
  local m = math.floor((uptime % 3600) / 60)
  local s = math.floor(uptime % 60)
  local clock = string.format("%02d:%02d:%02d", h, m, s)

  -- Threat indicator (only if motion driver is loaded)
  local threat = ""
  local motion = package.loaded and package.loaded["motion"]
  if motion and motion.isAvailable and motion.isAvailable() then
    local ok, contacts = pcall(motion.getContacts)
    if ok and contacts and #contacts > 0 then
      threat = " ⚠" .. #contacts .. " "
    end
  end

  local rightText = threat .. " " .. clock .. " "
  screen.drawText(w - #rightText + 1, ay, rightText, T.get("taskbar_fg"), T.get("taskbar_bg"))
end

--- Handle taskbar clicks (click window buttons to focus/restore).
function Taskbar:eventHandler(workspace, eventName, ...)
  if eventName == "touch" then
    local args = {...}
    local screenAddr, px, py = args[1], args[2], args[3]
    local ax, ay = self:absolutePosition()

    if py == ay then
      -- NEXUS logo click
      if px >= ax and px < ax + 10 then
        if self.onLogoClick then
          self.onLogoClick()
          return true
        end
      end
      local WM = require("gui.window")
      for _, item in ipairs(self._items) do
        if item._x and px >= item._x and px < item._x + item._w then
          if item.minimized then
            WM.restore(item.win)
          else
            if WM.focused == item.win then
              WM.minimize(item.win)
            else
              WM.focus(item.win)
            end
          end
          return true
        end
      end
    end
  end
  return false
end

return Taskbar
