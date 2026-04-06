-- ============================================================================
-- NEXUS-OS  /apps/drones.app/Main.lua
-- Drone Fleet Manager: deploy, command, telemetry
-- ============================================================================

return function(window, body, workspace)
  local ListView = require("gui.listview")
  local Button   = require("gui.button")
  local TabBar   = require("gui.tabbar")
  local Widget   = require("gui.widget")
  local Progress = require("gui.progress")
  local Radar    = require("gui.radar")
  local Modal    = require("gui.modal")
  local T        = require("theme")
  local config   = require("config")
  local net      = require("net")
  local ipc      = require("ipc")

  local bw, bh = body.width, body.height

  -- Drone registry from config
  local drones = config.loadWithDefaults("/etc/drones.cfg", { drones = {} }).drones
  -- Runtime state: addr → { lastTelemetry, battery, x, y, z, mode, target, status }
  local droneState = {}

  -- Tabs
  local tabs = TabBar.new(0, 0, bw, { "Fleet Status", "Command", "Map" })
  body:addChild(tabs)

  -- ── Fleet Status ──────────────────────────────────────────────────────
  local fleetList = ListView.new(0, 2, bw, bh - 6, {
    { name = "Name",    width = 14 },
    { name = "Address", width = 12 },
    { name = "Mode",    width = 10 },
    { name = "Battery", width = 8 },
    { name = "Status",  width = 10 },
    { name = "Position", width = 16 },
  })
  fleetList.rowColors = function(row, idx)
    -- Color by battery level
    if droneState[row[2]] then
      local bat = droneState[row[2]].battery or 100
      if bat < 20 then return T.get("alert_critical"), T.get("window_bg") end
      if bat < 50 then return T.get("alert_warn"), T.get("window_bg") end
    end
    return nil, nil
  end
  body:addChild(fleetList)

  -- ── Command Panel ─────────────────────────────────────────────────────
  local cmdPanel = Widget.new(0, 2, bw, bh - 4)
  cmdPanel.visible = false
  cmdPanel.draw = function(self, screen)
    if not self.visible then return end
    local ax, ay = self:absolutePosition()
    screen.drawText(ax, ay, "Select a drone from Fleet Status, then choose a command.",
      T.get("text_muted"), T.get("window_bg"))
  end
  body:addChild(cmdPanel)

  local selectedDrone = nil

  -- Command buttons
  local cmdY = 6
  local commands = {
    { label = " Tail Player ", mode = "tail" },
    { label = " Patrol Route", mode = "patrol" },
    { label = " Orbit Point ", mode = "orbit" },
    { label = " Recon Scan  ", mode = "recon" },
    { label = " Return Home ", mode = "home" },
    { label = " Halt / Hover", mode = "halt" },
  }

  for i, cmd in ipairs(commands) do
    local btn = Button.new(2, cmdY + (i - 1) * 2, 16, 1, cmd.label, function()
      if not selectedDrone then return end
      local addr = selectedDrone.address
      if cmd.mode == "tail" then
        -- Prompt for target player name
        local dlg = Modal.prompt("Tail Target", "Enter player name:", "Steve", function(name)
          if name and #name > 0 then
            net.sendDrone(addr, { cmd = "tail", target = name })
          end
        end)
        workspace:addChild(dlg)
      elseif cmd.mode == "patrol" then
        net.sendDrone(addr, { cmd = "patrol" })
      elseif cmd.mode == "orbit" then
        local dlg = Modal.prompt("Orbit", "Radius (blocks):", "10", function(r)
          r = tonumber(r) or 10
          net.sendDrone(addr, { cmd = "orbit", radius = r })
        end)
        workspace:addChild(dlg)
      elseif cmd.mode == "recon" then
        local dlg = Modal.prompt("Recon", "Coords (x,y,z):", "0,64,0", function(coords)
          if coords then
            local x, y, z = coords:match("([%-?%d]+),([%-?%d]+),([%-?%d]+)")
            x, y, z = tonumber(x), tonumber(y), tonumber(z)
            if x and y and z then
              net.sendDrone(addr, { cmd = "recon", x = x, y = y, z = z })
            end
          end
        end)
        workspace:addChild(dlg)
      else
        net.sendDrone(addr, { cmd = cmd.mode })
      end
    end)
    btn.visible = false
    btn._cmdMode = cmd.mode
    cmdPanel:addChild(btn)
  end

  -- ── Map View ──────────────────────────────────────────────────────────
  local droneRadar = Radar.new(0, 2, bw - 2, bh - 4, 100)
  droneRadar.visible = false
  body:addChild(droneRadar)

  -- Tab switching
  tabs.onTabChanged = function(idx)
    fleetList.visible   = (idx == 1)
    cmdPanel.visible    = (idx == 2)
    droneRadar.visible  = (idx == 3)
    for _, child in ipairs(cmdPanel.children) do
      child.visible = (idx == 2)
    end
    body:invalidate()
  end

  -- Fleet list selection → select drone for commands
  fleetList.onSelect = function(row, idx)
    if row then
      for _, d in ipairs(drones) do
        if d.name == row[1] then
          selectedDrone = d
          break
        end
      end
    end
  end

  -- ── Telemetry handler ─────────────────────────────────────────────────
  local function onDroneMessage(_, remoteAddr, srcNode, payload, distance)
    if type(payload) ~= "table" then return end
    if payload.type == "telemetry" then
      droneState[remoteAddr] = {
        battery = payload.battery or 0,
        x = payload.x or 0,
        y = payload.y or 0,
        z = payload.z or 0,
        mode = payload.mode or "idle",
        target = payload.target,
        status = payload.status or "ok",
        lastTelemetry = computer.uptime(),
      }
      refreshViews()
    end
  end

  function refreshViews()
    -- Update fleet list
    local rows = {}
    for _, d in ipairs(drones) do
      local state = droneState[d.address] or {}
      local pos = string.format("%.0f,%.0f,%.0f", state.x or 0, state.y or 0, state.z or 0)
      rows[#rows + 1] = {
        d.name or "?",
        (d.address or "?"):sub(1, 10) .. "..",
        state.mode or "offline",
        string.format("%.0f%%", state.battery or 0),
        state.status or "N/A",
        pos,
      }
    end
    fleetList:setData(rows)

    -- Update drone map
    local entities = {}
    for _, d in ipairs(drones) do
      local state = droneState[d.address] or {}
      if state.x then
        entities[#entities + 1] = {
          name = d.name,
          x = state.x,
          z = state.z,
          classification = "drone",
        }
      end
    end
    droneRadar:setEntities(entities)
    body:invalidate()
  end

  if _G.event then
    _G.event.listen("drone_message", onDroneMessage)
    -- Periodic stale check
    _G.event.timer(5, function()
      local now = computer.uptime()
      for addr, state in pairs(droneState) do
        if (now - (state.lastTelemetry or 0)) > 30 then
          state.status = "LOST"
        end
      end
      refreshViews()
    end, math.huge)
  end

  -- Register drone button
  local addBtn = Button.new(bw - 14, bh - 3, 12, 1, " + Add Drone", function()
    local dlg = Modal.prompt("Add Drone", "Drone modem address:", "", function(addr)
      if addr and #addr > 0 then
        local nameDlg = Modal.prompt("Drone Name", "Name for this drone:", "Drone-" .. #drones + 1, function(name)
          if name and #name > 0 then
            drones[#drones + 1] = { name = name, address = addr }
            config.save("/etc/drones.cfg", { drones = drones })
            refreshViews()
          end
        end)
        workspace:addChild(nameDlg)
      end
    end)
    workspace:addChild(dlg)
  end)
  body:addChild(addBtn)

  -- Header
  local header = Widget.new(0, 0, bw, 1)
  header.draw = function(self, screen)
    local ax, ay = self:absolutePosition()
    screen.drawText(ax, ay, "◆ DRONE FLEET MANAGER", T.get("accent"), T.get("window_bg"))
    screen.drawText(ax + 25, ay, "Registered: " .. #drones,
      T.get("text_secondary"), T.get("window_bg"))
    local online = 0
    for _, state in pairs(droneState) do
      if state.status ~= "LOST" then online = online + 1 end
    end
    screen.drawText(ax + 42, ay, "Online: " .. online,
      online > 0 and T.get("alert_ok") or T.get("text_muted"), T.get("window_bg"))
  end
  body:addChild(header)

  -- Initial refresh
  refreshViews()
end
