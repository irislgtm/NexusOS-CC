-- ============================================================================
-- NEXUS-OS  /drivers/geolyzer.lua
-- Geolyzer scanning with noise compensation and ore classification
-- ============================================================================

local M = {}

local proxy
local available = false

-- Scan cache: "x:y:z" → { hardness, timestamp }
local cache = {}

-- Ore classification by hardness ranges (approximate, Minecraft defaults)
-- Hardness value → { name, shortName }
local oreTable = {
  { min = 2.9, max = 3.1, name = "diamond_ore",   short = "DIA", color = "entity_passive" },
  { min = 2.9, max = 3.1, name = "emerald_ore",    short = "EMR", color = "entity_passive" },
  { min = 2.9, max = 3.1, name = "gold_ore",       short = "GLD", color = "alert_warn"    },
  { min = 2.9, max = 3.1, name = "redstone_ore",   short = "RED", color = "alert_critical" },
  { min = 2.9, max = 3.1, name = "iron_ore",       short = "IRN", color = "text_secondary" },
  { min = 2.9, max = 3.1, name = "lapis_ore",      short = "LAP", color = "accent"        },
  { min = 2.9, max = 3.1, name = "coal_ore",       short = "COL", color = "text_muted"    },
  -- Generic tiers
  { min = 0.01, max = 0.5,  name = "soft",    short = "SFT", color = "text_muted"    },
  { min = 0.5,  max = 1.5,  name = "medium",  short = "MED", color = "text_secondary" },
  { min = 1.5,  max = 3.0,  name = "hard",    short = "HRD", color = "text_primary"   },
  { min = 3.0,  max = 10.0, name = "ore",     short = "ORE", color = "accent"         },
  { min = 10.0, max = 100,  name = "obsidian", short = "OBS", color = "text_bright"   },
}

local function findGeolyzer()
  if _G.hw then
    proxy = _G.hw.find("geolyzer")
    available = proxy ~= nil
  end
end

function M.isAvailable()
  if proxy == nil then findGeolyzer() end
  return available
end

function M.get()
  if proxy == nil then findGeolyzer() end
  return proxy
end

--- Scan a column relative to the geolyzer.
-- @param x, z  Horizontal offset (-32..32 range)
-- @param y     Vertical offset (defaults to -32)
-- @param w,d,h Scan volume (defaults to 1,1,64)
-- @return Array of hardness values indexed from y offset
function M.scan(x, z, y, w, d, h)
  local g = M.get()
  if not g then return nil, "No geolyzer" end
  x = x or 0
  z = z or 0
  y = y or -32
  w = w or 1
  d = d or 1
  h = h or 64
  return g.scan(x, z, y, w, d, h)
end

--- Multi-pass scan with noise averaging.
-- OC geolyzer adds ±0.2 noise; averaging reduces it.
-- @param x, z   Offset
-- @param passes Number of scans to average (default 4)
-- @return Array of averaged hardness values
function M.scanAvg(x, z, passes)
  local g = M.get()
  if not g then return nil, "No geolyzer" end
  passes = passes or 4

  local sums = {}
  for pass = 1, passes do
    local data = g.scan(x, z)
    if not data then return nil, "Scan failed" end
    for i, v in ipairs(data) do
      sums[i] = (sums[i] or 0) + v
    end
  end

  local result = {}
  for i, s in ipairs(sums) do
    result[i] = s / passes
  end
  return result
end

--- Classify a hardness value.
-- @return { name, short, themeColor } or nil for air
function M.classify(hardness)
  if hardness <= 0 then return nil end  -- air or unloaded

  for _, ore in ipairs(oreTable) do
    if hardness >= ore.min and hardness < ore.max then
      return { name = ore.name, short = ore.short, color = ore.color }
    end
  end
  return { name = "unknown", short = "???", color = "text_muted" }
end

--- Scan and classify a full Y column.
-- @param x, z   Offset
-- @param passes  Averaging passes
-- @return Array of { y, hardness, class } for non-air blocks
function M.scanColumn(x, z, passes)
  local data, err = M.scanAvg(x, z, passes)
  if not data then return nil, err end

  local blocks = {}
  for i, h in ipairs(data) do
    if h > 0 then
      local cl = M.classify(h)
      blocks[#blocks + 1] = {
        y = i - 33,  -- geolyzer y mapping: index 1 = y-32
        hardness = h,
        class = cl,
      }
    end
  end
  return blocks
end

--- Cache a scan result.
function M.cacheSet(x, y, z, hardness)
  local key = x .. ":" .. y .. ":" .. z
  cache[key] = {
    hardness = hardness,
    time = computer and computer.uptime() or 0,
  }
end

--- Get cached value.
function M.cacheGet(x, y, z)
  local key = x .. ":" .. y .. ":" .. z
  return cache[key]
end

--- Clear scan cache.
function M.cacheClear()
  cache = {}
end

--- Detect what blocks are around the geolyzer.
-- Returns a 2D grid (x,z) for a given Y level.
-- @param yLevel  Y world coordinate offset from geolyzer
-- @param radius  Scan radius (max ~5 for decent speed)
function M.scanLayer(yLevel, radius)
  local g = M.get()
  if not g then return nil, "No geolyzer" end
  radius = radius or 5

  local grid = {}
  for x = -radius, radius do
    grid[x] = {}
    for z = -radius, radius do
      local data = g.scan(x, z, yLevel, 1, 1, 1)
      if data and data[1] then
        grid[x][z] = data[1]
      else
        grid[x][z] = 0
      end
    end
  end
  return grid
end

function M.rescan()
  proxy = nil
  findGeolyzer()
  return available
end

return M
