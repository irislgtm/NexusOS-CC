-- ============================================================================
-- NEXUS-OS  /drivers/storage.lua
-- Unified physical storage abstraction via Transposer(s)
-- Scans all connected inventories, builds a virtual item index,
-- and supports search, transfer, and real-time refresh.
-- ============================================================================

local component = component or require("computer") and component
local computer  = computer

local M = {}

-- ── Internal State ──────────────────────────────────────────────────

local transposers = {}       -- { proxy, address }[]
local inventories = {}       -- { transposer, side, name, size, slots={} }[]
local itemIndex   = {}       -- label → { {inv, slot, stack}, ... }
local totalTypes  = 0
local totalItems  = 0
local lastScan    = 0
local SCAN_COOLDOWN = 1.0    -- seconds between full rescans

-- Side names for display
local SIDE_NAMES = { [0]="Down", "Up", "North", "South", "West", "East" }

-- ── Transposer Discovery ───────────────────────────────────────────

local function findTransposers()
  transposers = {}
  if _G.hw and _G.hw.components and _G.hw.components.transposer then
    for _, addr in ipairs(_G.hw.components.transposer) do
      local proxy = _G.hw.proxies[addr]
      if proxy then
        transposers[#transposers + 1] = { proxy = proxy, address = addr }
      end
    end
  else
    for addr in component.list("transposer") do
      local proxy = component.proxy(addr)
      if proxy then
        transposers[#transposers + 1] = { proxy = proxy, address = addr }
      end
    end
  end
  return #transposers
end

-- ── Inventory Scanning ──────────────────────────────────────────────

--- Scan all sides of all transposers for connected inventories.
-- Builds a flat list of inventory descriptors.
local function scanInventories()
  inventories = {}
  for _, tp in ipairs(transposers) do
    for side = 0, 5 do
      local ok, size = pcall(tp.proxy.getInventorySize, side)
      if ok and size and size > 0 then
        local invName = ""
        pcall(function()
          invName = tp.proxy.getInventoryName(side) or ""
        end)
        inventories[#inventories + 1] = {
          transposer = tp,
          side       = side,
          sideName   = SIDE_NAMES[side] or tostring(side),
          name       = invName,
          size       = size,
          slots      = {},  -- populated by scanSlots
        }
      end
    end
  end
  return #inventories
end

--- Scan all slots in all inventories and build the item index.
local function scanSlots()
  itemIndex  = {}
  totalTypes = 0
  totalItems = 0

  for _, inv in ipairs(inventories) do
    inv.slots = {}
    -- Use getAllStacks if available (faster bulk read)
    local useIterator = false
    local iter
    pcall(function()
      iter = inv.transposer.proxy.getAllStacks(inv.side)
      if iter then useIterator = true end
    end)

    if useIterator and iter then
      local slot = 1
      while slot <= inv.size do
        local stack = iter()
        if stack == nil then break end
        if stack.name or stack.label then
          inv.slots[slot] = stack
          local label = stack.label or stack.name or "?"
          if not itemIndex[label] then
            itemIndex[label] = {}
            totalTypes = totalTypes + 1
          end
          itemIndex[label][#itemIndex[label] + 1] = {
            inv  = inv,
            slot = slot,
            stack = stack,
          }
          totalItems = totalItems + (stack.size or 1)
        end
        slot = slot + 1
      end
    else
      -- Fallback: per-slot reads
      for slot = 1, inv.size do
        local ok, stack = pcall(inv.transposer.proxy.getStackInSlot, inv.side, slot)
        if ok and stack and (stack.name or stack.label) then
          inv.slots[slot] = stack
          local label = stack.label or stack.name or "?"
          if not itemIndex[label] then
            itemIndex[label] = {}
            totalTypes = totalTypes + 1
          end
          itemIndex[label][#itemIndex[label] + 1] = {
            inv  = inv,
            slot = slot,
            stack = stack,
          }
          totalItems = totalItems + (stack.size or 1)
        end
      end
    end
  end

  lastScan = computer and computer.uptime() or 0
end

-- ── Public API ──────────────────────────────────────────────────────

--- Check if any transposers are available.
function M.isAvailable()
  if #transposers == 0 then findTransposers() end
  return #transposers > 0
end

--- Full rescan: discover transposers → inventories → slots.
function M.rescan()
  findTransposers()
  scanInventories()
  scanSlots()
  return {
    transposers  = #transposers,
    inventories  = #inventories,
    totalTypes   = totalTypes,
    totalItems   = totalItems,
  }
end

--- Refresh slot data only (no transposer/inventory rediscovery).
-- Returns quickly if called within SCAN_COOLDOWN.
function M.refresh()
  local now = computer and computer.uptime() or 0
  if (now - lastScan) < SCAN_COOLDOWN then
    return { totalTypes = totalTypes, totalItems = totalItems }
  end
  scanSlots()
  return { totalTypes = totalTypes, totalItems = totalItems }
end

--- Force refresh regardless of cooldown.
function M.forceRefresh()
  lastScan = 0
  return M.refresh()
end

--- Get summary stats.
function M.getSummary()
  return {
    transposers = #transposers,
    inventories = #inventories,
    totalTypes  = totalTypes,
    totalItems  = totalItems,
    lastScan    = lastScan,
  }
end

--- Get all inventories.
function M.getInventories()
  return inventories
end

--- Get all unique item types as a sorted list.
-- @return { {label, totalCount, maxSize, locations={...}} }
function M.getItems()
  local result = {}
  for label, locs in pairs(itemIndex) do
    local total = 0
    local maxSz = 64
    for _, loc in ipairs(locs) do
      total = total + (loc.stack.size or 0)
      if loc.stack.maxSize then maxSz = loc.stack.maxSize end
    end
    result[#result + 1] = {
      label      = label,
      name       = locs[1] and locs[1].stack.name or label,
      totalCount = total,
      maxSize    = maxSz,
      locations  = locs,
    }
  end
  table.sort(result, function(a, b) return a.label < b.label end)
  return result
end

--- Search items by name/label pattern (case-insensitive).
function M.searchItems(query)
  if not query or #query == 0 then return M.getItems() end
  query = query:lower()
  local result = {}
  for label, locs in pairs(itemIndex) do
    local name = (locs[1] and locs[1].stack.name or ""):lower()
    if label:lower():find(query, 1, true) or name:find(query, 1, true) then
      local total = 0
      local maxSz = 64
      for _, loc in ipairs(locs) do
        total = total + (loc.stack.size or 0)
        if loc.stack.maxSize then maxSz = loc.stack.maxSize end
      end
      result[#result + 1] = {
        label      = label,
        name       = locs[1] and locs[1].stack.name or label,
        totalCount = total,
        maxSize    = maxSz,
        locations  = locs,
      }
    end
  end
  table.sort(result, function(a, b) return a.label < b.label end)
  return result
end

--- Get the contents of a specific inventory.
-- @param invIndex  1-based index into inventories[]
-- @return { {slot, stack}, ... }
function M.getInventoryContents(invIndex)
  local inv = inventories[invIndex]
  if not inv then return {} end
  local result = {}
  for slot = 1, inv.size do
    if inv.slots[slot] then
      result[#result + 1] = { slot = slot, stack = inv.slots[slot] }
    end
  end
  return result
end

--- Transfer items between two inventory slots.
-- @param fromInvIdx  Source inventory index (1-based)
-- @param fromSlot    Source slot number
-- @param toInvIdx    Destination inventory index
-- @param toSlot      Destination slot (optional)
-- @param count       Number of items to move
-- @return number of items transferred, or 0 on error
function M.transferItem(fromInvIdx, fromSlot, toInvIdx, toSlot, count)
  local fromInv = inventories[fromInvIdx]
  local toInv   = inventories[toInvIdx]
  if not fromInv or not toInv then return 0 end

  -- Same transposer, different sides → direct transfer
  if fromInv.transposer.address == toInv.transposer.address then
    local tp = fromInv.transposer.proxy
    local ok, moved = pcall(tp.transferItem,
      fromInv.side, toInv.side, count or 64, fromSlot, toSlot)
    if ok then
      lastScan = 0  -- invalidate cache
      return moved or 0
    end
    return 0
  end

  -- Different transposers: need intermediate (not supported in v1)
  return 0
end

--- Move all of an item type to a target inventory.
-- Pulls from all locations where the item exists.
-- @param label     Item label to move
-- @param toInvIdx  Destination inventory index
-- @param maxCount  Maximum items to move (nil = all)
-- @return total items moved
function M.consolidateItem(label, toInvIdx, maxCount)
  local locs = itemIndex[label]
  if not locs then return 0 end
  local toInv = inventories[toInvIdx]
  if not toInv then return 0 end

  local moved = 0
  maxCount = maxCount or math.huge

  for _, loc in ipairs(locs) do
    if moved >= maxCount then break end
    if loc.inv ~= toInv then
      -- Same transposer check
      if loc.inv.transposer.address == toInv.transposer.address then
        local want = math.min(loc.stack.size or 0, maxCount - moved)
        local ok, n = pcall(loc.inv.transposer.proxy.transferItem,
          loc.inv.side, toInv.side, want, loc.slot)
        if ok and n then moved = moved + n end
      end
    end
  end

  if moved > 0 then lastScan = 0 end  -- invalidate cache
  return moved
end

--- Get number of transposers found.
function M.getTransposerCount()
  return #transposers
end

--- Get inventory descriptor by index.
function M.getInventory(idx)
  return inventories[idx]
end

--- Get human-readable name for a side number.
function M.sideName(side)
  return SIDE_NAMES[side] or tostring(side)
end

return M
