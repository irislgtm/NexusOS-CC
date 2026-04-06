-- ============================================================================
-- NEXUS-OS  /lib/config.lua
-- Configuration file reader/writer using serial.lua
-- Files stored in /etc/*.cfg as serialized Lua tables
-- ============================================================================

local serial = require("serial")

local M = {}

local computer  = computer  or require("computer")
local component = component or require("component")
local fs = component.proxy(computer.getBootAddress())

----------------------------------------------------------------------------
-- Internal helpers
----------------------------------------------------------------------------

local function readFile(path)
  if not fs.exists(path) then return nil end
  local handle = fs.open(path, "r")
  if not handle then return nil end
  local chunks = {}
  while true do
    local data = fs.read(handle, 4096)
    if not data then break end
    chunks[#chunks + 1] = data
  end
  fs.close(handle)
  return table.concat(chunks)
end

local function writeFile(path, content)
  -- Ensure parent directory exists
  local dir = path:match("^(.+)/[^/]+$")
  if dir and not fs.exists(dir) then
    fs.makeDirectory(dir)
  end
  local handle = fs.open(path, "w")
  if not handle then return false end
  fs.write(handle, content)
  fs.close(handle)
  return true
end

----------------------------------------------------------------------------
-- API
----------------------------------------------------------------------------

--- Load a config file, returning its contents as a table.
-- @param path  Absolute path (e.g. "/etc/os.cfg")
-- @return table or nil
function M.load(path)
  local content = readFile(path)
  if not content then return nil end
  local data = serial.unserialize(content)
  if type(data) ~= "table" then return nil end
  return data
end

--- Save a table to a config file.
-- @param path  Absolute path
-- @param data  Table to save
-- @return boolean success
function M.save(path, data)
  if type(data) ~= "table" then return false end
  local content = serial.serialize(data)
  return writeFile(path, content)
end

--- Load a config with defaults. Missing keys are filled from defaults.
-- @param path     Config file path
-- @param defaults Default table
-- @return merged table (also saved if any defaults were applied)
function M.loadWithDefaults(path, defaults)
  local data = M.load(path) or {}
  local changed = false
  for k, v in pairs(defaults) do
    if data[k] == nil then
      data[k] = v
      changed = true
    end
  end
  if changed then
    M.save(path, data)
  end
  return data
end

return M
