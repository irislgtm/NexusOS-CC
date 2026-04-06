-- ============================================================================
-- NEXUS-OS  /drivers/transposer.lua
-- Item/fluid transfer abstraction
-- ============================================================================

local M = {}

local proxy
local available = false

local function findTransposer()
  if _G.hw then
    proxy = _G.hw.find("transposer")
    available = proxy ~= nil
  end
end

function M.isAvailable()
  if proxy == nil then findTransposer() end
  return available
end

function M.get()
  if proxy == nil then findTransposer() end
  return proxy
end

--- Get inventory size on a side (0-5).
function M.getInventorySize(side)
  local t = M.get()
  if not t then return 0 end
  return t.getInventorySize(side) or 0
end

--- Get stack in a slot.
-- @return {name, damage, count, maxSize, label, ...} or nil
function M.getStackInSlot(side, slot)
  local t = M.get()
  if not t then return nil end
  return t.getStackInSlot(side, slot)
end

--- Get all stacks on a side.
function M.getAllStacks(side)
  local t = M.get()
  if not t then return nil end
  return t.getAllStacks(side)
end

--- Transfer items between sides.
-- @param count   Number of items
-- @param fromSide, fromSlot  Source
-- @param toSide, toSlot      Destination
-- @return number of items transferred
function M.transferItem(fromSide, toSide, count, fromSlot, toSlot)
  local t = M.get()
  if not t then return 0 end
  return t.transferItem(fromSide, toSide, count, fromSlot, toSlot)
end

--- Get fluid tank info on a side.
-- @return { name, amount, capacity } or nil
function M.getFluidInTank(side)
  local t = M.get()
  if not t or not t.getFluidInTank then return nil end
  return t.getFluidInTank(side)
end

--- Transfer fluid between sides.
function M.transferFluid(fromSide, toSide, amount)
  local t = M.get()
  if not t or not t.transferFluid then return 0 end
  return t.transferFluid(fromSide, toSide, amount)
end

function M.rescan()
  proxy = nil
  findTransposer()
  return available
end

return M
