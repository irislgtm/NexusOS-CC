-- ============================================================================
-- NEXUS-OS  /apps/terminal.app/Main.lua
-- Full terminal emulator running /bin/sh
-- ============================================================================

return function(window, body, workspace)
  local Widget = require("gui.widget")
  local T      = require("theme")

  local bw, bh = body.width, body.height

  -- Terminal buffer
  local lines = {}
  local maxLines = 200
  local scrollY = 0
  local inputBuf = ""
  local cursorX = 1
  local promptStr = "nexus> "

  local sh
  local hasSh, _sh = pcall(require, "sh")
  if hasSh then sh = _sh end

  local function addLine(text, color)
    lines[#lines + 1] = { text = text or "", color = color or T.get("text_primary") }
    if #lines > maxLines then table.remove(lines, 1) end
    -- Auto-scroll to bottom
    scrollY = math.max(0, #lines - (bh - 1))
  end

  -- Override print for terminal context
  local termPrint = function(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring(select(i, ...))
    end
    addLine(table.concat(parts, "\t"))
  end

  addLine("NEXUS-OS Terminal v1.0", T.get("accent"))
  addLine("Type 'help' for commands.", T.get("text_muted"))
  addLine("")

  -- Terminal widget
  local termWidget = Widget.new(0, 0, bw, bh)
  termWidget.draw = function(self, screen)
    if not self.visible then return end
    local ax, ay = self:absolutePosition()

    screen.fillRect(ax, ay, bw, bh, T.get("desktop_bg"))

    -- Draw visible lines
    for row = 1, bh - 1 do
      local lineIdx = row + scrollY
      if lineIdx <= #lines then
        local line = lines[lineIdx]
        screen.drawText(ax, ay + row - 1, line.text:sub(1, bw),
          line.color, T.get("desktop_bg"))
      end
    end

    -- Draw input line at bottom
    local inputLine = promptStr .. inputBuf
    screen.drawText(ax, ay + bh - 1, inputLine:sub(1, bw),
      T.get("text_bright"), T.get("desktop_bg"))

    -- Cursor
    local cx = ax + #promptStr + cursorX - 1
    if cx < ax + bw then
      screen.drawChar(cx, ay + bh - 1, "_", T.get("accent"), T.get("desktop_bg"))
    end
  end

  termWidget.eventHandler = function(self, ws, eName, ...)
    if eName == "key_down" then
      local _, _, char, code = ...
      if code == 28 then -- Enter
        addLine(promptStr .. inputBuf, T.get("text_bright"))
        -- Execute command
        if sh and #inputBuf > 0 then
          local oldPrint = _G.print
          _G.print = termPrint
          local result = sh.execute(inputBuf)
          _G.print = oldPrint
          if result == "EXIT" then
            addLine("Shell exited.", T.get("text_muted"))
          end
        end
        inputBuf = ""
        cursorX = 1
        scrollY = math.max(0, #lines - (bh - 1))
        self:invalidate()
        return true
      elseif code == 14 then -- Backspace
        if cursorX > 1 then
          inputBuf = inputBuf:sub(1, cursorX - 2) .. inputBuf:sub(cursorX)
          cursorX = cursorX - 1
          self:invalidate()
        end
        return true
      elseif code == 211 then -- Delete
        if cursorX <= #inputBuf then
          inputBuf = inputBuf:sub(1, cursorX - 1) .. inputBuf:sub(cursorX + 1)
          self:invalidate()
        end
        return true
      elseif code == 203 then -- Left
        cursorX = math.max(1, cursorX - 1)
        self:invalidate()
        return true
      elseif code == 205 then -- Right
        cursorX = math.min(#inputBuf + 1, cursorX + 1)
        self:invalidate()
        return true
      elseif code == 199 then -- Home
        cursorX = 1
        self:invalidate()
        return true
      elseif code == 207 then -- End
        cursorX = #inputBuf + 1
        self:invalidate()
        return true
      elseif code == 201 then -- PgUp
        scrollY = math.max(0, scrollY - (bh - 2))
        self:invalidate()
        return true
      elseif code == 209 then -- PgDn
        scrollY = math.min(math.max(0, #lines - (bh - 1)), scrollY + (bh - 2))
        self:invalidate()
        return true
      elseif char and char >= 32 and char < 127 then
        inputBuf = inputBuf:sub(1, cursorX - 1) .. string.char(char) .. inputBuf:sub(cursorX)
        cursorX = cursorX + 1
        self:invalidate()
        return true
      end
    elseif eName == "scroll" then
      local _, _, _, _, dir = ...
      scrollY = scrollY - (dir or 0)
      scrollY = math.max(0, math.min(math.max(0, #lines - (bh - 1)), scrollY))
      self:invalidate()
      return true
    end
    return false
  end

  body:addChild(termWidget)
end
