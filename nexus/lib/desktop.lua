-- ============================================================================
-- NEXUS-OS  /lib/desktop.lua
-- Desktop environment: workspace setup, app launcher, taskbar integration
-- ============================================================================

local Screen    = require("gui.screen")
local Workspace = require("gui.workspace")
local Window    = require("gui.window")
local Taskbar   = require("gui.taskbar")
local Button    = require("gui.button")
local Container = require("gui.container")
local T         = require("theme")
local Modal     = require("gui.modal")

local M = {}

local workspace
local taskbar
local launcher    -- app launcher panel
local launcherOpen = false

-- App registry: { id, name, icon, path, description }
local appRegistry = {}

--- Register an app.
function M.registerApp(id, name, icon, path, description)
  appRegistry[#appRegistry + 1] = {
    id = id,
    name = name,
    icon = icon or "◆",
    path = path,
    description = description or "",
  }
end

--- Get registered apps.
function M.getApps()
  return appRegistry
end

--- Launch an app by id.
function M.launchApp(id)
  for _, app in ipairs(appRegistry) do
    if app.id == id then
      local mainPath = app.path .. "/Main.lua"
      if _G._fs and _G._fs.exists(mainPath) then
        local fn, err = loadfile(mainPath)
        if fn then
          local win = Window.WM.open({
            title  = app.name,
            x      = 4 + math.random(0, 20),
            y      = 3 + math.random(0, 8),
            width  = 80,
            height = 30,
            closable   = true,
            resizable  = true,
          })
          if win then
            -- Run app in its window body container
            local ok, appErr = xpcall(fn, debug.traceback, win, win.body, workspace)
            if not ok then
              local errWin = Modal.alert("Error", app.name .. ": " .. tostring(appErr))
              workspace:addChild(errWin)
            end
          end
        else
          local errDlg = Modal.alert("Error", "Failed to load " .. app.name .. ": " .. tostring(err))
          workspace:addChild(errDlg)
        end
      else
        local errDlg = Modal.alert("Not Found", "App file not found: " .. mainPath)
        workspace:addChild(errDlg)
      end
      return
    end
  end
end

--- Toggle app launcher panel.
local function toggleLauncher()
  if launcherOpen and launcher then
    workspace:removeChild(launcher)
    launcher = nil
    launcherOpen = false
    workspace:invalidate()
    return
  end

  -- Build launcher panel
  local gpu = _G.hw and _G.hw.find("gpu")
  local sw, sh = 160, 50
  if gpu then sw, sh = gpu.getResolution() end

  local panelW = 30
  local panelH = math.min(#appRegistry * 2 + 4, sh - 4)
  launcher = Container.new(1, sh - panelH - 1, panelW, panelH)
  launcher.id = "launcher"

  -- Title
  local titleY = 0

  -- App buttons
  for i, app in ipairs(appRegistry) do
    local btnY = titleY + 1 + (i - 1) * 2
    local btn = Button.new(1, btnY, panelW - 2, 1,
      app.icon .. " " .. app.name,
      function()
        toggleLauncher()  -- close
        M.launchApp(app.id)
      end)
    launcher:addChild(btn)
  end

  workspace:addChild(launcher)
  launcherOpen = true
  workspace:invalidate()
end

--- Build default app registry by scanning /apps/ directory.
local function scanApps()
  appRegistry = {}
  if not _G._fs then return end

  local defaultApps = {
    { id = "tracker",  name = "Entity Tracker",   icon = "◎", path = "/apps/tracker.app" },
    { id = "mapper",   name = "Geolyzer Map",     icon = "▦", path = "/apps/mapper.app" },
    { id = "sigint",   name = "Signal Intel",      icon = "⚡", path = "/apps/sigint.app" },
    { id = "drones",   name = "Drone Fleet",       icon = "◆", path = "/apps/drones.app" },
    { id = "ae2mon",   name = "AE2 Monitor",       icon = "▣", path = "/apps/ae2mon.app" },
    { id = "reactor",  name = "Reactor Control",   icon = "☢", path = "/apps/reactor.app" },
    { id = "netmon",   name = "Network Monitor",   icon = "⊞", path = "/apps/netmon.app" },
    { id = "terminal", name = "Terminal",           icon = ">", path = "/apps/terminal.app" },
    { id = "settings", name = "Settings",           icon = "⚙", path = "/apps/settings.app" },
  }

  for _, app in ipairs(defaultApps) do
    M.registerApp(app.id, app.name, app.icon, app.path, "")
  end
end

--- Initialize and start the desktop environment.
function M.start()
  -- Init subsystems
  Screen.init()
  T.init()

  local gpu = _G.hw and _G.hw.find("gpu")
  local sw, sh = 160, 50
  if gpu then sw, sh = gpu.getResolution() end

  -- Create workspace
  workspace = Workspace.new()

  -- Create taskbar (bottom, 1 row)
  taskbar = Taskbar.new(1, sh, sw)
  taskbar.onLogoClick = toggleLauncher
  workspace:addChild(taskbar)

  -- Scan and register apps
  scanApps()

  -- Install keyboard driver
  local hasKb, kb = pcall(require, "keyboard")
  if hasKb and kb.install then kb.install() end
  if hasKb and kb.bind then
    -- Ctrl+Q: close focused window
    kb.bind("ctrl+q", function()
      local focused = Window.WM.getFocused and Window.WM.getFocused()
      if focused then Window.WM.close(focused) end
    end)
    -- Ctrl+L: toggle launcher
    kb.bind("ctrl+l", toggleLauncher)
  end

  -- Install motion driver
  local hasMo, motion = pcall(require, "motion")
  if hasMo and motion.install then motion.install() end

  -- Initialize network
  local hasNet, net = pcall(require, "net")
  if hasNet and net.init then
    pcall(net.init)
  end

  -- Start workspace event loop (blocking)
  workspace:start()
end

--- Get workspace reference.
function M.getWorkspace()
  return workspace
end

--- Get taskbar reference.
function M.getTaskbar()
  return taskbar
end

return M
