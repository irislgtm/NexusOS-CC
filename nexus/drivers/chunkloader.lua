-- ============================================================================
-- NEXUS-OS  /drivers/chunkloader.lua
-- Chunk loading control (stub if absent)
-- ============================================================================

local M = {}

local proxy
local available = false

local function findChunkloader()
  if _G.hw then
    proxy = _G.hw.find("chunkloader")
    available = proxy ~= nil
  end
end

function M.isAvailable()
  if proxy == nil then findChunkloader() end
  return available
end

function M.get()
  if proxy == nil then findChunkloader() end
  return proxy
end

--- Is chunk loading active?
function M.isActive()
  local c = M.get()
  if not c then return false end
  return c.isActive()
end

--- Enable or disable chunk loading.
function M.setActive(state)
  local c = M.get()
  if not c then return false end
  return c.setActive(state == true)
end

function M.rescan()
  proxy = nil
  findChunkloader()
  return available
end

return M
