-- ============================================================================
-- NEXUS-OS  /boot/02_memory.lua
-- Module loader (require), package system, standard library bootstrap
-- ============================================================================

local computer  = computer  or require("computer")
local component = component or require("component")
local filesystem = component.proxy(computer.getBootAddress())

----------------------------------------------------------------------------
-- Package system
----------------------------------------------------------------------------
_G.package = _G.package or {}
package.loaded  = package.loaded or {}
package.path    = "/lib/?.lua;/lib/?/init.lua;/drivers/?.lua;/?.lua"
package.preload = package.preload or {}

-- Already-available globals
package.loaded["component"] = component
package.loaded["computer"]  = computer

----------------------------------------------------------------------------
-- Filesystem helpers (low-level, before require works)
----------------------------------------------------------------------------
local function fsRead(path)
  if not filesystem.exists(path) then return nil end
  local handle = filesystem.open(path, "r")
  if not handle then return nil end
  local chunks = {}
  while true do
    local chunk = filesystem.read(handle, 4096)
    if not chunk then break end
    chunks[#chunks + 1] = chunk
  end
  filesystem.close(handle)
  return table.concat(chunks)
end

local function fsExists(path)
  return filesystem.exists(path)
end

----------------------------------------------------------------------------
-- require() implementation
----------------------------------------------------------------------------
local function searchPath(name)
  local tried = {}
  for pattern in package.path:gmatch("[^;]+") do
    local path = pattern:gsub("%?", name)
    if fsExists(path) then
      return path
    end
    tried[#tried + 1] = "  " .. path
  end
  return nil, "module '" .. name .. "' not found:\n" .. table.concat(tried, "\n")
end

function _G.require(name)
  -- Check cache
  if package.loaded[name] then
    return package.loaded[name]
  end

  -- Check preloaded
  if package.preload[name] then
    local result = package.preload[name]()
    package.loaded[name] = result or true
    return package.loaded[name]
  end

  -- Search filesystem
  -- Allow both "lib.gui.screen" (dot notation) and "lib/gui/screen" (path)
  local searchName = name:gsub("%.", "/")
  local path, err = searchPath(searchName)
  if not path then
    error(err, 2)
  end

  -- Load and execute
  local source = fsRead(path)
  if not source then
    error("require: failed to read '" .. path .. "'", 2)
  end

  local fn, loadErr = load(source, "=" .. path)
  if not fn then
    error("require: syntax error in '" .. path .. "': " .. tostring(loadErr), 2)
  end

  local result = fn()
  package.loaded[name] = result or true
  return package.loaded[name]
end

local function fsWrite(path, data)
  local handle = filesystem.open(path, "w")
  if not handle then return false end
  filesystem.write(handle, data)
  filesystem.close(handle)
  return true
end

local function fsList(path)
  local result = {}
  if not filesystem.isDirectory(path) then return result end
  local iter = filesystem.list(path)
  if iter then
    for entry in iter do
      result[#result + 1] = entry
    end
  end
  return result
end

local function fsMkdir(path)
  return filesystem.makeDirectory(path)
end

----------------------------------------------------------------------------
-- Export filesystem helpers for later boot scripts
----------------------------------------------------------------------------
_G._fs = {
  read    = fsRead,
  write   = fsWrite,
  exists  = fsExists,
  list    = fsList,
  mkdir   = fsMkdir,
  proxy   = filesystem,
}

-- Expose boot filesystem as a proxy so other code can use it
hw.bootFS = filesystem

-- Boot message
hw.gpu.set(1, 2, "[BOOT] Module loader initialized | search: " .. package.path:sub(1, 50) .. "...")

return true
