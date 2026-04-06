-- ============================================================================
-- NEXUS-OS  /lib/drone_server.lua
-- Base Station Drone Server: handles OTA code deployment & command relay
-- Run by the drones.app or as a background service
-- ============================================================================

local M = {}

local fs = _G._fs
local modem = require("modem")
local net = require("net")
local ipc = require("ipc")
local logger = require("logger")

local log = logger.new("/var/log/drone_server.log")
local fleet = {}   -- addr -> {name, mode, lastSeen, energy, position, status}
local PORT = 9200
local running = false

-- Load firmware file as string
local function loadFirmware(path)
  local data = fs.read(path)
  if not data then
    log:error("Failed to load firmware: " .. path)
    return nil
  end
  return data
end

-- Get or create drone entry
local function getDrone(addr)
  if not fleet[addr] then
    fleet[addr] = {
      addr = addr,
      name = "Drone-" .. addr:sub(1, 4),
      mode = "unknown",
      lastSeen = 0,
      energy = 0,
      position = nil,
      status = "",
      online = false,
    }
  end
  return fleet[addr]
end

-- Send command to a drone
function M.sendCommand(addr, cmd, args)
  local payload = cmd
  if args then payload = cmd .. ":" .. tostring(args) end
  modem.send(addr, PORT, "NX_DRONE_CMD", addr, payload)
  log:info("CMD -> " .. addr:sub(1, 8) .. ": " .. payload)
end

-- Send command to all drones
function M.broadcastCommand(cmd, args)
  local payload = cmd
  if args then payload = cmd .. ":" .. tostring(args) end
  modem.broadcast(PORT, "NX_DRONE_CMD", "*", payload)
  log:info("CMD -> ALL: " .. payload)
end

-- Deploy OTA runtime to a drone
function M.deployRuntime(addr)
  local code = loadFirmware("/firmware/drone_core.lua")
  if not code then return false, "Failed to load drone_core.lua" end
  modem.send(addr, PORT, "NX_DRONE_CODE", addr, code)
  log:info("OTA deploy -> " .. addr:sub(1, 8))
  return true
end

-- Deploy a mode module to a drone
function M.deployMode(addr, modeName)
  local path = "/firmware/drone_" .. modeName .. ".lua"
  local code = loadFirmware(path)
  if not code then return false, "Failed to load " .. path end
  modem.send(addr, PORT, "NX_DRONE_CMD", addr, "load_mode")
  -- Send mode code separately
  modem.send(addr, PORT, "NX_DRONE_CODE_MODE", addr, modeName, code)
  log:info("Mode deploy -> " .. addr:sub(1, 8) .. ": " .. modeName)
  return true
end

-- Get fleet status
function M.getFleet()
  return fleet
end

-- Get online drones
function M.getOnlineDrones()
  local now = computer.uptime()
  local online = {}
  for addr, info in pairs(fleet) do
    if now - info.lastSeen < 15 then
      info.online = true
      online[#online + 1] = info
    else
      info.online = false
    end
  end
  return online
end

-- Parse simple key=value format from drone messages
local function parsePayload(str)
  if type(str) ~= "string" then return {} end
  local data = {}
  for kv in str:gmatch("[^;]+") do
    local k, v = kv:match("^(.-)=(.+)$")
    if k then
      -- Try to parse numbers
      local n = tonumber(v)
      data[k] = n or v
    end
  end
  return data
end

-- Handle incoming drone messages
local function onDroneMessage(_, _, from, port, _, msgType, droneAddr, payload)
  if port ~= PORT then return end

  local now = computer.uptime()

  if msgType == "NX_DRONE_BOOT" then
    -- Drone requesting OTA code
    log:info("Boot request from " .. tostring(droneAddr))
    local d = getDrone(tostring(droneAddr))
    d.lastSeen = now
    d.mode = "booting"
    d.online = true
    -- Deploy runtime
    M.deployRuntime(tostring(droneAddr))
    ipc.publish("drone_boot", {addr = tostring(droneAddr)})

  elseif msgType == "NX_DRONE_ONLINE" then
    local d = getDrone(tostring(droneAddr))
    d.lastSeen = now
    d.mode = "idle"
    d.online = true
    local data = parsePayload(payload)
    if data.energy then d.energy = tonumber(data.energy) or 0 end
    log:info("Drone online: " .. tostring(droneAddr))
    ipc.publish("drone_online", {addr = tostring(droneAddr)})

  elseif msgType == "NX_DRONE_HEARTBEAT" then
    local d = getDrone(tostring(droneAddr))
    d.lastSeen = now
    d.online = true
    local data = parsePayload(payload)
    if data.mode then d.mode = data.mode end
    if data.energy then d.energy = tonumber(data.energy) or 0 end

  elseif msgType == "NX_DRONE_TELEMETRY" then
    local d = getDrone(tostring(droneAddr))
    d.lastSeen = now
    d.online = true
    local data = parsePayload(payload)
    if data.mode then d.mode = data.mode end
    if data.energy then d.energy = tonumber(data.energy) or 0 end
    if data.energyPct then d.energy = tonumber(data.energyPct) or 0 end
    d.status = payload or ""
    ipc.publish("drone_telemetry", {addr = tostring(droneAddr), data = data})

  elseif msgType == "NX_DRONE_MODE" then
    local d = getDrone(tostring(droneAddr))
    d.lastSeen = now
    local data = parsePayload(payload)
    if data.mode then d.mode = data.mode end
    ipc.publish("drone_mode", {addr = tostring(droneAddr), mode = data.mode})

  elseif msgType == "NX_DRONE_ALERT" then
    local d = getDrone(tostring(droneAddr))
    d.lastSeen = now
    log:alert("DRONE ALERT [" .. tostring(droneAddr) .. "]: " .. tostring(payload))
    ipc.publish("drone_alert", {addr = tostring(droneAddr), alert = payload})

  elseif msgType == "NX_DRONE_ACK" then
    log:info("ACK from " .. tostring(droneAddr) .. ": " .. tostring(payload))

  elseif msgType == "NX_DRONE_ERR" then
    log:error("ERR from " .. tostring(droneAddr) .. ": " .. tostring(payload))
    ipc.publish("drone_error", {addr = tostring(droneAddr), error = payload})

  elseif msgType == "NX_DRONE_PONG" then
    local d = getDrone(tostring(droneAddr))
    d.lastSeen = now

  elseif msgType == "NX_DRONE_PATROL_ARRIVE"
      or msgType == "NX_DRONE_PATROL"
      or msgType == "NX_DRONE_ORBIT"
      or msgType == "NX_DRONE_RECON"
      or msgType == "NX_DRONE_RECON_DATA"
      or msgType == "NX_DRONE_TELEMETRY_TAIL" then
    local d = getDrone(tostring(droneAddr))
    d.lastSeen = now
    d.status = tostring(payload)
    ipc.publish("drone_message", {
      addr = tostring(droneAddr),
      type = msgType,
      data = parsePayload(payload),
    })
  end
end

-- Start the drone server
function M.start()
  if running then return end
  running = true

  if not modem.isOpen(PORT) then
    modem.open(PORT)
  end

  event.listen("modem_message", onDroneMessage)
  log:info("Drone server started on port " .. PORT)

  -- Periodic fleet cleanup
  event.timer(10, function()
    local now = computer.uptime()
    for addr, info in pairs(fleet) do
      if now - info.lastSeen > 60 then
        info.online = false
      end
    end
  end, math.huge)
end

-- Stop the drone server
function M.stop()
  if not running then return end
  running = false
  event.listen("modem_message", nil) -- would need unlisten
  log:info("Drone server stopped")
end

-- Add drone manually
function M.addDrone(addr, name)
  local d = getDrone(addr)
  if name then d.name = name end
  return d
end

-- Remove drone
function M.removeDrone(addr)
  fleet[addr] = nil
end

-- Rename drone
function M.renameDrone(addr, name)
  local d = fleet[addr]
  if d then d.name = name end
end

return M
