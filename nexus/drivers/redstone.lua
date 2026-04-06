-- ============================================================================
-- NEXUS-OS  /drivers/redstone.lua
-- Unified API for vanilla + bundled redstone I/O
-- ============================================================================

local M = {}

local proxy
local available = false

-- Rate limit: 1 change per tick (0.05s)
local lastSet = 0
local RATE_LIMIT = 0.05

local function findRedstone()
  if _G.hw then
    proxy = _G.hw.find("redstone")
    available = proxy ~= nil
  end
end

function M.isAvailable()
  if proxy == nil then findRedstone() end
  return available
end

function M.get()
  if proxy == nil then findRedstone() end
  return proxy
end

-- Side constants (OC sides library)
M.sides = {
  bottom = 0, down = 0,
  top = 1, up = 1,
  back = 2, north = 2,
  front = 3, south = 3,
  right = 4, west = 4,
  left = 5, east = 5,
}

--- Get analog input on a side.
-- @param side  Number (0-5) or name string
-- @return 0..15
function M.getInput(side)
  local r = M.get()
  if not r then return 0 end
  if type(side) == "string" then side = M.sides[side] or 0 end
  return r.getInput(side)
end

--- Get analog output on a side.
function M.getOutput(side)
  local r = M.get()
  if not r then return 0 end
  if type(side) == "string" then side = M.sides[side] or 0 end
  return r.getOutput(side)
end

--- Set analog output on a side (rate-limited).
-- @param side   Number or name
-- @param value  0..15
function M.setOutput(side, value)
  local r = M.get()
  if not r then return false end
  if type(side) == "string" then side = M.sides[side] or 0 end
  value = math.max(0, math.min(15, math.floor(value or 0)))

  local now = computer and computer.uptime() or 0
  if (now - lastSet) < RATE_LIMIT then return false end
  lastSet = now

  return r.setOutput(side, value)
end

--- Get bundled input.
-- @param side   Side
-- @param color  Color bitmask (0..15)
-- @return 0..255
function M.getBundledInput(side, color)
  local r = M.get()
  if not r or not r.getBundledInput then return 0 end
  if type(side) == "string" then side = M.sides[side] or 0 end
  return r.getBundledInput(side, color)
end

--- Set bundled output.
function M.setBundledOutput(side, color, value)
  local r = M.get()
  if not r or not r.setBundledOutput then return false end
  if type(side) == "string" then side = M.sides[side] or 0 end

  local now = computer and computer.uptime() or 0
  if (now - lastSet) < RATE_LIMIT then return false end
  lastSet = now

  return r.setBundledOutput(side, color, value)
end

--- Get comparator input value.
function M.getComparatorInput(side)
  local r = M.get()
  if not r or not r.getComparatorInput then return 0 end
  if type(side) == "string" then side = M.sides[side] or 0 end
  return r.getComparatorInput(side)
end

function M.rescan()
  proxy = nil
  findRedstone()
  return available
end

return M
