-- ============================================================================
-- NEXUS-OS  /lib/net.lua
-- Network protocol layer over modem
-- Packet framing, XOR encryption, ACK/retry, node discovery
-- ============================================================================

local modem  = require("modem")
local serial = require("serial")
local config = require("config")

local M = {}

-- Protocol constants
local PORT_DATA  = 9100
local PORT_ACK   = 9101
local PORT_DISC  = 9102  -- discovery
local PORT_DRONE = 9200  -- drone protocol

local MAGIC   = "NX"    -- packet header magic
local VERSION = 1
local MAX_RETRIES = 3
local ACK_TIMEOUT = 2   -- seconds

-- State
local nodeId     = nil
local encKey     = nil
local seqCounter = 0
local pendingAck = {}    -- seq → { time, retries, data, dst }
local knownNodes = {}    -- addr → { lastSeen, name, ... }

--- Initialize network.
function M.init()
  local cfg = config.load("/etc/network.cfg")
  nodeId = cfg.nodeId or (computer and computer.address():sub(1, 8) or "unknown")
  encKey = cfg.encKey or ""

  modem.open(PORT_DATA)
  modem.open(PORT_ACK)
  modem.open(PORT_DISC)
  modem.open(PORT_DRONE)

  -- Register modem_message handler
  if _G.event then
    _G.event.listen("modem_message", M._onMessage)
  end
end

--- Simple XOR cipher (not cryptographically secure, but obfuscates).
local function xorCrypt(data, key)
  if not key or #key == 0 then return data end
  local out = {}
  for i = 1, #data do
    local ki = ((i - 1) % #key) + 1
    out[i] = string.char(bit32 and
      bit32.bxor(data:byte(i), key:byte(ki)) or
      ((data:byte(i) ~ key:byte(ki)) & 0xFF))
  end
  return table.concat(out)
end

--- Build a packet.
local function buildPacket(ptype, dst, payload)
  seqCounter = seqCounter + 1
  local pkt = {
    m = MAGIC,
    v = VERSION,
    t = ptype,       -- "data", "ack", "disc", "drone"
    s = nodeId,       -- source
    d = dst or "*",   -- destination
    q = seqCounter,   -- sequence
    p = payload,      -- payload table
  }
  local raw = serial.serialize(pkt)
  if encKey and #encKey > 0 then
    raw = xorCrypt(raw, encKey)
  end
  return raw, seqCounter
end

--- Parse a received packet.
local function parsePacket(raw)
  if encKey and #encKey > 0 then
    raw = xorCrypt(raw, encKey)
  end
  local ok, pkt = pcall(serial.unserialize, raw)
  if not ok or type(pkt) ~= "table" then return nil end
  if pkt.m ~= MAGIC then return nil end
  return pkt
end

--- Send data to a specific node.
-- @param dst     Destination modem address
-- @param payload Table payload
-- @param reliable  If true, wait for ACK
-- @return seq number
function M.send(dst, payload, reliable)
  local raw, seq = buildPacket("data", dst, payload)
  modem.send(dst, PORT_DATA, raw)

  if reliable then
    pendingAck[seq] = {
      time = computer and computer.uptime() or 0,
      retries = 0,
      raw = raw,
      dst = dst,
    }
  end
  return seq
end

--- Broadcast data to all nodes.
function M.broadcast(payload)
  local raw = buildPacket("data", "*", payload)
  modem.broadcast(PORT_DATA, raw)
end

--- Send drone command.
function M.sendDrone(droneAddr, payload)
  local raw = buildPacket("drone", droneAddr, payload)
  modem.send(droneAddr, PORT_DRONE, raw)
end

--- Broadcast discovery ping.
function M.discover()
  local raw = buildPacket("disc", "*", {
    type = "ping",
    name = nodeId,
    time = computer and computer.uptime() or 0,
  })
  modem.broadcast(PORT_DISC, raw)
end

--- Handle incoming modem message.
function M._onMessage(_, localAddr, remoteAddr, port, distance, raw)
  if type(raw) ~= "string" then return end
  local pkt = parsePacket(raw)
  if not pkt then return end

  -- Track known nodes
  knownNodes[remoteAddr] = {
    lastSeen = computer and computer.uptime() or 0,
    name = pkt.s,
    distance = distance,
  }

  -- Route by type
  if pkt.t == "ack" then
    -- ACK received — remove from pending
    local seq = pkt.p and pkt.p.ackSeq
    if seq and pendingAck[seq] then
      pendingAck[seq] = nil
    end

  elseif pkt.t == "disc" then
    -- Discovery ping → reply with pong
    if pkt.p and pkt.p.type == "ping" then
      local reply = buildPacket("disc", pkt.s, {
        type = "pong",
        name = nodeId,
        time = computer and computer.uptime() or 0,
      })
      modem.send(remoteAddr, PORT_DISC, reply)
    end
    -- Push discovery event
    if _G.event then
      _G.event.push("net_discovery", remoteAddr, pkt.s, pkt.p)
    end

  elseif pkt.t == "data" then
    -- Send ACK if addressed to us
    if pkt.d == nodeId or pkt.d == "*" then
      local ackRaw = buildPacket("ack", pkt.s, { ackSeq = pkt.q })
      modem.send(remoteAddr, PORT_ACK, ackRaw)
    end
    -- Push data event
    if _G.event then
      _G.event.push("net_message", remoteAddr, pkt.s, pkt.p, distance)
    end

  elseif pkt.t == "drone" then
    if _G.event then
      _G.event.push("drone_message", remoteAddr, pkt.s, pkt.p, distance)
    end
  end
end

--- Retry timed-out reliable sends. Call periodically.
function M.tick()
  local now = computer and computer.uptime() or 0
  for seq, entry in pairs(pendingAck) do
    if (now - entry.time) > ACK_TIMEOUT then
      if entry.retries < MAX_RETRIES then
        entry.retries = entry.retries + 1
        entry.time = now
        modem.send(entry.dst, PORT_DATA, entry.raw)
      else
        pendingAck[seq] = nil
        if _G.event then
          _G.event.push("net_timeout", entry.dst, seq)
        end
      end
    end
  end
end

--- Get list of known network nodes.
function M.getNodes()
  local result = {}
  local now = computer and computer.uptime() or 0
  for addr, info in pairs(knownNodes) do
    if (now - info.lastSeen) < 120 then  -- 2 min staleness
      result[#result + 1] = {
        address  = addr,
        name     = info.name,
        distance = info.distance,
        lastSeen = info.lastSeen,
        age      = now - info.lastSeen,
      }
    end
  end
  table.sort(result, function(a, b) return a.lastSeen > b.lastSeen end)
  return result
end

--- Get node count.
function M.getNodeCount()
  return #M.getNodes()
end

--- Get protocol ports.
function M.getPorts()
  return {
    data  = PORT_DATA,
    ack   = PORT_ACK,
    disc  = PORT_DISC,
    drone = PORT_DRONE,
  }
end

return M
