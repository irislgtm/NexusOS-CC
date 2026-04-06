-- ============================================================================
-- NEXUS-OS  /lib/gui/screen.lua
-- VRAM double-buffered rendering engine with dirty-rect optimization
-- T3 GPU: 160x50, 256 colors, hardware VRAM via allocateBuffer/bitblt
-- ============================================================================

local M = {}

local gpu    = nil
local buf    = nil   -- VRAM buffer index (0 = screen)
local W, H   = 160, 50
local hasBuf = false -- does the GPU support VRAM buffers?

-- Dirty tracking: list of {x, y, w, h} rects changed since last flush
local dirty = {}
local fullDirty = true  -- if true, flush entire screen

-- Current drawing state
local curFg = 0x00FF41
local curBg = 0x000000

----------------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------------

--- Initialize the screen buffer system.
-- Must be called after boot/01_hardware.lua has set up hw.gpu.
function M.init()
  gpu = hw.gpu
  W, H = gpu.getResolution()

  -- Try to allocate a VRAM buffer for double-buffering
  local ok, result = pcall(gpu.allocateBuffer, W, H)
  if ok and result then
    buf = result
    hasBuf = true
    gpu.setActiveBuffer(buf)
  else
    -- No VRAM support (shouldn't happen on T3, but be safe)
    buf = 0
    hasBuf = false
  end

  curFg = 0x00FF41
  curBg = 0x000000
  M.clear(0x000000)
  M.flush()
end

--- Get screen dimensions
function M.getSize()
  return W, H
end

----------------------------------------------------------------------------
-- Color management (minimize GPU calls via state tracking)
----------------------------------------------------------------------------

--- Set foreground color. Only issues GPU call if color changed.
function M.setFg(color)
  if color ~= curFg then
    gpu.setForeground(color)
    curFg = color
  end
end

--- Set background color. Only issues GPU call if color changed.
function M.setBg(color)
  if color ~= curBg then
    gpu.setBackground(color)
    curBg = color
  end
end

--- Set both fg and bg. Minimizes calls.
function M.setColors(fg, bg)
  M.setFg(fg)
  M.setBg(bg)
end

----------------------------------------------------------------------------
-- Dirty-rect tracking
----------------------------------------------------------------------------

local function markDirty(x, y, w, h)
  if fullDirty then return end
  dirty[#dirty + 1] = {x = x, y = y, w = w, h = h}
  -- If too many small rects, just mark full dirty
  if #dirty > 50 then
    fullDirty = true
    dirty = {}
  end
end

--- Force full screen redraw on next flush
function M.invalidate()
  fullDirty = true
  dirty = {}
end

----------------------------------------------------------------------------
-- Drawing primitives (all draw to VRAM buffer)
----------------------------------------------------------------------------

--- Clear entire screen with a background color.
function M.clear(bg)
  bg = bg or 0x000000
  M.setBg(bg)
  gpu.fill(1, 1, W, H, " ")
  fullDirty = true
end

--- Fill a rectangle with a character.
-- @param x,y   Top-left position (1-indexed)
-- @param w,h   Width and height
-- @param bg    Background color
-- @param char  Fill character (default " ")
function M.fillRect(x, y, w, h, bg, char)
  if w <= 0 or h <= 0 then return end
  M.setBg(bg)
  gpu.fill(x, y, w, h, char or " ")
  markDirty(x, y, w, h)
end

--- Draw a text string at position.
-- @param x,y  Position (1-indexed)
-- @param text String to draw
-- @param fg   Foreground color
-- @param bg   Background color (optional, keeps current if nil)
function M.drawText(x, y, text, fg, bg)
  if y < 1 or y > H or x > W then return end
  if bg then M.setBg(bg) end
  M.setFg(fg)
  -- Clip text to screen bounds
  if x < 1 then
    text = text:sub(2 - x)
    x = 1
  end
  if x + #text - 1 > W then
    text = text:sub(1, W - x + 1)
  end
  if #text > 0 then
    gpu.set(x, y, text)
    markDirty(x, y, #text, 1)
  end
end

--- Draw a single character at position.
function M.drawChar(x, y, char, fg, bg)
  if x < 1 or x > W or y < 1 or y > H then return end
  if bg then M.setBg(bg) end
  M.setFg(fg)
  gpu.set(x, y, char)
  markDirty(x, y, 1, 1)
end

--- Draw a horizontal line.
function M.drawHLine(x, y, length, char, fg, bg)
  if y < 1 or y > H or length <= 0 then return end
  if bg then M.setBg(bg) end
  M.setFg(fg)
  local str = string.rep(char or "─", length)
  if x + length - 1 > W then
    str = str:sub(1, W - x + 1)
  end
  if x < 1 then
    str = str:sub(2 - x)
    x = 1
  end
  if #str > 0 then
    gpu.set(x, y, str)
    markDirty(x, y, #str, 1)
  end
end

--- Draw a vertical line.
function M.drawVLine(x, y, length, char, fg, bg)
  if x < 1 or x > W or length <= 0 then return end
  if bg then M.setBg(bg) end
  M.setFg(fg)
  char = char or "│"
  for row = y, math.min(y + length - 1, H) do
    if row >= 1 then
      gpu.set(x, row, char)
    end
  end
  markDirty(x, y, 1, length)
end

--- Draw a box border using Unicode box-drawing characters.
-- @param x,y   Top-left
-- @param w,h   Width and height (including border)
-- @param fg    Border color
-- @param bg    Background color
-- @param style "single" (default) or "double" or "round"
function M.drawBorder(x, y, w, h, fg, bg, style)
  if w < 2 or h < 2 then return end
  style = style or "single"

  local tl, tr, bl, br, hz, vt
  if style == "double" then
    tl, tr, bl, br, hz, vt = "╔", "╗", "╚", "╝", "═", "║"
  elseif style == "round" then
    tl, tr, bl, br, hz, vt = "╭", "╮", "╰", "╯", "─", "│"
  else -- single
    tl, tr, bl, br, hz, vt = "┌", "┐", "└", "┘", "─", "│"
  end

  M.setColors(fg, bg)

  -- Top edge
  gpu.set(x, y, tl .. string.rep(hz, w - 2) .. tr)
  -- Bottom edge
  gpu.set(x, y + h - 1, bl .. string.rep(hz, w - 2) .. br)
  -- Left and right edges
  for row = y + 1, y + h - 2 do
    gpu.set(x, row, vt)
    gpu.set(x + w - 1, row, vt)
  end

  markDirty(x, y, w, h)
end

--- Draw a filled rectangle with border.
function M.drawPanel(x, y, w, h, borderFg, bg, style)
  M.fillRect(x, y, w, h, bg)
  M.drawBorder(x, y, w, h, borderFg, bg, style)
end

--- Copy a region (useful for scrolling).
function M.copy(x, y, w, h, dx, dy)
  gpu.copy(x, y, w, h, dx, dy)
  markDirty(x + dx, y + dy, w, h)
end

----------------------------------------------------------------------------
-- Buffer flush (bitblt VRAM → screen)
----------------------------------------------------------------------------

--- Flush the back buffer to the visible screen.
-- Uses bitblt for flicker-free display on T3 GPU.
function M.flush()
  if not hasBuf then return end

  if fullDirty then
    -- Flush entire buffer to screen
    gpu.bitblt(0, 1, 1, W, H, buf, 1, 1)
    fullDirty = false
    dirty = {}
  elseif #dirty > 0 then
    -- Flush only dirty regions
    -- Merge overlapping rects would be ideal but for simplicity,
    -- compute bounding box of all dirty rects
    local minX, minY = W, H
    local maxX, maxY = 1, 1
    for _, r in ipairs(dirty) do
      if r.x < minX then minX = r.x end
      if r.y < minY then minY = r.y end
      local rx = r.x + r.w - 1
      local ry = r.y + r.h - 1
      if rx > maxX then maxX = rx end
      if ry > maxY then maxY = ry end
    end
    local bw = maxX - minX + 1
    local bh = maxY - minY + 1
    if bw > 0 and bh > 0 then
      gpu.bitblt(0, minX, minY, bw, bh, buf, minX, minY)
    end
    dirty = {}
  end
end

--- Switch drawing target back to the buffer (call after flush if needed)
function M.activateBuffer()
  if hasBuf and buf then
    gpu.setActiveBuffer(buf)
  end
end

--- Get raw GPU proxy (for advanced use)
function M.getGPU()
  return gpu
end

--- Free the VRAM buffer (call on shutdown)
function M.destroy()
  if hasBuf and buf then
    gpu.setActiveBuffer(0)
    gpu.freeBuffer(buf)
    buf = nil
    hasBuf = false
  end
end

return M
