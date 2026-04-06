-- ============================================================================
-- NEXUS-OS  /drivers/modem.lua
-- Modem abstraction: open/close ports, send/broadcast, wireless strength
-- ============================================================================

local M = {}

local proxy     -- modem component proxy
local available = false
local openPorts = {}

local function findModem()
  if _G.hw then
    proxy = _G.hw.find("modem")
    available = proxy ~= nil
  end
end

--- Is a modem present?
function M.isAvailable()
  if proxy == nil then findModem() end
  return available
end

--- Get modem proxy (or nil).
function M.get()
  if proxy == nil then findModem() end
  return proxy
end

--- Get modem address.
function M.getAddress()
  local m = M.get()
  return m and m.address or nil
end

--- Is the modem wireless?
function M.isWireless()
  local m = M.get()
  return m and m.isWireless and m.isWireless() or false
end

--- Open a port.
function M.open(port)
  local m = M.get()
  if not m then return false end
  local ok = m.open(port)
  if ok then openPorts[port] = true end
  return ok
end

--- Close a port.
function M.close(port)
  local m = M.get()
  if not m then return false end
  local ok = m.close(port)
  if ok then openPorts[port] = nil end
  return ok
end

--- Close all ports.
function M.closeAll()
  local m = M.get()
  if not m then return false end
  for p in pairs(openPorts) do
    m.close(p)
  end
  openPorts = {}
  return true
end

--- Check if port is open.
function M.isOpen(port)
  local m = M.get()
  if not m then return false end
  return m.isOpen(port)
end

--- Send to specific address + port.
function M.send(addr, port, ...)
  local m = M.get()
  if not m then return false end
  return m.send(addr, port, ...)
end

--- Broadcast on port.
function M.broadcast(port, ...)
  local m = M.get()
  if not m then return false end
  return m.broadcast(port, ...)
end

--- Get wireless signal strength.
function M.getStrength()
  local m = M.get()
  if not m or not m.getStrength then return 0 end
  return m.getStrength()
end

--- Set wireless signal strength.
function M.setStrength(value)
  local m = M.get()
  if not m or not m.setStrength then return false end
  return m.setStrength(value)
end

--- Get max packet size.
function M.maxPacketSize()
  local m = M.get()
  if not m or not m.maxPacketSize then return 8192 end
  return m.maxPacketSize()
end

--- Rescan for modem hardware.
function M.rescan()
  proxy = nil
  openPorts = {}
  findModem()
  return available
end

return M
