-- ============================================================================
-- NEXUS-OS  /boot/01_hardware.lua
-- Hardware detection, GPU→Screen binding, tier assertion
-- ============================================================================

local component = component or require("component")
local computer  = computer  or require("computer")

-- Global hardware proxy table
_G.hw = _G.hw or {}

----------------------------------------------------------------------------
-- Detect primary GPU and Screen, bind them, set T3 resolution
----------------------------------------------------------------------------
local gpuAddr = component.list("gpu")()
if not gpuAddr then
  error("NEXUS-OS FATAL: No GPU detected. Cannot boot.")
end

hw.gpu = component.proxy(gpuAddr)

local screenAddr = component.list("screen")()
if not screenAddr then
  error("NEXUS-OS FATAL: No screen detected. Cannot boot.")
end

hw.gpu.bind(screenAddr, false)
hw.screen = screenAddr

-- Determine GPU tier from max depth
local maxW, maxH = hw.gpu.maxResolution()
local maxDepth   = hw.gpu.maxDepth()

hw.gpuTier = 1
if maxDepth >= 8 then
  hw.gpuTier = 3
elseif maxDepth >= 4 then
  hw.gpuTier = 2
end

if hw.gpuTier < 3 then
  hw.gpu.setResolution(maxW, maxH)
  hw.gpu.setDepth(maxDepth)
  hw.gpu.setBackground(0x000000)
  hw.gpu.setForeground(0xFF0000)
  hw.gpu.fill(1, 1, maxW, maxH, " ")
  hw.gpu.set(1, 1, "NEXUS-OS requires a Tier 3 GPU and Screen.")
  hw.gpu.set(1, 2, "Current GPU tier: " .. hw.gpuTier)
  hw.gpu.set(1, 3, "Please upgrade your hardware and reboot.")
  error("NEXUS-OS FATAL: Tier 3 GPU required (found T" .. hw.gpuTier .. ")")
end

-- Set optimal T3 resolution
hw.gpu.setDepth(8)
hw.gpu.setResolution(160, 50)
hw.W, hw.H = 160, 50

-- Clear screen
hw.gpu.setBackground(0x000000)
hw.gpu.setForeground(0x00FF41)
hw.gpu.fill(1, 1, hw.W, hw.H, " ")

----------------------------------------------------------------------------
-- Scan and cache all component proxies by type
----------------------------------------------------------------------------
hw.components = {}  -- type → {addr1, addr2, ...}
hw.proxies    = {}  -- addr → proxy

for addr, ctype in component.list() do
  if not hw.components[ctype] then
    hw.components[ctype] = {}
  end
  table.insert(hw.components[ctype], addr)
  hw.proxies[addr] = component.proxy(addr)
end

--- Get first component proxy of a given type, or nil
function hw.find(ctype)
  local addrs = hw.components[ctype]
  if addrs and addrs[1] then
    return hw.proxies[addrs[1]], addrs[1]
  end
  return nil, nil
end

--- Get all proxies of a given type
function hw.findAll(ctype)
  local result = {}
  local addrs = hw.components[ctype] or {}
  for _, addr in ipairs(addrs) do
    result[#result + 1] = hw.proxies[addr]
  end
  return result
end

--- Refresh component list (call after hotplug)
function hw.rescan()
  hw.components = {}
  hw.proxies = {}
  for addr, ctype in component.list() do
    if not hw.components[ctype] then
      hw.components[ctype] = {}
    end
    table.insert(hw.components[ctype], addr)
    hw.proxies[addr] = component.proxy(addr)
  end
end

-- Boot message
hw.gpu.set(1, 1, "[BOOT] Hardware scan complete: " ..
  #(function() local n=0; for _ in component.list() do n=n+1 end; return tostring(n) end)() ..
  " ... nah")

-- Count components properly
local compCount = 0
for _ in component.list() do compCount = compCount + 1 end

hw.gpu.fill(1, 1, hw.W, 1, " ")
hw.gpu.set(1, 1, "[BOOT] Hardware: " .. compCount .. " components | GPU T3 | " .. hw.W .. "x" .. hw.H)

return true
