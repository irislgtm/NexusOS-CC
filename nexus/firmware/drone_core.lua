-- ============================================================================
-- NEXUS-OS  /firmware/drone_core.lua
-- Drone Core Runtime: command dispatch, telemetry, heartbeat
-- Sent OTA by base station, executed by drone_boot.lua
-- ============================================================================

local M = {}

-- Injected by boot loader
local modem, baseAddr

-- State
local drone
local nav
local mode = "idle"        -- idle, tail, patrol, orbit, recon, halt
local modeModule = nil
local running = true
local config = {
  heartbeatInterval = 2,
  telemetryInterval = 3,
  maxAltitude = 128,
}

-- Find drone component
local function findDrone()
  for addr, ctype in component.list("drone") do
    return component.proxy(addr)
  end
end

-- Find navigation (optional)
local function findNav()
  for addr, ctype in component.list("navigation") do
    return component.proxy(addr)
  end
end

-- Telemetry data
local function getTelemetry()
  local data = {
    addr = computer.address(),
    mode = mode,
    uptime = computer.uptime(),
    energy = computer.energy(),
    maxEnergy = computer.maxEnergy(),
    energyPct = math.floor((computer.energy() / computer.maxEnergy()) * 100),
  }

  if drone then
    local sx, sy, sz = drone.getStatusText and drone.getStatusText() or ""
    data.status = sx
    local ox, oy, oz = drone.getOffset()
    data.offset = {x = ox, y = oy, z = oz}
    local vx, vy, vz = drone.getVelocity()
    data.velocity = {x = vx, y = vy, z = vz}
    data.name = drone.name and drone.name() or "Drone"
  end

  if nav then
    local ok, x, y, z = pcall(nav.getPosition)
    if ok and x then
      data.position = {x = x, y = y, z = z}
    end
    local ok2, facing = pcall(nav.getFacing)
    if ok2 then
      data.facing = facing
    end
  end

  return data
end

-- Send message to base
local function sendBase(msgType, payload)
  local data = ""
  if type(payload) == "table" then
    -- Simple serialize for tables
    local parts = {}
    for k, v in pairs(payload) do
      if type(v) == "table" then
        local sub = {}
        for sk, sv in pairs(v) do
          sub[#sub + 1] = tostring(sk) .. "=" .. tostring(sv)
        end
        parts[#parts + 1] = tostring(k) .. "={" .. table.concat(sub, ",") .. "}"
      else
        parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
      end
    end
    data = table.concat(parts, ";")
  elseif payload then
    data = tostring(payload)
  end
  modem.send(baseAddr, 9200, msgType, computer.address(), data)
end

-- Move drone toward a position (relative offsets)
function M.moveTo(dx, dy, dz)
  if not drone then return false end
  drone.move(dx, dy, dz)
  return true
end

-- Set status text on drone
function M.setStatus(text)
  if drone and drone.setStatusText then
    drone.setStatusText(tostring(text))
  end
end

-- Get current mode
function M.getMode() return mode end
function M.getDrone() return drone end
function M.getNav() return nav end
function M.getConfig() return config end
function M.getModem() return modem end
function M.getBaseAddr() return baseAddr end
function M.sendBase(t, p) return sendBase(t, p) end

-- Switch mode
function M.setMode(newMode, params)
  -- Unload current mode module
  if modeModule and modeModule.stop then
    pcall(modeModule.stop)
  end
  modeModule = nil
  mode = newMode
  M.setStatus("Mode: " .. mode)
  sendBase("NX_DRONE_MODE", {mode = mode})

  -- Load mode module
  if newMode == "tail" then
    modeModule = M.modes.tail
  elseif newMode == "patrol" then
    modeModule = M.modes.patrol
  elseif newMode == "orbit" then
    modeModule = M.modes.orbit
  elseif newMode == "recon" then
    modeModule = M.modes.recon
  elseif newMode == "halt" then
    if drone then drone.move(0, 0, 0) end
  elseif newMode == "home" then
    M.moveTo(0, -10, 0) -- descend
    mode = "idle"
  end

  if modeModule and modeModule.start then
    modeModule.start(M, params or {})
  end
end

-- Mode modules (loaded inline since this is OTA code)
M.modes = {}

-- Command handler
local function handleCommand(cmd, args)
  if cmd == "tail" then
    M.setMode("tail", {target = args})
  elseif cmd == "patrol" then
    M.setMode("patrol", {waypoints = args})
  elseif cmd == "orbit" then
    M.setMode("orbit", {params = args})
  elseif cmd == "recon" then
    M.setMode("recon", {target = args})
  elseif cmd == "home" then
    M.setMode("home")
  elseif cmd == "halt" then
    M.setMode("halt")
  elseif cmd == "ping" then
    sendBase("NX_DRONE_PONG", getTelemetry())
  elseif cmd == "status" then
    sendBase("NX_DRONE_TELEMETRY", getTelemetry())
  elseif cmd == "shutdown" then
    running = false
    sendBase("NX_DRONE_SHUTDOWN", {addr = computer.address()})
    computer.shutdown()
  elseif cmd == "reboot" then
    running = false
    sendBase("NX_DRONE_REBOOT", {addr = computer.address()})
    computer.shutdown(true)
  elseif cmd == "load_mode" then
    -- args = {name=..., code=...}
    local name = args.name
    local code = args.code
    if name and code then
      local fn, err = load(code, "=mode_" .. name)
      if fn then
        M.modes[name] = fn(M)
        sendBase("NX_DRONE_ACK", "mode_loaded:" .. name)
      else
        sendBase("NX_DRONE_ERR", "load_fail:" .. tostring(err))
      end
    end
  end
end

-- Main runtime entry point
return function(injectedModem, injectedBase)
  modem = injectedModem
  baseAddr = injectedBase

  drone = findDrone()
  nav = findNav()

  if not drone then
    modem.send(baseAddr, 9200, "NX_DRONE_ERR", computer.address(), "no_drone_component")
    return
  end

  M.setStatus("NEXUS Online")
  sendBase("NX_DRONE_ONLINE", getTelemetry())

  local lastHeartbeat = 0
  local lastTelemetry = 0

  while running do
    local now = computer.uptime()

    -- Heartbeat
    if now - lastHeartbeat >= config.heartbeatInterval then
      sendBase("NX_DRONE_HEARTBEAT", {
        addr = computer.address(),
        mode = mode,
        energy = math.floor((computer.energy() / computer.maxEnergy()) * 100),
      })
      lastHeartbeat = now
    end

    -- Telemetry
    if now - lastTelemetry >= config.telemetryInterval then
      sendBase("NX_DRONE_TELEMETRY", getTelemetry())
      lastTelemetry = now
    end

    -- Tick mode module
    if modeModule and modeModule.tick then
      pcall(modeModule.tick, now)
    end

    -- Low energy check
    local ePct = computer.energy() / computer.maxEnergy()
    if ePct < 0.1 then
      M.setMode("home")
      sendBase("NX_DRONE_ALERT", "low_energy:" .. math.floor(ePct * 100))
    end

    -- Pull signal
    local sig = {computer.pullSignal(0.5)}
    if sig[1] == "modem_message" then
      local _, _, from, port, _, msgType, droneAddr, payload = table.unpack(sig)
      if port == 9200 and (droneAddr == computer.address() or droneAddr == "*") then
        if msgType == "NX_DRONE_CMD" then
          -- payload = "command:args"
          local cmd, args = tostring(payload):match("^(%w+):?(.*)")
          if cmd then
            handleCommand(cmd, args ~= "" and args or nil)
          end
        elseif msgType == "NX_DRONE_CODE" then
          -- Hot-reload runtime
          local fn, err = load(payload, "=drone_update")
          if fn then
            sendBase("NX_DRONE_ACK", "code_updated")
            running = false
            fn(modem, baseAddr)
            return
          else
            sendBase("NX_DRONE_ERR", "update_fail:" .. tostring(err))
          end
        end
      end
    end
  end
end
