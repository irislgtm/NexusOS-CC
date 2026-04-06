-- ============================================================================
-- NEXUS-OS  /drivers/draconic.lua
-- Draconic Evolution: energy core + reactor monitoring
-- ============================================================================

local adapter = require("adapter")

local M = {}

local energyCore, dracoReactor
local coreAvail, reactorAvail = false, false

local function findDevices()
  energyCore = adapter.find("draconic_rf_storage")
  coreAvail = energyCore ~= nil
  dracoReactor = adapter.find("draconic_reactor")
  reactorAvail = dracoReactor ~= nil
end

function M.isAvailable()
  if energyCore == nil and dracoReactor == nil then findDevices() end
  return coreAvail or reactorAvail
end

function M.hasEnergyCore()
  if energyCore == nil then findDevices() end
  return coreAvail
end

function M.hasReactor()
  if dracoReactor == nil then findDevices() end
  return reactorAvail
end

-- ── Energy Core ──────────────────────────────────────────────────────────

function M.getEnergyStored()
  if not coreAvail then return 0 end
  return adapter.call(energyCore, "getEnergyStored") or 0
end

function M.getMaxEnergyStored()
  if not coreAvail then return 0 end
  return adapter.call(energyCore, "getMaxEnergyStored") or 0
end

function M.getEnergyPercent()
  local max = M.getMaxEnergyStored()
  if max <= 0 then return 0 end
  return M.getEnergyStored() / max * 100
end

function M.getTransferPerTick()
  if not coreAvail then return 0 end
  return adapter.call(energyCore, "getTransferPerTick") or 0
end

function M.getEnergyInfo()
  return {
    stored   = M.getEnergyStored(),
    max      = M.getMaxEnergyStored(),
    percent  = M.getEnergyPercent(),
    transfer = M.getTransferPerTick(),
  }
end

-- ── Draconic Reactor ─────────────────────────────────────────────────────

function M.getReactorInfo()
  if not reactorAvail then return nil end
  local info = adapter.call(dracoReactor, "getReactorInfo")
  if type(info) ~= "table" then
    -- Fallback: build info from individual calls
    return {
      status        = adapter.call(dracoReactor, "getStatus") or "unknown",
      temperature   = adapter.call(dracoReactor, "getTemperature") or 0,
      fieldStrength = adapter.call(dracoReactor, "getFieldStrength") or 0,
      maxFieldStrength = adapter.call(dracoReactor, "getMaxFieldStrength") or 0,
      saturation    = adapter.call(dracoReactor, "getSaturation") or 0,
      maxSaturation = adapter.call(dracoReactor, "getMaxSaturation") or 0,
      fuelConversion = adapter.call(dracoReactor, "getFuelConversion") or 0,
      maxFuelConversion = adapter.call(dracoReactor, "getMaxFuelConversion") or 0,
      generationRate = adapter.call(dracoReactor, "getGenerationRate") or 0,
    }
  end
  return info
end

function M.chargeReactor()
  if not reactorAvail then return false end
  return adapter.call(dracoReactor, "chargeReactor")
end

function M.activateReactor()
  if not reactorAvail then return false end
  return adapter.call(dracoReactor, "activateReactor")
end

function M.stopReactor()
  if not reactorAvail then return false end
  return adapter.call(dracoReactor, "stopReactor")
end

function M.rescan()
  energyCore = nil; dracoReactor = nil
  findDevices()
  return M.isAvailable()
end

return M
