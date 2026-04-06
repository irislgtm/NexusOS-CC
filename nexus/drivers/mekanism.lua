-- ============================================================================
-- NEXUS-OS  /drivers/mekanism.lua
-- Mekanism: gas tanks, energy cubes, digital miner, machines
-- ============================================================================

local adapter = require("adapter")

local M = {}

local devices = {}
local available = false

local MEK_TYPES = {
  "mekanism_machine",
  "digital_miner",
  "mek_energy_cube",
  "mek_gas_tank",
  "mek_induction_matrix",
}

local function findDevices()
  devices = {}
  for _, ctype in ipairs(MEK_TYPES) do
    local p = adapter.find(ctype)
    if p then
      devices[ctype] = p
      available = true
    end
  end
  -- Fallback: try runtime introspection for generic mekanism components
  if not available and _G.hw then
    local all = _G.hw.findAll and _G.hw.findAll("mekanism") or {}
    for _, addr in ipairs(all) do
      local p = _G.hw.proxies and _G.hw.proxies[addr]
      if p then
        devices["mekanism_generic"] = p
        available = true
        break
      end
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

-- ── Energy Cube ──────────────────────────────────────────────────────────

function M.hasEnergyCube()
  return M.getDevice("mek_energy_cube") ~= nil
end

function M.getEnergyStored()
  local p = M.getDevice("mek_energy_cube") or M.getDevice("mek_induction_matrix")
  if not p then return 0 end
  return adapter.call(p, "getEnergy") or adapter.call(p, "getStored") or 0
end

function M.getMaxEnergy()
  local p = M.getDevice("mek_energy_cube") or M.getDevice("mek_induction_matrix")
  if not p then return 0 end
  return adapter.call(p, "getMaxEnergy") or adapter.call(p, "getCapacity") or 0
end

function M.getEnergyPercent()
  local max = M.getMaxEnergy()
  if max <= 0 then return 0 end
  return M.getEnergyStored() / max * 100
end

-- ── Gas Tank ─────────────────────────────────────────────────────────────

function M.hasGasTank()
  return M.getDevice("mek_gas_tank") ~= nil
end

function M.getGasStored()
  local p = M.getDevice("mek_gas_tank")
  if not p then return 0, "none" end
  local amount = adapter.call(p, "getStored") or 0
  local gas = adapter.call(p, "getGas") or "unknown"
  return amount, gas
end

function M.getGasCapacity()
  local p = M.getDevice("mek_gas_tank")
  if not p then return 0 end
  return adapter.call(p, "getMaxGas") or adapter.call(p, "getCapacity") or 0
end

-- ── Digital Miner ────────────────────────────────────────────────────────

function M.hasDigitalMiner()
  return M.getDevice("digital_miner") ~= nil
end

function M.getDigitalMinerStatus()
  local p = M.getDevice("digital_miner")
  if not p then return nil end
  return {
    running  = adapter.call(p, "isRunning") or false,
    toMine   = adapter.call(p, "getToMine") or 0,
    energy   = adapter.call(p, "getEnergy") or 0,
    maxEnergy = adapter.call(p, "getMaxEnergy") or 0,
  }
end

function M.startDigitalMiner()
  local p = M.getDevice("digital_miner")
  if not p then return false end
  return adapter.call(p, "start")
end

function M.stopDigitalMiner()
  local p = M.getDevice("digital_miner")
  if not p then return false end
  return adapter.call(p, "stop")
end

-- ── Induction Matrix ─────────────────────────────────────────────────────

function M.hasInductionMatrix()
  return M.getDevice("mek_induction_matrix") ~= nil
end

function M.getInductionInfo()
  local p = M.getDevice("mek_induction_matrix")
  if not p then return nil end
  return {
    stored   = adapter.call(p, "getEnergy") or 0,
    capacity = adapter.call(p, "getMaxEnergy") or 0,
    input    = adapter.call(p, "getInput") or adapter.call(p, "getLastInput") or 0,
    output   = adapter.call(p, "getOutput") or adapter.call(p, "getLastOutput") or 0,
  }
end

function M.rescan()
  devices = {}
  available = false
  findDevices()
  return available
end

return M
