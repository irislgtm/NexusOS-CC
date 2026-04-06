-- ============================================================================
-- NEXUS-OS  /lib/boot_anim.lua
-- Matrix-style boot animation + POST sequence
-- ============================================================================

local M = {}

--- Matrix rain effect (timed, fills screen with falling green chars).
-- @param gpu      GPU proxy
-- @param duration Seconds to run
function M.matrixRain(gpu, duration)
  if not gpu then return end
  local w, h = gpu.getResolution()
  local startTime = computer.uptime()

  -- Column state: y position per column
  local cols = {}
  for x = 1, w do
    cols[x] = math.random(1, h)
  end

  local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#$%&*<>{}[]|/"

  gpu.setBackground(0x000000)
  gpu.fill(1, 1, w, h, " ")

  while (computer.uptime() - startTime) < duration do
    for x = 1, w do
      if math.random() > 0.4 then
        -- Draw falling char (bright head)
        local y = cols[x]
        local ch = chars:sub(math.random(1, #chars), math.random(1, #chars))
        if #ch == 0 then ch = "0" end
        ch = ch:sub(1, 1)

        gpu.setForeground(0x00FF00)
        gpu.set(x, y, ch)

        -- Dim the trail
        local trailY = y - 1
        if trailY >= 1 then
          gpu.setForeground(0x005500)
          local tc = chars:sub(math.random(1, #chars), math.random(1, #chars))
          if #tc == 0 then tc = "." end
          gpu.set(x, trailY, tc:sub(1, 1))
        end

        -- Fade further back
        local fadeY = y - math.random(4, 12)
        if fadeY >= 1 then
          gpu.setForeground(0x002200)
          gpu.set(x, fadeY, " ")
        end

        -- Advance column
        cols[x] = y + 1
        if cols[x] > h then
          cols[x] = 1
          -- Clear column occasionally
          if math.random() > 0.7 then
            gpu.setForeground(0x000000)
            for cy = 1, h do gpu.set(x, cy, " ") end
          end
        end
      end
    end
    -- Yield to prevent timeout
    computer.pullSignal(0.02)
  end
end

--- POST (Power-On Self-Test) display.
-- Shows hardware detection output like a real BIOS.
function M.post(gpu)
  if not gpu then return end
  local w, h = gpu.getResolution()

  gpu.setBackground(0x000000)
  gpu.fill(1, 1, w, h, " ")

  local y = 1
  local function postLine(text, color)
    if y > h then
      gpu.copy(1, 2, w, h - 1, 0, -1)
      gpu.fill(1, h, w, 1, " ")
      y = h
    end
    gpu.setForeground(color or 0x00FF00)
    gpu.set(1, y, text)
    y = y + 1
    computer.pullSignal(0.05)
  end

  local function postOK(label, value)
    gpu.setForeground(0x00FF00)
    if y > h then
      gpu.copy(1, 2, w, h - 1, 0, -1)
      gpu.fill(1, h, w, 1, " ")
      y = h
    end
    gpu.set(1, y, label)
    gpu.setForeground(0x00AA00)
    gpu.set(40, y, "[ " .. value .. " ]")
    y = y + 1
    computer.pullSignal(0.03)
  end

  -- ASCII logo
  postLine("", 0x00FF00)
  postLine("  ███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗", 0x00FF00)
  postLine("  ████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝", 0x00FF00)
  postLine("  ██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗", 0x00FF00)
  postLine("  ██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║", 0x00AA00)
  postLine("  ██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║", 0x00AA00)
  postLine("  ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝", 0x005500)
  postLine("          Surveillance Operating System v1.0", 0x005500)
  postLine("", 0x00FF00)

  -- Hardware detection
  postLine("POST — Hardware Detection", 0x00FFFF)
  postLine(string.rep("─", 60), 0x005555)

  -- GPU
  local depth = gpu.maxDepth()
  local tier = depth >= 8 and "T3" or depth >= 4 and "T2" or "T1"
  postOK("  GPU", tier .. " (" .. w .. "x" .. h .. ", " .. tostring(2^depth) .. " colors)")

  -- Memory
  local totalMem = computer.totalMemory()
  local freeMem = computer.freeMemory()
  postOK("  RAM", math.floor(totalMem / 1024) .. "KB total, " ..
    math.floor(freeMem / 1024) .. "KB free")

  -- VRAM
  local vram = gpu.totalMemory and gpu.totalMemory() or 0
  if vram > 0 then
    postOK("  VRAM", math.floor(vram / 1024) .. "KB")
  end

  -- Components
  local counts = {}
  for addr, ctype in component.list() do
    counts[ctype] = (counts[ctype] or 0) + 1
  end

  local important = {
    "screen", "keyboard", "filesystem", "modem",
    "motion_sensor", "geolyzer", "navigation",
    "chunkloader", "redstone", "transposer",
  }
  for _, ctype in ipairs(important) do
    if counts[ctype] then
      postOK("  " .. ctype, tostring(counts[ctype]) .. " found")
    end
  end

  -- Mod components
  local modTypes = {
    "me_controller", "me_interface",
    "br_reactor", "br_turbine",
    "ic2_reactor",
    "draconic_rf_storage", "draconic_reactor",
    "capacitor_bank",
  }
  local foundMods = false
  for _, ctype in ipairs(modTypes) do
    if counts[ctype] then
      if not foundMods then
        postLine("", 0x00FF00)
        postLine("  Mod Integration", 0x00FFFF)
        foundMods = true
      end
      postOK("    " .. ctype, tostring(counts[ctype]))
    end
  end

  postLine("", 0x00FF00)
  postLine(string.rep("─", 60), 0x005555)

  local totalComponents = 0
  for _, n in pairs(counts) do totalComponents = totalComponents + n end
  postOK("  Components Total", tostring(totalComponents))

  postLine("", 0x00FF00)
  postLine("  Boot sequence complete. Starting desktop...", 0x00FF00)
  computer.pullSignal(0.5)
end

--- Full boot sequence: rain → POST → clear.
function M.run(gpu, rainDuration)
  if not gpu then return end
  rainDuration = rainDuration or 1.5
  M.matrixRain(gpu, rainDuration)
  M.post(gpu)
end

return M
