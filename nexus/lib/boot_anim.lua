-- ============================================================================
-- NEXUS-OS  /lib/boot_anim.lua
-- Clean boot splash — spinning indicator + green "N" branding
-- ============================================================================

local M = {}

-- Large block-letter "N" (7 lines tall, 9 columns wide)
local logo = {
  "█▄  █",
  "██▄ █",
  "█ ▀██",
  "█  ▀█",
}

--- Boot splash: centred green "N" with a spinning ASCII indicator beneath.
-- @param gpu      GPU proxy
-- @param duration Seconds to display (default 2.5)
function M.run(gpu, duration)
  if not gpu then return end
  duration = duration or 2.5

  local w, h = gpu.getResolution()
  local spinner = { "|", "/", "-", "\\" }
  local nSpinner = #spinner

  gpu.setBackground(0x0A0A0A)
  gpu.fill(1, 1, w, h, " ")

  -- Centre the logo block
  local logoW = #logo[1]       -- visual width (unicode-aware not needed; all ASCII)
  local logoH = #logo
  local lx = math.floor((w - logoW) / 2) + 1
  local ly = math.floor(h / 2) - logoH       -- place logo above centre

  -- Draw the static "N"
  gpu.setForeground(0x00CC00)
  for i, line in ipairs(logo) do
    gpu.set(lx, ly + i - 1, line)
  end

  -- "NEXUS" label just below the N
  local label = "N E X U S"
  local labelX = math.floor((w - #label) / 2) + 1
  local labelY = ly + logoH + 1
  gpu.setForeground(0x005500)
  gpu.set(labelX, labelY, label)

  -- Spinner row
  local spinY = labelY + 2
  local spinX = math.floor(w / 2) + 1

  local startTime = computer.uptime()
  local frame = 0

  while (computer.uptime() - startTime) < duration do
    frame = frame + 1
    local ch = spinner[(frame % nSpinner) + 1]

    gpu.setForeground(0x00FF00)
    gpu.set(spinX, spinY, ch)

    computer.pullSignal(0.15)
  end

  -- Brief clear before handing off to desktop
  gpu.setBackground(0x000000)
  gpu.fill(1, 1, w, h, " ")
end

return M
