-- ============================================================================
-- NEXUS-OS  /drivers/bigreactors.lua
-- Big/Extreme Reactors: reactor and turbine control
-- ============================================================================

local adapter = require("adapter")

local M = {}

local reactor, turbine
local reactorAvail, turbineAvail = false, false

local function findDevices()
  reactor = adapter.find("br_reactor")
  reactorAvail = reactor ~= nil
  turbine = adapter.find("br_turbine")
  turbineAvail = turbine ~= nil
end

function M.isAvailable()
  if reactor == nil and turbine == nil then findDevices() end
  return reactorAvail or turbineAvail
end

function M.hasReactor()
  if reactor == nil then findDevices() end
  return reactorAvail
end

function M.hasTurbine()
  if turbine == nil then findDevices() end
  return turbineAvail
end

-- ── Reactor ──────────────────────────────────────────────────────────────

function M.getReactorActive()
  if not reactorAvail then return false end
  return adapter.call(reactor, "getActive") or false
end

function M.setReactorActive(state)
  if not reactorAvail then return false end
  return adapter.call(reactor, "setActive", state == true)
end

function M.getEnergyStored()
  if not reactorAvail then return 0 end
  return adapter.call(reactor, "getEnergyStored") or 0
end

function M.getEnergyProduced()
  if not reactorAvail then return 0 end
  return adapter.call(reactor, "getEnergyProducedLastTick") or 0
end

function M.getFuelTemperature()
  if not reactorAvail then return 0 end
  return adapter.call(reactor, "getFuelTemperature") or 0
end

function M.getCasingTemperature()
  if not reactorAvail then return 0 end
  return adapter.call(reactor, "getCasingTemperature") or 0
end

function M.getFuelAmount()
  if not reactorAvail then return 0 end
  return adapter.call(reactor, "getFuelAmount") or 0
end

function M.getFuelAmountMax()
  if not reactorAvail then return 0 end
  return adapter.call(reactor, "getFuelAmountMax") or 0
end

function M.getFuelPercent()
  local max = M.getFuelAmountMax()
  if max <= 0 then return 0 end
  return M.getFuelAmount() / max * 100
end

function M.getFuelConsumedLastTick()
  if not reactorAvail then return 0 end
  return adapter.call(reactor, "getFuelConsumedLastTick") or 0
end

function M.getWasteAmount()
  if not reactorAvail then return 0 end
  return adapter.call(reactor, "getWasteAmount") or 0
end

function M.getNumberOfControlRods()
  if not reactorAvail then return 0 end
  return adapter.call(reactor, "getNumberOfControlRods") or 0
end

function M.getControlRodLevel(index)
  if not reactorAvail then return 0 end
  return adapter.call(reactor, "getControlRodLevel", index) or 0
end

function M.setAllControlRodLevels(pct)
  if not reactorAvail then return false end
  pct = math.max(0, math.min(100, math.floor(pct or 0)))
  return adapter.call(reactor, "setAllControlRodLevels", pct)
end

function M.getReactorInfo()
  return {
    active      = M.getReactorActive(),
    energy      = M.getEnergyStored(),
    produced    = M.getEnergyProduced(),
    fuelTemp    = M.getFuelTemperature(),
    casingTemp  = M.getCasingTemperature(),
    fuel        = M.getFuelAmount(),
    fuelMax     = M.getFuelAmountMax(),
    fuelPct     = M.getFuelPercent(),
    consumed    = M.getFuelConsumedLastTick(),
    waste       = M.getWasteAmount(),
    rods        = M.getNumberOfControlRods(),
  }
end

-- ── Turbine ──────────────────────────────────────────────────────────────

function M.getTurbineActive()
  if not turbineAvail then return false end
  return adapter.call(turbine, "getActive") or false
end

function M.setTurbineActive(state)
  if not turbineAvail then return false end
  return adapter.call(turbine, "setActive", state == true)
end

function M.getRotorSpeed()
  if not turbineAvail then return 0 end
  return adapter.call(turbine, "getRotorSpeed") or 0
end

function M.getFluidFlowRate()
  if not turbineAvail then return 0 end
  return adapter.call(turbine, "getFluidFlowRate") or 0
end

function M.getFluidFlowRateMax()
  if not turbineAvail then return 0 end
  return adapter.call(turbine, "getFluidFlowRateMax") or 0
end

function M.getTurbineEnergyProduced()
  if not turbineAvail then return 0 end
  return adapter.call(turbine, "getEnergyProducedLastTick") or 0
end

function M.getTurbineEnergyStored()
  if not turbineAvail then return 0 end
  return adapter.call(turbine, "getEnergyStored") or 0
end

function M.setFluidFlowRateMax(rate)
  if not turbineAvail then return false end
  return adapter.call(turbine, "setFluidFlowRateMax", rate)
end

function M.getTurbineInfo()
  return {
    active   = M.getTurbineActive(),
    rpm      = M.getRotorSpeed(),
    flow     = M.getFluidFlowRate(),
    flowMax  = M.getFluidFlowRateMax(),
    energy   = M.getTurbineEnergyStored(),
    produced = M.getTurbineEnergyProduced(),
  }
end

function M.rescan()
  reactor = nil; turbine = nil
  findDevices()
  return M.isAvailable()
end

return M
