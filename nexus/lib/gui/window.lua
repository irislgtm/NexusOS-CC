-- ============================================================================
-- NEXUS-OS  /lib/gui/window.lua
-- Window Manager: z-ordered windows with drag, close, minimize, resize
-- ============================================================================

local Container = require("gui.container")
local Screen    = require("gui.screen")
local T         = require("theme")

local WM = {}
WM.windows  = {}   -- ordered list: first = bottom, last = top
WM.focused  = nil   -- currently focused window
WM.workspace = nil  -- reference to root workspace (set by desktop)
WM.taskbar   = nil  -- reference to taskbar (set by desktop)

----------------------------------------------------------------------------
-- Window class
----------------------------------------------------------------------------
local Window = setmetatable({}, {__index = Container})
Window.__index = Window

--- Open a new window.
-- @param opts  Table: { title, x, y, w, h, app, closable, resizable, minimizable }
-- @return window container
function WM.open(opts)
  opts = opts or {}
  local w = opts.w or 60
  local h = opts.h or 20
  local x = opts.x or math.floor((160 - w) / 2) + 1
  local y = opts.y or math.floor((50 - h) / 2) + 1

  local win = Container.new(x, y, w, h)
  setmetatable(win, Window)

  win.meta = {
    title       = opts.title or "Window",
    app         = opts.app or nil,
    closable    = opts.closable ~= false,
    resizable   = opts.resizable ~= false,
    minimizable = opts.minimizable ~= false,
    minimized   = false,
    id          = tostring(#WM.windows + 1) .. "-" .. tostring(os and os.clock and os.clock() or 0),
    icon        = opts.icon or nil,
  }

  -- Dragging state
  win._dragging = nil
  win._resizing = nil

  -- Content area: the usable area inside the window (below titlebar, inside border)
  win.body = Container.new(2, 2, w - 2, h - 2)
  win:addChild(win.body)

  -- Register with WM
  WM.windows[#WM.windows + 1] = win
  WM.focus(win)

  -- Add to workspace if available
  if WM.workspace then
    WM.workspace:addChild(win)
    WM.workspace:requestRedraw()
  end

  -- Notify taskbar
  if WM.taskbar and WM.taskbar.refresh then
    WM.taskbar:refresh()
  end

  return win
end

--- Draw the window (border, titlebar, body).
function Window:draw(screen)
  if not self.visible or (self.meta and self.meta.minimized) then return end

  local isFocused = (WM.focused == self)
  local x, y = self:absolutePosition()
  local w, h = self.width, self.height

  -- Window background & border
  local borderColor = isFocused and T.get("window_border") or T.get("window_border_inactive")
  local bgColor = T.get("window_bg")

  screen.fillRect(x, y, w, h, bgColor)
  screen.drawBorder(x, y, w, h, borderColor, bgColor, "single")

  -- Titlebar
  local tbBg = isFocused and T.get("titlebar_active_bg") or T.get("titlebar_bg")
  local tbFg = isFocused and T.get("titlebar_active_fg") or T.get("titlebar_fg")
  screen.fillRect(x + 1, y, w - 2, 1, tbBg)

  -- Title text (clipped)
  local title = self.meta.title or ""
  local maxTitle = w - 8  -- leave room for buttons
  if #title > maxTitle then title = title:sub(1, maxTitle - 2) .. ".." end
  screen.drawText(x + 2, y, " " .. title .. " ", tbFg, tbBg)

  -- Close button [X]
  if self.meta.closable then
    screen.drawText(x + w - 2, y, "×", T.get("alert_error"), tbBg)
  end

  -- Minimize button [_]
  if self.meta.minimizable then
    local mPos = self.meta.closable and (x + w - 4) or (x + w - 2)
    screen.drawText(mPos, y, "─", T.get("text_secondary"), tbBg)
  end

  -- Resize indicator (bottom-right corner)
  if self.meta.resizable then
    screen.drawChar(x + w - 1, y + h - 1, "◢", T.get("text_muted"), bgColor)
  end

  -- Draw body and children
  -- Update body dimensions in case window was resized
  self.body.x = 2
  self.body.y = 2
  self.body.width = w - 2
  self.body.height = h - 2

  Container.draw(self, screen)
end

--- Handle window-level events (drag, close, minimize, resize).
function Window:eventHandler(workspace, eventName, ...)
  if not self.visible or (self.meta and self.meta.minimized) then return false end

  local args = {...}

  if eventName == "touch" then
    local screenAddr, px, py, button = args[1], args[2], args[3], args[4]
    local ax, ay = self:absolutePosition()

    -- Focus this window
    WM.focus(self)

    -- Check close button
    if self.meta.closable and py == ay and px == ax + self.width - 2 then
      WM.close(self)
      return true
    end

    -- Check minimize button
    if self.meta.minimizable then
      local mPos = self.meta.closable and (ax + self.width - 4) or (ax + self.width - 2)
      if py == ay and px == mPos then
        WM.minimize(self)
        return true
      end
    end

    -- Check resize handle (bottom-right 2x1 area)
    if self.meta.resizable and px >= ax + self.width - 2 and py == ay + self.height - 1 then
      self._resizing = { ox = px, oy = py, ow = self.width, oh = self.height }
      return true
    end

    -- Titlebar drag
    if py == ay and px >= ax and px < ax + self.width - 2 then
      self._dragging = { ox = px - self.x, oy = py - self.y }
      return true
    end

    -- Forward to body/children
    return Container.eventHandler(self, workspace, eventName, ...)

  elseif eventName == "drag" then
    local screenAddr, px, py = args[1], args[2], args[3]

    if self._dragging then
      self.x = math.max(1, math.min(160 - self.width + 1, px - self._dragging.ox))
      self.y = math.max(1, math.min(50 - self.height + 1, py - self._dragging.oy))
      if workspace.requestRedraw then workspace:requestRedraw() end
      return true
    end

    if self._resizing then
      local newW = math.max(10, self._resizing.ow + (px - self._resizing.ox))
      local newH = math.max(5, self._resizing.oh + (py - self._resizing.oy))
      newW = math.min(newW, 160 - self.x + 1)
      newH = math.min(newH, 50 - self.y + 1)
      self.width = newW
      self.height = newH
      if workspace.requestRedraw then workspace:requestRedraw() end
      return true
    end

    return Container.eventHandler(self, workspace, eventName, ...)

  elseif eventName == "drop" then
    self._dragging = nil
    self._resizing = nil
    return false

  elseif eventName == "key_down" then
    -- Forward keyboard events only to focused window
    if WM.focused == self then
      return Container.eventHandler(self, workspace, eventName, ...)
    end
    return false

  else
    -- Forward other events
    if WM.focused == self then
      return Container.eventHandler(self, workspace, eventName, ...)
    end
    return false
  end
end

----------------------------------------------------------------------------
-- WM management functions
----------------------------------------------------------------------------

--- Close a window and remove it from the WM.
function WM.close(win)
  -- Call app close handler
  if win.meta and win.meta.app and win.meta.app.close then
    pcall(win.meta.app.close)
  end

  -- Remove from windows list
  for i, w in ipairs(WM.windows) do
    if w == win then
      table.remove(WM.windows, i)
      break
    end
  end

  -- Remove from workspace
  if WM.workspace then
    WM.workspace:removeChild(win)
  end

  -- Update focus
  if WM.focused == win then
    WM.focused = WM.windows[#WM.windows] or nil
  end

  -- Refresh taskbar and redraw
  if WM.taskbar and WM.taskbar.refresh then
    WM.taskbar:refresh()
  end
  if WM.workspace then
    WM.workspace:requestRedraw()
  end
end

--- Focus a window (bring to front).
function WM.focus(win)
  if win.meta and win.meta.minimized then return end

  -- Move to end of windows list (top of z-order)
  for i, w in ipairs(WM.windows) do
    if w == win then
      table.remove(WM.windows, i)
      break
    end
  end
  WM.windows[#WM.windows + 1] = win

  -- Move to top in workspace
  if WM.workspace then
    WM.workspace:moveToTop(win)
    WM.workspace:requestRedraw()
  end

  WM.focused = win
end

--- Minimize a window (hide from screen, show in taskbar).
function WM.minimize(win)
  win.meta.minimized = true
  win.visible = false
  if WM.focused == win then
    WM.focused = nil
    -- Focus next visible window
    for i = #WM.windows, 1, -1 do
      if WM.windows[i].visible and not WM.windows[i].meta.minimized then
        WM.focused = WM.windows[i]
        break
      end
    end
  end
  if WM.taskbar and WM.taskbar.refresh then
    WM.taskbar:refresh()
  end
  if WM.workspace then
    WM.workspace:requestRedraw()
  end
end

--- Restore a minimized window.
function WM.restore(win)
  win.meta.minimized = false
  win.visible = true
  WM.focus(win)
end

--- Get all open windows.
function WM.getWindows()
  return WM.windows
end

--- Get window count.
function WM.count()
  return #WM.windows
end

--- Close all windows.
function WM.closeAll()
  while #WM.windows > 0 do
    WM.close(WM.windows[#WM.windows])
  end
end

return WM
