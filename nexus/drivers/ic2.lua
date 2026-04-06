-- ============================================================================
-- NEXUS-OS  /drivers/ic2.lua
-- IndustrialCraft 2: reactor, energy storage monitoring
-- ============================================================================

local adapter = require("adapter")

local M = {}

local devices = {}  -- ctype → proxy
local available = false

-- IC2 component types exposed through adapters
local IC2_TYPES = {
  "ic2_reactor",
  "ic2_te_mfsu",
  "ic2_te_mfe",
  "ic2_te_cesu",
  "ic2_te_batbox",
  "ic2_te_mass_fab",
}

local function findDevices()
  devices = {}
  for _, ctype in ipairs(IC2_TYPES) do
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

--- Get a specific IC2 device proxy.
function M.getDevice(ctype)
  if next(devices) == nil then findDevices() end
  return devices[ctype]
end

-- ── Reactor ──────────────────────────────────────────────────────────────

function M.hasReactor()
  return M.getDevice("ic2_reactor") ~= nil
end

function M.getReactorHeat()
  local r = M.getDevice("ic2_reactor")
  if not r then return 0 end
  return adapter.call(r, "getHeat") or 0
end

function M.getReactorMaxHeat()
  local r = M.getDevice("ic2_reactor")
  if not r then return 0 end
  return adapter.call(r, "getMaxHeat") or 0
end

function M.getReactorHeatPercent()
  local max = M.getReactorMaxHeat()
  if max <= 0 then return 0 end
  return M.getReactorHeat() / max * 100
end

function M.getReactorEUOutput()
  local r = M.getDevice("ic2_reactor")
  if not r then return 0 end
  return adapter.call(r, "getReactorEUOutput") or 0
end

function M.getReactorActive()
  local r = M.getDevice("ic2_reactor")
  if not r then return false end
  return adapter.call(r, "producesEnergy") or false
end

function M.getReactorInfo()
  return {
    heat    = M.getReactorHeat(),
    maxHeat = M.getReactorMaxHeat(),
    heatPct = M.getReactorHeatPercent(),
    euOut   = M.getReactorEUOutput(),
    active  = M.getReactorActive(),
  }
end

-- ── Energy Storage (MFSU/MFE/CESU/BatBox) ──────────────────────────────

--- Get all energy storage devices.
function M.getStorageDevices()
  if next(devices) == nil then findDevices() end
  local result = {}
  local storageTypes = { "ic2_te_mfsu", "ic2_te_mfe", "ic2_te_cesu", "ic2_te_batbox" }
  for _, ctype in ipairs(storageTypes) do
    local p = devices[ctype]
    if p then
      result[#result + 1] = {
        type     = ctype,
        stored   = adapter.call(p, "getStored") or adapter.call(p, "getEnergy") or 0,
        capacity = adapter.call(p, "getCapacity") or adapter.call(p, "getMaxEnergy") or 0,
      }
    end
  end
  return result
end

--- Get total EU stored across all storage devices.
function M.getTotalStored()
  local devs = M.getStorageDevices()
  local total = 0
  for _, d in ipairs(devs) do total = total + d.stored end
  return total
end

--- Get total EU capacity.
function M.getTotalCapacity()
  local devs = M.getStorageDevices()
  local total = 0
  for _, d in ipairs(devs) do total = total + d.capacity end
  return total
end

-- ── Mass Fabricator ─────────────────────────────────────────────────────

function M.hasMassFab()
  return M.getDevice("ic2_te_mass_fab") ~= nil
end

function M.getMassFabProgress()
  local mf = M.getDevice("ic2_te_mass_fab")
  if not mf then return 0 end
  return adapter.call(mf, "getProgress") or 0
end

function M.rescan()
  devices = {}
  available = false
  findDevices()
  return available
end

return M
