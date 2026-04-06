-- ============================================================================
-- NEXUS-OS  /lib/desktop.lua
-- Desktop: matrix rain background, app launcher, taskbar integration
-- ============================================================================

local Screen    = require("gui.screen")
local Workspace = require("gui.workspace")
local WM        = require("gui.window")
local Taskbar   = require("gui.taskbar")
local Button    = require("gui.button")
local Container = require("gui.container")
local T         = require("theme")
local Modal     = require("gui.modal")

local M = {}

local workspace
local taskbar
local launcher
local launcherOpen = false

-- ── Matrix Rain Background ──────────────────────────────────────────

local rainCols = {}
local RAIN_CHARS = "012345789ABCDEFabcdef@#$&*.:=<>{}|/"
local rainReady = false

local function initRain()
  local sw, sh = Screen.getSize()
  sh = sh - 1
  for x = 1, sw do
    rainCols[x] = {
      y    = math.random(-10, sh),
      spd  = math.random(1, 2),
      len  = math.random(4, 14),
      on   = math.random() > 0.65,
      cd   = math.random(5, 50),
    }
  end
  rainReady = true
end

local function tickRain()
  if not rainReady then return end
  local sw, sh = Screen.getSize()
  sh = sh - 1
  for x = 1, sw do
    local c = rainCols[x]
    if c.on then
      c.y = c.y + c.spd
      if c.y - c.len > sh then
        c.on = false
        c.cd = math.random(8, 50)
      end
    else
      c.cd = c.cd - 1
      if c.cd <= 0 then
        c.on = true
        c.y = math.random(-8, 0)
        c.len = math.random(4, 14)
        c.spd = math.random(1, 2)
      end
    end
  end
end

local function drawRain(wk, screen)
  if not rainReady then return end
  local sw, sh = screen.getSize()
  sh = sh - 1
  local bg = T.get("desktop_bg")

  for x = 1, sw do
    local c = rainCols[x]
    if c.on then
      local hy = c.y
      -- Head (brightest)
      if hy >= 1 and hy <= sh then
        local ci = math.random(1, #RAIN_CHARS)
        screen.drawChar(x, hy, RAIN_CHARS:sub(ci, ci), 0x00FF41, bg)
      end
      -- Trail with fading brightness
      for t = 1, math.min(c.len, 10) do
        local ty = hy - t
        if ty >= 1 and ty <= sh then
          local ci = math.random(1, #RAIN_CHARS)
          local shade
          if t <= 2 then shade = 0x00AA33
          elseif t <= 4 then shade = 0x006622
          elseif t <= 7 then shade = 0x003311
          else shade = 0x001A08 end
          screen.drawChar(x, ty, RAIN_CHARS:sub(ci, ci), shade, bg)
        end
      end
    end
  end
end

-- ── App Registry ────────────────────────────────────────────────────

local appRegistry = {}

function M.registerApp(id, name, icon, path, desc)
  appRegistry[#appRegistry + 1] = {
    id = id, name = name, icon = icon or "\xe2\x97\x86",
    path = path, description = desc or "",
  }
end

function M.getApps() return appRegistry end

function M.launchApp(id)
  for _, app in ipairs(appRegistry) do
    if app.id == id then
      local mainPath = app.path .. "/Main.lua"
      if _G._fs and _G._fs.exists(mainPath) then
        local source = _G._fs.read(mainPath)
        if not source then
          workspace:addChild(Modal.alert("Error", "Failed to read " .. app.name))
          return
        end
        local fn, err = load(source, "=" .. mainPath)
        if fn then
          local win = WM.open({
            title = app.name,
            x = 4 + math.random(0, 20),
            y = 3 + math.random(0, 8),
            w = 80, h = 30,
            closable = true, resizable = true,
          })
          if win then
            local ok, appErr = xpcall(fn, tostring, win, win.body, workspace)
            if not ok then
              workspace:addChild(Modal.alert("Error",
                app.name .. ": " .. tostring(appErr)))
            end
          end
        else
          workspace:addChild(Modal.alert("Error",
            "Load " .. app.name .. ": " .. tostring(err)))
        end
      else
        workspace:addChild(Modal.alert("Not Found", mainPath))
      end
      return
    end
  end
end

-- ── Launcher Panel ──────────────────────────────────────────────────

local function toggleLauncher()
  if launcherOpen and launcher then
    workspace:removeChild(launcher)
    launcher = nil
    launcherOpen = false
    workspace:requestRedraw()
    return
  end

  local sw, sh = Screen.getSize()
  local panelW = 30
  local panelH = math.min(#appRegistry * 2 + 4, sh - 4)
  launcher = Container.new(1, sh - panelH - 1, panelW, panelH)
  launcher.id = "launcher"

  -- Custom draw: panel background + border
  launcher.draw = function(self, screen)
    if not self.visible then return end
    local ax, ay = self:absolutePosition()
    screen.drawPanel(ax, ay, self.width, self.height,
      T.get("border_bright"), T.get("window_bg"), "single")
    screen.drawText(ax + 2, ay, " APPS ",
      T.get("accent"), T.get("window_bg"))
    for _, child in ipairs(self.children) do
      if child.visible then child:draw(screen) end
    end
  end

  for i, app in ipairs(appRegistry) do
    local btnY = 2 + (i - 1) * 2
    local btn = Button.new(2, btnY, panelW - 4, 1,
      app.icon .. " " .. app.name,
      function()
        toggleLauncher()
        M.launchApp(app.id)
      end)
    launcher:addChild(btn)
  end

  workspace:addChild(launcher)
  launcherOpen = true
  workspace:requestRedraw()
end

-- ── App Scanning ────────────────────────────────────────────────────

local function scanApps()
  appRegistry = {}
  local defaultApps = {
    { id="tracker",  name="Entity Tracker",  icon="\xe2\x97\x8e", path="/apps/tracker.app" },
    { id="mapper",   name="Geolyzer Map",    icon="\xe2\x96\xa6", path="/apps/mapper.app" },
    { id="sigint",   name="Signal Intel",    icon="~",             path="/apps/sigint.app" },
    { id="drones",   name="Drone Fleet",     icon="\xe2\x97\x86", path="/apps/drones.app" },
    { id="ae2mon",   name="AE2 Monitor",     icon="\xe2\x96\xa3", path="/apps/ae2mon.app" },
    { id="reactor",  name="Reactor Control", icon="*",             path="/apps/reactor.app" },
    { id="netmon",   name="Network Monitor", icon="#",              path="/apps/netmon.app" },
    { id="terminal", name="Terminal",        icon=">",              path="/apps/terminal.app" },
    { id="settings", name="Settings",        icon="+",              path="/apps/settings.app" },
    { id="storage",  name="Storage Manager", icon="=",              path="/apps/storage.app" },
  }
  for _, app in ipairs(defaultApps) do
    M.registerApp(app.id, app.name, app.icon, app.path, "")
  end
end

-- ── Desktop Start ───────────────────────────────────────────────────

function M.start()
  -- Initialize screen and theme
  Screen.init()
  T.init()

  -- Create workspace
  workspace = Workspace.new()

  -- Matrix rain background
  initRain()
  workspace.drawBackground = drawRain

  -- Taskbar at bottom
  taskbar = Taskbar.new()
  taskbar.onLogoClick = toggleLauncher
  workspace:addChild(taskbar)

  -- Wire up Window Manager
  WM.workspace = workspace
  WM.taskbar   = taskbar

  -- Scan and register apps
  scanApps()

  -- Keyboard driver
  local hasKb, kb = pcall(require, "keyboard")
  if hasKb and kb and kb.install then kb.install() end

  -- Rain animation timer (~4 FPS)
  _G.event.timer(0.25, function()
    tickRain()
    if workspace then workspace:requestRedraw() end
  end, math.huge)

  -- Force GC before entering the event loop to maximise available Lua heap
  collectgarbage("collect")
  collectgarbage("collect")

  -- Start workspace event loop (blocking)
  workspace:start()
end

function M.getWorkspace() return workspace end
function M.getTaskbar() return taskbar end

return M
