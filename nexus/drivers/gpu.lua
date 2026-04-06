-- ============================================================================
-- NEXUS-OS  /drivers/gpu.lua
-- GPU proxy cache, resolution management, color helpers
-- ============================================================================

local M = {}

local proxy

--- Get current bound GPU proxy.
function M.get()
  if not proxy and _G.hw then
    proxy = _G.hw.find("gpu")
  end
  return proxy
end

--- Get current resolution.
function M.getResolution()
  local g = M.get()
  if g then return g.getResolution() end
  return 160, 50
end

--- Get maximum resolution for current tier.
function M.getMaxResolution()
  local g = M.get()
  if g then return g.maxResolution() end
  return 160, 50
end

--- Set resolution, clamped to max.
function M.setResolution(w, h)
  local g = M.get()
  if not g then return false end
  local mw, mh = g.maxResolution()
  w = math.min(w, mw)
  h = math.min(h, mh)
  return g.setResolution(w, h)
end

--- Get GPU tier (1-3).
function M.getTier()
  local g = M.get()
  if not g then return 0 end
  local d = g.maxDepth()
  if d >= 8 then return 3 end
  if d >= 4 then return 2 end
  return 1
end

--- Get color depth.
function M.getDepth()
  local g = M.get()
  if g then return g.getDepth() end
  return 1
end

--- Total VRAM in bytes (approximate based on tier).
function M.getVRAM()
  local g = M.get()
  if g then return g.totalMemory() end
  return 0
end

--- Free VRAM.
function M.getFreeVRAM()
  local g = M.get()
  if g then return g.freeMemory() end
  return 0
end

--- Rebind GPU (useful after hot-swap).
function M.rebind()
  proxy = nil
  return M.get()
end

return M
