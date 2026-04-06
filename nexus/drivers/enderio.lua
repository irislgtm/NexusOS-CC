-- ============================================================================
-- NEXUS-OS  /drivers/enderio.lua
-- Ender IO: capacitor banks, conduit monitors
-- ============================================================================

local adapter = require("adapter")

local M = {}

local devices = {}
local available = false

local EIO_TYPES = {
  "capacitor_bank",
  "eio_capacitor_bank",
}

local function findDevices()
  devices = {}
  for _, ctype in ipairs(EIO_TYPES) do
    local p = adapter.find(ctype)
    if p then
      devices[ctype] = p
      available = true
    end
  end
end

function M.isAvailable()
  if not available and next(devices) == nil then findDevices() end
  return available
end

function M.getDevice(ctype)
  if next(devices) == nil then findDevices() end
  return devices[ctype]
end

--- Get first available capacitor bank.
local function getCapBank()
  for _, ctype in ipairs(EIO_TYPES) do
    if devices[ctype] then return devices[ctype] end
  end
  return nil
end

-- ── Capacitor Bank ──────────────────────────────────────────────────────

function M.hasCapacitorBank()
  if next(devices) == nil then findDevices() end
  return getCapBank() ~= nil
end

function M.getEnergyStored()
  local p = getCapBank()
  if not p then return 0 end
  return adapter.call(p, "getEnergyStored") or 0
end

function M.getMaxEnergyStored()
  local p = getCapBank()
  if not p then return 0 end
  return adapter.call(p, "getMaxEnergyStored") or 0
end

function M.getEnergyPercent()
  local max = M.getMaxEnergyStored()
  if max <= 0 then return 0 end
  return M.getEnergyStored() / max * 100
end

function M.getAverageInput()
  local p = getCapBank()
  if not p then return 0 end
  return adapter.call(p, "getAverageInputPerTick") or 0
end

function M.getAverageOutput()
  local p = getCapBank()
  if not p then return 0 end
  return adapter.call(p, "getAverageOutputPerTick") or 0
end

function M.getCapBankInfo()
  return {
    stored  = M.getEnergyStored(),
    max     = M.getMaxEnergyStored(),
    percent = M.getEnergyPercent(),
    input   = M.getAverageInput(),
    output  = M.getAverageOutput(),
  }
end

function M.rescan()
  devices = {}
  available = false
  findDevices()
  return available
end

return M
