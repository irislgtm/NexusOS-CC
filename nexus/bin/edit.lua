-- ============================================================================
-- NEXUS-OS  /bin/edit.lua — Simple text editor
-- ============================================================================

local args = { ... }
local path = args[1]

if not path then
  print("Usage: edit <file>")
  return
end

local gpu = _G.hw and _G.hw.find("gpu")
if not gpu then
  print("edit: no GPU available")
  return
end

local w, h = gpu.getResolution()

-- Load file content
local lines = { "" }
if _G._fs and _G._fs.exists(path) then
  local data = _G._fs.read(path)
  if data then
    lines = {}
    for line in (data .. "\n"):gmatch("([^\n]*)\n") do
      lines[#lines + 1] = line
    end
    if #lines == 0 then lines = { "" } end
  end
end

local cursorX, cursorY = 1, 1
local scrollX, scrollY = 0, 0
local statusMsg = "Ctrl+S: Save  Ctrl+Q: Quit"
local dirty = false

local function clamp()
  cursorY = math.max(1, math.min(#lines, cursorY))
  cursorX = math.max(1, math.min(#lines[cursorY] + 1, cursorX))
end

local function render()
  -- Status bar
  gpu.setBackground(0x333333)
  gpu.setForeground(0x00FF00)
  gpu.fill(1, 1, w, 1, " ")
  gpu.set(1, 1, " EDIT: " .. path .. (dirty and " [*]" or ""))
  gpu.set(w - #statusMsg, 1, statusMsg)

  -- Content area
  gpu.setBackground(0x0D0D0D)
  gpu.setForeground(0xCCCCCC)
  gpu.fill(1, 2, w, h - 2, " ")

  for screenRow = 1, h - 2 do
    local lineIdx = screenRow + scrollY
    if lineIdx <= #lines then
      local line = lines[lineIdx]
      local visible = line:sub(scrollX + 1, scrollX + w)
      gpu.set(1, screenRow + 1, visible)
    end
  end

  -- Line number / position bar
  gpu.setBackground(0x333333)
  gpu.setForeground(0x999999)
  gpu.fill(1, h, w, 1, " ")
  gpu.set(1, h, string.format(" Ln %d, Col %d  |  %d lines", cursorY, cursorX, #lines))
end

-- Main loop
render()
while true do
  local sig = table.pack(coroutine.yield())
  if sig[1] == "key_down" then
    local char, code = sig[3], sig[4]
    local ctrl = false
    -- Check ctrl state via keyboard driver if available
    local kb = package.loaded and package.loaded.keyboard
    if kb and kb.isCtrl then ctrl = kb.isCtrl() end

    if ctrl and (code == 31) then  -- Ctrl+S
      -- Save
      if _G._fs then
        _G._fs.write(path, table.concat(lines, "\n"))
        dirty = false
        statusMsg = "Saved!"
      end
    elseif ctrl and (code == 16) then  -- Ctrl+Q
      -- Quit
      break
    elseif code == 28 then  -- Enter
      local before = lines[cursorY]:sub(1, cursorX - 1)
      local after  = lines[cursorY]:sub(cursorX)
      lines[cursorY] = before
      table.insert(lines, cursorY + 1, after)
      cursorY = cursorY + 1
      cursorX = 1
      dirty = true
    elseif code == 14 then  -- Backspace
      if cursorX > 1 then
        lines[cursorY] = lines[cursorY]:sub(1, cursorX - 2) .. lines[cursorY]:sub(cursorX)
        cursorX = cursorX - 1
        dirty = true
      elseif cursorY > 1 then
        cursorX = #lines[cursorY - 1] + 1
        lines[cursorY - 1] = lines[cursorY - 1] .. lines[cursorY]
        table.remove(lines, cursorY)
        cursorY = cursorY - 1
        dirty = true
      end
    elseif code == 211 then  -- Delete
      if cursorX <= #lines[cursorY] then
        lines[cursorY] = lines[cursorY]:sub(1, cursorX - 1) .. lines[cursorY]:sub(cursorX + 1)
        dirty = true
      elseif cursorY < #lines then
        lines[cursorY] = lines[cursorY] .. lines[cursorY + 1]
        table.remove(lines, cursorY + 1)
        dirty = true
      end
    elseif code == 200 then cursorY = cursorY - 1     -- Up
    elseif code == 208 then cursorY = cursorY + 1     -- Down
    elseif code == 203 then cursorX = cursorX - 1     -- Left
    elseif code == 205 then cursorX = cursorX + 1     -- Right
    elseif code == 199 then cursorX = 1               -- Home
    elseif code == 207 then cursorX = #lines[cursorY] + 1 -- End
    elseif code == 201 then cursorY = cursorY - (h - 3)   -- PgUp
    elseif code == 209 then cursorY = cursorY + (h - 3)   -- PgDn
    elseif char and char >= 32 and char < 127 then
      lines[cursorY] = lines[cursorY]:sub(1, cursorX - 1) ..
        string.char(char) .. lines[cursorY]:sub(cursorX)
      cursorX = cursorX + 1
      dirty = true
    end

    clamp()
    -- Scroll to follow cursor
    if cursorY - scrollY > h - 2 then scrollY = cursorY - h + 2 end
    if cursorY - scrollY < 1 then scrollY = cursorY - 1 end
    render()
  end
end

-- Cleanup
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
gpu.fill(1, 1, w, h, " ")
