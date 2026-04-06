-- ============================================================================
-- NEXUS-OS  /lib/gui/workspace.lua
-- Root workspace: full-screen container, owns event loop, manages redraws
-- ============================================================================

local Container = require("gui.container")
local Screen    = require("gui.screen")

local Workspace = setmetatable({}, {__index = Container})
Workspace.__index = Workspace

--- Create a new workspace (full-screen root container).
function Workspace.new()
  local W, H = Screen.getSize()
  local self = Container.new(1, 1, W, H)
  setmetatable(self, Workspace)
  self.running     = false
  self.needsRedraw = true
  self.onDraw      = nil   -- optional callback after draw
  self.onEvent     = nil   -- optional pre-event filter
  return self
end

--- Full redraw: clear, draw all children, flush buffer.
function Workspace:redraw()
  local T = require("theme")
  Screen.activateBuffer()
  Screen.clear(T.get("desktop_bg"))
  if self.drawBackground then
    self.drawBackground(self, Screen)
  end
  self:draw(Screen)
  if self.onDraw then
    self.onDraw(self, Screen)
  end
  Screen.flush()
  self.needsRedraw = false
end

--- Override invalidate for root workspace
function Workspace:invalidate()
  self.needsRedraw = true
end

--- Request a redraw on next tick
function Workspace:requestRedraw()
  self.needsRedraw = true
end

--- Start the workspace event loop (blocks until stopped).
-- This should be run inside a process coroutine.
function Workspace:start()
  self.running = true
  self:redraw()

  while self.running do
    -- Pull event from the scheduler (yields to kernel)
    local signal = table.pack(coroutine.yield())

    if signal.n > 0 then
      local eventName = signal[1]

      -- Pre-filter
      if self.onEvent then
        local consumed = self.onEvent(self, eventName, table.unpack(signal, 2, signal.n))
        if consumed then goto continue end
      end

      -- Route to children
      self:eventHandler(self, eventName, table.unpack(signal, 2, signal.n))

      -- Handle screen resize
      if eventName == "screen_resized" then
        local W, H = Screen.getSize()
        self.width = W
        self.height = H
        self.needsRedraw = true
      end

      -- Handle theme change
      if eventName == "theme_changed" then
        self.needsRedraw = true
      end

      ::continue::
    end

    -- Redraw if needed
    if self.needsRedraw then
      self:redraw()
    end
  end
end

--- Stop the workspace event loop.
function Workspace:stop()
  self.running = false
end

--- Check if workspace contains a point (always true — it's full screen)
function Workspace:contains(px, py)
  return true
end

--- Absolute position of workspace is always (1,1)
function Workspace:absolutePosition()
  return 1, 1
end

return Workspace
