-- ============================================================================
-- NEXUS-OS  /drivers/motion.lua
-- Motion sensor polling + event-driven entity tracking
-- ============================================================================

local M = {}

local proxy
local available = false

-- Tracked contacts: name → { x, y, z, lastSeen, classification, speed }
local contacts = {}

-- Config
local STALE_TIMEOUT = 15  -- seconds before contact expires

local function findMotion()
  if _G.hw then
    proxy = _G.hw.find("motion_sensor")
    available = proxy ~= nil
  end
end

function M.isAvailable()
  if proxy == nil then findMotion() end
  return available
end

function M.get()
  if proxy == nil then findMotion() end
  return proxy
end

--- Get sensor sensitivity (range).
function M.getSensitivity()
  local s = M.get()
  if not s or not s.getSensitivity then return 0 end
  return s.getSensitivity()
end

--- Set sensor sensitivity (0..32).
function M.setSensitivity(value)
  local s = M.get()
  if not s or not s.setSensitivity then return false end
  value = math.max(0, math.min(32, value or 8))
  return s.setSensitivity(value)
end

--- Classify entity by name patterns.
local function classifyEntity(name)
  if not name then return "unknown" end
  local n = name:lower()

  -- Players have capitalized names, no underscores typically
  -- Hostile mobs
  local hostiles = {
    "zombie", "skeleton", "creeper", "spider", "enderman",
    "witch", "slime", "blaze", "ghast", "wither",
    "guardian", "shulker", "vindicator", "evoker", "vex",
    "phantom", "drowned", "pillager", "ravager", "hoglin",
    "piglin_brute", "magma_cube", "silverfish",
  }
  for _, h in ipairs(hostiles) do
    if n:find(h) then return "hostile" end
  end

  -- Passive mobs
  local passives = {
    "cow", "pig", "sheep", "chicken", "horse", "donkey",
    "mule", "rabbit", "wolf", "cat", "ocelot", "parrot",
    "villager", "iron_golem", "snow_golem", "bat", "squid",
    "fox", "bee", "turtle", "dolphin", "panda", "llama",
  }
  for _, p in ipairs(passives) do
    if n:find(p) then return "passive" end
  end

  -- If name contains no underscore and starts uppercase, likely a player
  if not n:find("_") or (name:sub(1,1):match("%u") and #name <= 16) then
    return "player"
  end

  return "unknown"
end

--- Process a motion signal.
-- Called by event system: motion(addr, relX, relY, relZ, entityName)
function M.onMotion(_, _, relX, relY, relZ, entityName)
  local now = computer and computer.uptime() or 0
  local name = entityName or "unknown"

  local prev = contacts[name]
  local speed = 0
  if prev then
    local dx = relX - prev.x
    local dy = relY - prev.y
    local dz = relZ - prev.z
    local dt = now - prev.lastSeen
    if dt > 0 then
      speed = math.sqrt(dx*dx + dy*dy + dz*dz) / dt
    end
  end

  contacts[name] = {
    x = relX,
    y = relY,
    z = relZ,
    lastSeen = now,
    classification = classifyEntity(name),
    speed = speed,
    distance = math.sqrt(relX*relX + relY*relY + relZ*relZ),
  }
end

--- Get current contact list (purges stale entries).
-- @return Array of { name, x, y, z, distance, classification, speed, lastSeen }
function M.getContacts()
  local now = computer and computer.uptime() or 0
  local result = {}

  for name, c in pairs(contacts) do
    if (now - c.lastSeen) <= STALE_TIMEOUT then
      result[#result + 1] = {
        name = name,
        x = c.x,
        y = c.y,
        z = c.z,
        distance = c.distance,
        classification = c.classification,
        speed = c.speed,
        lastSeen = c.lastSeen,
      }
    else
      contacts[name] = nil
    end
  end

  -- Sort by distance
  table.sort(result, function(a, b) return a.distance < b.distance end)
  return result
end

--- Get contacts of a specific classification.
function M.getContactsByClass(class)
  local all = M.getContacts()
  local result = {}
  for _, c in ipairs(all) do
    if c.classification == class then
      result[#result + 1] = c
    end
  end
  return result
end

--- Get player contacts only.
function M.getPlayers()
  return M.getContactsByClass("player")
end

--- Get hostile contacts only.
function M.getHostiles()
  return M.getContactsByClass("hostile")
end

--- Set stale timeout in seconds.
function M.setStaleTimeout(seconds)
  STALE_TIMEOUT = seconds or 15
end

--- Clear all contacts.
function M.clearContacts()
  contacts = {}
end

--- Install motion event listener.
function M.install()
  if _G.event then
    _G.event.listen("motion", M.onMotion)
  end
end

function M.rescan()
  proxy = nil
  findMotion()
  return available
end

return M
