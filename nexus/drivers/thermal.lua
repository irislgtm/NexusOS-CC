-- ============================================================================
-- NEXUS-OS  /drivers/thermal.lua
-- Thermal Expansion: dynamos, machines, tanks
-- ============================================================================

local adapter = require("adapter")

local M = {}

local devices = {}
local available = false

local TE_TYPES = {
  "thermalexpansion_dynamo",
  "thermalexpansion_machine",
  "thermalexpansion_tank",
  "te_energy_cell",
}

local function findDevices()
  devices = {}
  for _, ctype in ipairs(TE_TYPES) do
    local proxies = adapter.findAll(ctype)
    if #proxies > 0 then
      devices[ctype] = {}
      for _, addr in ipairs(proxies) do
        local p = _G.hw and _G.hw.proxies and _G.hw.proxies[addr]
        if not p then
          p = component and component.proxy(addr)
        end
        if p then
          devices[ctype][#devices[ctype] + 1] = p
          available = true
        end
      end
    end
  end
end

function M.isAvailable()
  if not available and next(devices) == nil then findDevices() end
  return available
end

--- Get all devices of a type.
function M.getDevices(ctype)
  if next(devices) == nil then findDevices() end
  return devices[ctype] or {}
end

-- ── Energy Cell ──────────────────────────────────────────────────────────

function M.hasEnergyCell()
  return #M.getDevices("te_energy_cell") > 0
end

function M.getEnergyStored()
  local cells = M.getDevices("te_energy_cell")
  local total = 0
  for _, p in ipairs(cells) do
    total = total + (adapter.call(p, "getEnergyStored") or 0)
  end
  return total
end

function M.getMaxEnergyStored()
  local cells = M.getDevices("te_energy_cell")
  local total = 0
  for _, p in ipairs(cells) do
    total = total + (adapter.call(p, "getMaxEnergyStored") or 0)
  end
  return total
end

-- ── Dynamos ──────────────────────────────────────────────────────────────

function M.getDynamos()
  local dynamos = M.getDevices("thermalexpansion_dynamo")
  local result = {}
  for _, p in ipairs(dynamos) do
    result[#result + 1] = {
      energy    = adapter.call(p, "getEnergyStored") or 0,
      maxEnergy = adapter.call(p, "getMaxEnergyStored") or 0,
      active    = adapter.call(p, "isActive") or false,
    }
  end
  return result
end

-- ── Tanks ────────────────────────────────────────────────────────────────

function M.getTanks()
  local tanks = M.getDevices("thermalexpansion_tank")
  local result = {}
  for _, p in ipairs(tanks) do
    local info = adapter.call(p, "getFluidInTank") or adapter.call(p, "getTankInfo")
    if info then
      result[#result + 1] = info
    end
  end
  return result
end

function M.rescan()
  devices = {}
  available = false
  findDevices()
  return available
end

return M
