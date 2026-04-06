-- ============================================================================
-- NEXUS-OS  /lib/boot_anim.lua
-- Premium boot splash — matrix rain → NEXUS logo + spinner
-- Zero per-column allocation: uses flat arrays for column state
-- ============================================================================

local M = {}

local logo = {
  "█▄  █ █▀▀ ▀▄▀ █  █ █▀▀",
  "█ ▀██ █▀▀  █  █  █ ▀▀█",
  "█  ▀█ ▀▀▀ ▀ ▀ ▀▀▀▀ ▀▀▀",
}

--- Full boot sequence: matrix rain → branded splash → clear.
-- @param gpu      GPU proxy
-- @param duration Total seconds for the rain phase (default 1.5)
function M.run(gpu, duration)
  if not gpu then return end
  duration = duration or 1.5
  local w, h = gpu.getResolution()

  -- ── Phase 1: Matrix Rain (flat arrays, no table-per-column) ──────
  local chars = "0123456789ABCDEFabcdef@#$&*"
  local nC = #chars

  -- Flat arrays for column state
  local colY = {}   -- y position
  local colSpd = {} -- speed
  local colOn = {}  -- 1=active, 0=idle
  for x = 1, w do
    colY[x]   = math.random(1, h)
    colSpd[x] = math.random(1, 2)
    colOn[x]  = math.random() > 0.35 and 1 or 0
  end

  gpu.setBackground(0x000000)
  gpu.fill(1, 1, w, h, " ")

  local batchStart = 1
  local BATCH = 40
  local startTime = computer.uptime()

  while (computer.uptime() - startTime) < duration do
    local batchEnd = math.min(batchStart + BATCH - 1, w)
    for x = batchStart, batchEnd do
      if colOn[x] == 1 then
        local y = colY[x]
        if y >= 1 and y <= h then
          gpu.setForeground(0x00FF41)
          local ci = math.random(1, nC)
          gpu.set(x, y, chars:sub(ci, ci))
        end
        local ty = y - 1
        if ty >= 1 and ty <= h then
          gpu.setForeground(0x005500)
          local ci = math.random(1, nC)
          gpu.set(x, ty, chars:sub(ci, ci))
        end
        local fy = y - math.random(5, 12)
        if fy >= 1 and fy <= h then
          gpu.setBackground(0x000000)
          gpu.set(x, fy, " ")
        end
        colY[x] = y + colSpd[x]
        if colY[x] > h then
          colY[x] = 1
          colOn[x] = math.random() > 0.25 and 1 or 0
        end
      else
        if math.random() > 0.93 then
          colOn[x] = 1
          colY[x] = 1
        end
      end
    end
    batchStart = batchEnd + 1
    if batchStart > w then batchStart = 1 end
    computer.pullSignal(0.05)
  end

  -- Free column state immediately
  colY, colSpd, colOn = nil, nil, nil

  -- ── Phase 2: Branded splash ──────────────────────────────────────
  gpu.setBackground(0x0A0A0A)
  gpu.fill(1, 1, w, h, " ")

  local logoH = #logo
  local logoW = #logo[1]
  local lx = math.floor((w - logoW) / 2) + 1
  local ly = math.floor(h / 2) - logoH

  gpu.setForeground(0x00CC00)
  for i, line in ipairs(logo) do
    gpu.set(lx, ly + i - 1, line)
  end

  -- Subtitle
  local sub = "Surveillance Operating System"
  gpu.setForeground(0x005500)
  gpu.set(math.floor((w - #sub) / 2) + 1, ly + logoH + 1, sub)

  -- Spinner
  local spinner = { "|", "/", "-", "\\" }
  local spinX = math.floor(w / 2) + 1
  local spinY = ly + logoH + 3
  local splashStart = computer.uptime()

  while (computer.uptime() - splashStart) < 1.2 do
    local idx = math.floor((computer.uptime() - splashStart) / 0.15)
    gpu.setForeground(0x00FF41)
    gpu.set(spinX, spinY, spinner[(idx % 4) + 1])
    computer.pullSignal(0.15)
  end

  -- ── Phase 3: Clear ───────────────────────────────────────────────
  gpu.setBackground(0x000000)
  gpu.fill(1, 1, w, h, " ")
end

return M
