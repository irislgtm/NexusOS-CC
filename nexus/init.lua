-- ============================================================================
-- NEXUS-OS  /init.lua  — Kernel Entry Point
-- Loads boot scripts, enters main event loop, never returns.
-- ============================================================================

local computer  = computer  or require("computer")
local component = component or require("component")

-- Minimal early GPU binding for boot messages
local _gpu = component.proxy(component.list("gpu")())
local _scr = component.list("screen")()
_gpu.bind(_scr, false)
local maxW, maxH = _gpu.maxResolution()
_gpu.setResolution(math.min(160, maxW), math.min(50, maxH))
_gpu.setDepth(_gpu.maxDepth())
_gpu.setBackground(0x000000)
_gpu.setForeground(0x00FF41)
_gpu.fill(1, 1, 160, 50, " ")
_gpu.set(1, 1, "NEXUS-OS v1.0 — Booting...")

----------------------------------------------------------------------------
-- Load boot scripts in explicit order (avoids picking up foreign OS files)
----------------------------------------------------------------------------
local bootFS   = component.proxy(computer.getBootAddress())
local bootDir  = "/boot/"
local bootList = {
  "01_hardware.lua",
  "02_memory.lua",
  "03_scheduler.lua",
  "04_events.lua",
}

for _, name in ipairs(bootList) do
  local path = bootDir .. name
  local handle = bootFS.open(path, "r")
  if handle then
    local chunks = {}
    while true do
      local data = bootFS.read(handle, 4096)
      if not data then break end
      chunks[#chunks + 1] = data
    end
    bootFS.close(handle)

    local source = table.concat(chunks)
    local fn, err = load(source, "=" .. path)
    if fn then
      local ok, result = xpcall(fn, function(e) return tostring(e) end)
      if not ok then
        _gpu.setForeground(0xFF0000)
        _gpu.set(1, 6, "BOOT FATAL: " .. path .. ": " .. tostring(result))
        while true do computer.pullSignal(10) end
      end
    else
      _gpu.setForeground(0xFF0000)
      _gpu.set(1, 6, "BOOT SYNTAX: " .. path .. ": " .. tostring(err))
      while true do computer.pullSignal(10) end
    end
  end
end

----------------------------------------------------------------------------
-- Post-boot: all systems should be initialized
-- _G.hw, _G.scheduler, _G.event, _G.require are now available
----------------------------------------------------------------------------

hw.gpu.set(1, 5, "[BOOT] All boot scripts loaded.")

-- Run boot animation (matrix rain + POST)
local animOk, bootAnim = pcall(require, "boot_anim")
if animOk and bootAnim then
  bootAnim.run(hw.gpu, 1.5)
end

-- Component hotplug support
event.listen("component_added", function(_, addr, ctype)
  hw.rescan()
end)
event.listen("component_removed", function(_, addr, ctype)
  hw.rescan()
end)

----------------------------------------------------------------------------
-- Launch desktop / boot animation (Phase 8)
-- For now, spawn a minimal shell process
----------------------------------------------------------------------------
local function kernelShell()
  -- Minimal interactive shell until desktop is implemented
  local gpu = hw.gpu
  gpu.fill(1, 1, hw.W, hw.H, " ")
  gpu.setForeground(0x00FF41)
  gpu.set(1, 1, "NEXUS-OS v1.0 — Kernel Shell")
  gpu.set(1, 2, "Type 'help' for commands. Type 'desktop' to launch GUI (when available).")
  gpu.setForeground(0x007744)
  gpu.set(1, 3, string.rep("─", hw.W))
  local row = 4
  local history = {}

  while true do
    gpu.setForeground(0x00FF41)
    gpu.set(1, row, "> ")
    gpu.setForeground(0xFFFFFF)

    -- Read input character by character via events
    local buf = ""
    local col = 3
    while true do
      local sig = table.pack(event.pull())
      if sig[1] == "key_down" then
        local char = sig[3]
        local code = sig[4]
        if char == 13 then -- Enter
          break
        elseif char == 8 or code == 14 then -- Backspace
          if #buf > 0 then
            buf = buf:sub(1, -2)
            col = col - 1
            gpu.set(col, row, " ")
          end
        elseif char >= 32 and char < 127 then
          buf = buf .. string.char(char)
          gpu.set(col, row, string.char(char))
          col = col + 1
        end
      end
    end

    -- Move to next row
    row = row + 1
    if row > hw.H - 1 then
      gpu.copy(1, 2, hw.W, hw.H - 2, 0, -1)
      gpu.fill(1, hw.H - 1, hw.W, 1, " ")
      row = hw.H - 1
    end

    -- Process command
    local cmd = buf:match("^%s*(.-)%s*$")
    if #cmd > 0 then
      history[#history + 1] = cmd
      local parts = {}
      for w in cmd:gmatch("%S+") do parts[#parts + 1] = w end
      local c = parts[1]:lower()

      if c == "help" then
        local lines = {
          "Commands:",
          "  help       — Show this help",
          "  status     — Show system status",
          "  ps         — List processes",
          "  components — List hardware",
          "  reboot     — Reboot computer",
          "  shutdown   — Shutdown computer",
          "  desktop    — Launch GUI desktop (when available)",
        }
        for _, line in ipairs(lines) do
          gpu.setForeground(0x00FF88)
          gpu.set(1, row, line)
          row = row + 1
          if row > hw.H - 1 then
            gpu.copy(1, 2, hw.W, hw.H - 2, 0, -1)
            gpu.fill(1, hw.H - 1, hw.W, 1, " ")
            row = hw.H - 1
          end
        end
      elseif c == "status" then
        gpu.setForeground(0x00FFCC)
        gpu.set(1, row, string.format("Uptime: %.1fs | Procs: %d | Listeners: %d | Timers: %d",
          computer.uptime(), scheduler.count(), event.listenerCount(), event.timerCount()))
        row = row + 1
      elseif c == "ps" then
        local procs = scheduler.list()
        gpu.setForeground(0x999999)
        gpu.set(1, row, string.format("%-6s %-20s %-10s %s", "PID", "NAME", "STATUS", "UPTIME"))
        row = row + 1
        for _, p in ipairs(procs) do
          gpu.setForeground(0x00FF88)
          gpu.set(1, row, string.format("%-6d %-20s %-10s %.1fs", p.pid, p.name, p.status, p.uptime))
          row = row + 1
          if row > hw.H - 1 then
            gpu.copy(1, 2, hw.W, hw.H - 2, 0, -1)
            gpu.fill(1, hw.H - 1, hw.W, 1, " ")
            row = hw.H - 1
          end
        end
      elseif c == "components" then
        gpu.setForeground(0x999999)
        gpu.set(1, row, string.format("%-38s %s", "ADDRESS", "TYPE"))
        row = row + 1
        for addr, ctype in component.list() do
          gpu.setForeground(0x00CCFF)
          gpu.set(1, row, string.format("%-38s %s", addr:sub(1, 36), ctype))
          row = row + 1
          if row > hw.H - 1 then
            gpu.copy(1, 2, hw.W, hw.H - 2, 0, -1)
            gpu.fill(1, hw.H - 1, hw.W, 1, " ")
            row = hw.H - 1
          end
        end
      elseif c == "reboot" then
        computer.shutdown(true)
      elseif c == "shutdown" then
        computer.shutdown(false)
      elseif c == "desktop" then
        -- Try to launch the desktop
        local ok, err = pcall(function()
          local desktop = require("desktop")
          desktop.start()
        end)
        if not ok then
          gpu.setForeground(0xFFAA00)
          gpu.set(1, row, "Desktop not available yet: " .. tostring(err))
          row = row + 1
        end
      else
        gpu.setForeground(0xFF8800)
        gpu.set(1, row, "Unknown command: " .. c)
        row = row + 1
      end
    end

    if row > hw.H - 1 then
      gpu.copy(1, 2, hw.W, hw.H - 2, 0, -1)
      gpu.fill(1, hw.H - 1, hw.W, 1, " ")
      row = hw.H - 1
    end
  end
end

-- Spawn kernel shell as PID 1
scheduler.spawn(kernelShell, "kernel-shell")

----------------------------------------------------------------------------
-- KERNEL MAIN LOOP — never returns
-- 1. Pull signal (or pop synthetic)
-- 2. Dispatch to event handlers
-- 3. Resume all process coroutines with signal
----------------------------------------------------------------------------
hw.gpu.set(1, 6, "[BOOT] Kernel main loop starting...")
computer.pullSignal(0.5)  -- Brief pause for visual

while true do
  -- Check for synthetic events first
  local signal = event.popPushed()
  if not signal then
    -- Pull from hardware (0.05s = ~20 ticks/sec responsiveness)
    signal = table.pack(computer.pullSignal(0.05))
    if signal.n == 0 then signal = nil end
  end

  -- Dispatch to registered handlers and fire timers
  event.dispatch(signal)

  -- Resume all process coroutines
  scheduler.tick(signal)
end
