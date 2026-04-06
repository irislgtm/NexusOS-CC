-- ============================================================================
-- NEXUS-OS  /drivers/ae2.lua
-- Applied Energistics 2: ME Controller / Interface monitoring
-- ============================================================================

local adapter = require("adapter")

local M = {}

local proxy
local available = false
local cache      = {}
local cacheTime  = 0
local POLL_INTERVAL = 2  -- seconds between refreshes

local function findAE2()
  proxy = adapter.find("me_controller") or adapter.find("me_interface")
  available = proxy ~= nil
end

function M.isAvailable()
  if proxy == nil then findAE2() end
  return available
end

function M.get()
  if proxy == nil then findAE2() end
  return proxy
end

local function refreshCache()
  local now = computer and computer.uptime() or 0
  if (now - cacheTime) < POLL_INTERVAL then return end
  cacheTime = now

  local p = M.get()
  if not p then cache = {}; return end

  cache.energyStored    = adapter.call(p, "getAvgPowerInjection") or 0
  cache.energyCapacity  = adapter.call(p, "getIdlePowerUsage") or 0
  cache.avgPowerUsage   = adapter.call(p, "getAvgPowerUsage") or 0
  cache.storedPower     = adapter.call(p, "getStoredPower") or 0
  cache.maxStoredPower  = adapter.call(p, "getMaxStoredPower") or 0
end

--- Get all items in the ME network.
-- @return Array of {name, label, size, isCraftable, ...}
function M.getItems()
  local p = M.get()
  if not p then return {} end
  local ok, items = pcall(p.getItemsInNetwork or p.getAvailableItems or function() return {} end)
  if ok and items then return items end
  return {}
end

--- Get craftable items.
function M.getCraftables()
  local p = M.get()
  if not p then return {} end
  local ok, items = pcall(p.getCraftables or function() return {} end)
  if ok and items then return items end
  return {}
end

--- Get stored energy in the ME network.
function M.getStoredPower()
  refreshCache()
  return cache.storedPower or 0
end

--- Get max energy capacity.
function M.getMaxStoredPower()
  refreshCache()
  return cache.maxStoredPower or 0
end

--- Get average power usage (AE/t).
function M.getAvgPowerUsage()
  refreshCache()
  return cache.avgPowerUsage or 0
end

--- Get energy as percentage.
function M.getEnergyPercent()
  local max = M.getMaxStoredPower()
  if max <= 0 then return 0 end
  return M.getStoredPower() / max * 100
end

--- Request crafting of an item.
-- @param filter  {name=, damage=} table to identify the item
-- @param amount  Number to craft
-- @return crafting status object or nil
function M.requestCraft(filter, amount)
  local p = M.get()
  if not p then return nil, "No AE2" end

  local craftables = M.getCraftables()
  for _, c in ipairs(craftables) do
    local item = c.getItemStack and c.getItemStack() or c
    if item and item.name == filter.name then
      if c.request then
        return c.request(amount)
      end
    end
  end
  return nil, "Item not craftable"
end

--- Get CPU status (crafting CPUs).
function M.getCpus()
  local p = M.get()
  if not p or not p.getCpus then return {} end
  local ok, cpus = pcall(p.getCpus)
  if ok and cpus then return cpus end
  return {}
end

--- Search items by name pattern.
function M.searchItems(pattern)
  local items = M.getItems()
  local results = {}
  pattern = pattern:lower()
  for _, item in ipairs(items) do
    local name = (item.label or item.name or ""):lower()
    if name:find(pattern, 1, true) then
      results[#results + 1] = item
    end
  end
  return results
end

--- Get storage usage summary.
function M.getStorageSummary()
  local items = M.getItems()
  local totalTypes = #items
  local totalCount = 0
  for _, item in ipairs(items) do
    totalCount = totalCount + (item.size or 0)
  end
  return {
    types = totalTypes,
    totalItems = totalCount,
    energy = M.getStoredPower(),
    maxEnergy = M.getMaxStoredPower(),
    avgPower = M.getAvgPowerUsage(),
  }
end

function M.rescan()
  proxy = nil
  cache = {}
  cacheTime = 0
  findAE2()
  return available
end

return M
