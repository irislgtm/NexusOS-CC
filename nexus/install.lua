-- ============================================================================
-- NEXUS-OS  /install.lua
-- Standalone installer — run from OpenOS to deploy NEXUS-OS onto a drive
-- Usage: wget run <url>/install.lua
-- ============================================================================

local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local shell = require("shell")
local event = require("event")
local unicode = require("unicode")
local internet = component.internet

-- Config
local REPO_BASE = "https://raw.githubusercontent.com/irislgtm/NexusOS-CC/main/nexus/"
local INSTALL_ROOT = "/"
local VERSION = "1.0.0"

-- All files to install
local FILES = {
  -- Kernel & Boot
  "init.lua",
  "boot/01_hardware.lua",
  "boot/02_memory.lua",
  "boot/03_scheduler.lua",
  "boot/04_events.lua",

  -- Libraries
  "lib/serial.lua",
  "lib/config.lua",
  "lib/logger.lua",
  "lib/boot_anim.lua",
  "lib/desktop.lua",
  "lib/drone_server.lua",
  "lib/theme.lua",
  "lib/net.lua",
  "lib/process.lua",
  "lib/ipc.lua",

  -- GUI
  "lib/gui/screen.lua",
  "lib/gui/widget.lua",
  "lib/gui/container.lua",
  "lib/gui/workspace.lua",
  "lib/gui/window.lua",
  "lib/gui/taskbar.lua",
  "lib/gui/button.lua",
  "lib/gui/textfield.lua",
  "lib/gui/listview.lua",
  "lib/gui/scrollview.lua",
  "lib/gui/tabbar.lua",
  "lib/gui/chart.lua",
  "lib/gui/radar.lua",
  "lib/gui/progress.lua",
  "lib/gui/modal.lua",

  -- Drivers
  "drivers/gpu.lua",
  "drivers/keyboard.lua",
  "drivers/modem.lua",
  "drivers/geolyzer.lua",
  "drivers/motion.lua",
  "drivers/redstone.lua",
  "drivers/navigation.lua",
  "drivers/chunkloader.lua",
  "drivers/transposer.lua",
  "drivers/adapter.lua",
  "drivers/ae2.lua",
  "drivers/bigreactors.lua",
  "drivers/ic2.lua",
  "drivers/mekanism.lua",
  "drivers/draconic.lua",
  "drivers/enderio.lua",
  "drivers/thermal.lua",

  -- Shell & Utilities
  "bin/sh.lua",
  "bin/ls.lua",
  "bin/cat.lua",
  "bin/top.lua",
  "bin/ifconfig.lua",
  "bin/ping.lua",
  "bin/reboot.lua",
  "bin/edit.lua",

  -- Apps
  "apps/tracker.app/Main.lua",
  "apps/mapper.app/Main.lua",
  "apps/sigint.app/Main.lua",
  "apps/drones.app/Main.lua",
  "apps/ae2mon.app/Main.lua",
  "apps/reactor.app/Main.lua",
  "apps/netmon.app/Main.lua",
  "apps/terminal.app/Main.lua",
  "apps/settings.app/Main.lua",

  -- Drone Firmware
  "firmware/drone_boot.lua",
  "firmware/drone_core.lua",
  "firmware/drone_tail.lua",
  "firmware/drone_patrol.lua",
  "firmware/drone_orbit.lua",
  "firmware/drone_recon.lua",
}

-- Dirs to create
local DIRS = {
  "boot", "lib", "lib/gui", "drivers", "bin", "firmware",
  "apps", "apps/tracker.app", "apps/mapper.app", "apps/sigint.app",
  "apps/drones.app", "apps/ae2mon.app", "apps/reactor.app",
  "apps/netmon.app", "apps/terminal.app", "apps/settings.app",
  "etc", "var", "var/log", "var/maps", "var/drone_telemetry",
  "tmp",
}

-- Colors
local gpu = component.gpu
local W, H = gpu.getResolution()

local function setColor(fg, bg)
  if fg then gpu.setForeground(fg) end
  if bg then gpu.setBackground(bg) end
end

local function clearScreen()
  gpu.setBackground(0x000000)
  gpu.setForeground(0x00FF00)
  gpu.fill(1, 1, W, H, " ")
end

local function centerText(y, text)
  local len = unicode.len(text)
  local x = math.floor((W - len) / 2) + 1
  gpu.set(x, y, text)
end

local function drawProgress(y, current, total)
  local barW = math.floor(W * 0.6)
  local barX = math.floor((W - barW) / 2) + 1
  local filled = math.floor((current / total) * barW)

  gpu.setForeground(0x333333)
  gpu.fill(barX, y, barW, 1, "░")
  gpu.setForeground(0x00FF00)
  gpu.fill(barX, y, filled, 1, "█")

  local pct = math.floor((current / total) * 100)
  local label = string.format(" %d%% (%d/%d)", pct, current, total)
  gpu.setForeground(0xAAAAAA)
  gpu.set(barX + barW + 1, y, label)
end

-- Download a file from URL
local function download(url, dest)
  local request, err = internet.request(url)
  if not request then
    return false, "Request failed: " .. tostring(err)
  end

  local data = ""
  while true do
    local chunk = request.read(math.huge)
    if not chunk then break end
    data = data .. chunk
  end
  request.close()

  if #data == 0 then
    return false, "Empty response"
  end

  local f, ferr = io.open(dest, "w")
  if not f then
    return false, "Write failed: " .. tostring(ferr)
  end
  f:write(data)
  f:close()

  return true
end

-- Copy a local file
local function copyFile(src, dest)
  local f = io.open(src, "r")
  if not f then return false, "Source not found: " .. src end
  local data = f:read("*a")
  f:close()

  local o = io.open(dest, "w")
  if not o then return false, "Cannot write: " .. dest end
  o:write(data)
  o:close()
  return true
end

-- ===================== MAIN INSTALLER =====================

clearScreen()

-- Banner
setColor(0x00FF00, 0x000000)
centerText(2,  "╔════════════════════════════════════════════╗")
centerText(3,  "║         N E X U S - O S   v" .. VERSION .. "          ║")
centerText(4,  "║      Surveillance Operating System        ║")
centerText(5,  "╚════════════════════════════════════════════╝")
centerText(7,  "Autonomous Tracking · Mapping · Drone Control")

setColor(0xAAAAAA)
centerText(9,  "Install Location: " .. INSTALL_ROOT)
centerText(10, "Total Files: " .. #FILES)

-- Detect install mode
setColor(0xFFFF00)
centerText(12, "Select install mode:")
setColor(0x00FF00)
centerText(13, "[1] Local copy (files already on disk)")
centerText(14, "[2] Download from GitHub repository")
centerText(15, "[3] Cancel installation")

setColor(0xFFFFFF)
gpu.set(1, 17, "> ")

-- Read choice
local choice = nil
while not choice do
  local _, _, _, code = event.pull("key_down")
  if code == 0x02 then choice = 1    -- key '1'
  elseif code == 0x03 then choice = 2 -- key '2'
  elseif code == 0x04 then choice = 3 -- key '3'
  end
end

if choice == 3 then
  setColor(0xFF0000)
  centerText(17, "Installation cancelled.")
  return
end

-- Create directories
clearScreen()
setColor(0x00FF00)
centerText(2, "Creating directory structure...")

local line = 4
for _, dir in ipairs(DIRS) do
  local path = fs.concat(INSTALL_ROOT, dir)
  if not fs.isDirectory(path) then
    fs.makeDirectory(path)
  end
  gpu.setForeground(0x666666)
  gpu.set(3, line, "  mkdir " .. dir)
  line = line + 1
  if line > H - 5 then line = 4 end
end

-- Install files
clearScreen()
setColor(0x00FF00)
centerText(2, "Installing NEXUS-OS files...")
centerText(3, "─────────────────────────────────────")

local success = 0
local failed = 0
local errors = {}

for i, file in ipairs(FILES) do
  drawProgress(5, i, #FILES)

  local dest = fs.concat(INSTALL_ROOT, file)
  local ok, err

  if choice == 1 then
    -- Local mode: copy from current directory or nexus/ subfolder
    local src = fs.concat(shell.getWorkingDirectory(), file)
    if not fs.exists(src) then
      src = fs.concat(shell.getWorkingDirectory(), "nexus", file)
    end
    ok, err = copyFile(src, dest)
  else
    -- Download mode
    local url = REPO_BASE .. file
    ok, err = download(url, dest)
  end

  if ok then
    success = success + 1
    setColor(0x00FF00)
  else
    failed = failed + 1
    errors[#errors + 1] = file .. ": " .. tostring(err)
    setColor(0xFF5555)
  end

  -- Show current file
  local display = file
  if #display > W - 10 then
    display = "..." .. display:sub(-(W - 13))
  end
  gpu.fill(3, 7, W - 4, 1, " ")
  gpu.set(3, 7, (ok and "  ✓ " or "  ✗ ") .. display)

  os.sleep(0) -- yield
end

-- Create default config
local cfgPath = fs.concat(INSTALL_ROOT, "etc/os.cfg")
if not fs.exists(cfgPath) then
  local f = io.open(cfgPath, "w")
  if f then
    f:write('return {\n')
    f:write('  theme = "matrix",\n')
    f:write('  hostname = "nexus-' .. computer.address():sub(1, 4) .. '",\n')
    f:write('  autoDesktop = true,\n')
    f:write('}\n')
    f:close()
  end
end

-- Summary
clearScreen()
if failed == 0 then
  setColor(0x00FF00)
  centerText(3, "╔══════════════════════════════════════════╗")
  centerText(4, "║      INSTALLATION COMPLETE               ║")
  centerText(5, "╚══════════════════════════════════════════╝")
  centerText(7, string.format("Successfully installed %d files.", success))
  centerText(9, "NEXUS-OS is ready.")
  centerText(10, "Reboot the computer to start NEXUS-OS.")
  centerText(12, "Press any key to reboot...")

  event.pull("key_down")
  computer.shutdown(true)
else
  setColor(0xFFFF00)
  centerText(3, "Installation completed with errors.")
  centerText(5, string.format("Success: %d  |  Failed: %d", success, failed))

  setColor(0xFF5555)
  local ey = 7
  for _, e in ipairs(errors) do
    if ey < H - 2 then
      gpu.set(3, ey, "  " .. e)
      ey = ey + 1
    end
  end

  setColor(0xAAAAAA)
  centerText(H - 1, "Press any key to continue...")
  event.pull("key_down")
end
