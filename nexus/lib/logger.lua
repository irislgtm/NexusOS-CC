-- ============================================================================
-- NEXUS-OS  /lib/logger.lua
-- Timestamped file logger with auto-rotation
-- ============================================================================

local computer  = computer  or require("computer")
local component = component or require("component")
local fs = component.proxy(computer.getBootAddress())

local M = {}

local MAX_SIZE = 65536  -- 64KB auto-rotate threshold

----------------------------------------------------------------------------
-- Logger instance
----------------------------------------------------------------------------

--- Create a new logger writing to the given path.
-- @param path  File path (e.g. "/var/log/system.log")
-- @return logger table with :info(), :warn(), :error(), :write()
function M.new(path)
  local logger = {}
  logger.path = path

  -- Ensure directory exists
  local dir = path:match("^(.+)/[^/]+$")
  if dir and not fs.exists(dir) then
    fs.makeDirectory(dir)
  end

  local function timestamp()
    local t = computer.uptime()
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = math.floor(t % 60)
    return string.format("[%02d:%02d:%02d]", h, m, s)
  end

  local function append(line)
    -- Rotate if too large
    if fs.exists(path) and fs.size(path) > MAX_SIZE then
      local old = path .. ".old"
      if fs.exists(old) then fs.remove(old) end
      fs.rename(path, old)
    end

    local handle = fs.open(path, "a")
    if handle then
      fs.write(handle, line .. "\n")
      fs.close(handle)
    end
  end

  --- Write a raw line
  function logger:write(msg)
    append(timestamp() .. " " .. tostring(msg))
  end

  --- Log at INFO level
  function logger:info(msg)
    append(timestamp() .. " [INFO]  " .. tostring(msg))
  end

  --- Log at WARN level
  function logger:warn(msg)
    append(timestamp() .. " [WARN]  " .. tostring(msg))
  end

  --- Log at ERROR level
  function logger:error(msg)
    append(timestamp() .. " [ERROR] " .. tostring(msg))
  end

  --- Log at ALERT level
  function logger:alert(msg)
    append(timestamp() .. " [ALERT] " .. tostring(msg))
  end

  --- Read last N lines from the log file
  function logger:tail(n)
    n = n or 20
    if not fs.exists(path) then return {} end
    local handle = fs.open(path, "r")
    if not handle then return {} end
    local lines = {}
    local buf = ""
    while true do
      local data = fs.read(handle, 4096)
      if not data then break end
      buf = buf .. data
    end
    fs.close(handle)
    for line in buf:gmatch("[^\n]+") do
      lines[#lines + 1] = line
    end
    -- Return last N
    local start = math.max(1, #lines - n + 1)
    local result = {}
    for i = start, #lines do
      result[#result + 1] = lines[i]
    end
    return result
  end

  return logger
end

return M
