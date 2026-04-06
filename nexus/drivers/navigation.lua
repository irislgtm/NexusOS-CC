-- ============================================================================
-- NEXUS-OS  /drivers/navigation.lua
-- Navigation upgrade: position, facing, waypoints
-- ============================================================================

local M = {}

local proxy
local available = false

local function findNav()
  if _G.hw then
    proxy = _G.hw.find("navigation")
    available = proxy ~= nil
  end
end

function M.isAvailable()
  if proxy == nil then findNav() end
  return available
end

function M.get()
  if proxy == nil then findNav() end
  return proxy
end

--- Get position relative to map center.
-- @return x, y, z or nil
function M.getPosition()
  local n = M.get()
  if not n then return nil end
  return n.getPosition()
end

--- Get facing direction.
-- @return {sides constant} or nil
function M.getFacing()
  local n = M.get()
  if not n then return nil end
  return n.getFacing()
end

--- Get waypoints within range.
-- @param range  Detection range in blocks
-- @return Array of { label, x, y, z, redstone } or nil
function M.getWaypoints(range)
  local n = M.get()
  if not n then return nil end
  return n.findWaypoints(range or 64)
end

function M.rescan()
  proxy = nil
  findNav()
  return available
end

return M
