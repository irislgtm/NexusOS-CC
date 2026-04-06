-- ============================================================================
-- NEXUS-OS  /apps/settings.app/Main.lua
-- Settings: theme picker, component list, system info
-- ============================================================================

return function(window, body, workspace)
  local TabBar   = require("gui.tabbar")
  local Button   = require("gui.button")
  local ListView = require("gui.listview")
  local Widget   = require("gui.widget")
  local T        = require("theme")
  local config   = require("config")

  local bw, bh = body.width, body.height

  local tabs = TabBar.new(0, 0, bw, { "Theme", "Components", "System" })
  body:addChild(tabs)

  -- ── Theme Tab ─────────────────────────────────────────────────────────
  local themePanel = Widget.new(0, 2, bw, bh - 4)
  themePanel.draw = function(self, screen)
    if not self.visible then return end
    local ax, ay = self:absolutePosition()
    screen.drawText(ax + 2, ay, "Select Color Scheme:", T.get("text_primary"), T.get("window_bg"))
    screen.drawText(ax + 2, ay + 2, "Current: " .. (T.currentScheme or "matrix"),
      T.get("accent"), T.get("window_bg"))

    -- Color preview
    local previewY = ay + 5
    local colors = {
      "desktop_bg", "window_bg", "titlebar_bg", "accent",
      "text_primary", "text_secondary", "text_bright",
      "alert_ok", "alert_warn", "alert_critical",
    }
    for i, key in ipairs(colors) do
      local c = T.get(key)
      screen.fillRect(ax + 2, previewY + i - 1, 3, 1, c)
      screen.drawText(ax + 6, previewY + i - 1, key, T.get("text_muted"), T.get("window_bg"))
    end
  end
  body:addChild(themePanel)

  -- Theme buttons
  local themes = { "matrix", "phantom", "ember" }
  for i, name in ipairs(themes) do
    local btn = Button.new(2, 4 + (i - 1) * 2, 14, 1, " " .. name .. " ", function()
      T.setScheme(name)
      body:invalidate()
    end)
    themePanel:addChild(btn)
  end

  -- ── Components Tab ────────────────────────────────────────────────────
  local compList = ListView.new(0, 2, bw, bh - 4, {
    { name = "Type",    width = 20 },
    { name = "Address", width = 40 },
  })
  compList.visible = false
  body:addChild(compList)

  local function refreshComponents()
    local rows = {}
    for addr, ctype in component.list() do
      rows[#rows + 1] = { ctype, addr }
    end
    table.sort(rows, function(a, b) return a[1] < b[1] end)
    compList:setData(rows)
  end

  -- ── System Tab ────────────────────────────────────────────────────────
  local sysPanel = Widget.new(0, 2, bw, bh - 4)
  sysPanel.visible = false
  sysPanel.draw = function(self, screen)
    if not self.visible then return end
    local ax, ay = self:absolutePosition()
    local row = ay

    local function stat(label, value)
      screen.drawText(ax + 2, row, label .. ":", T.get("text_secondary"), T.get("window_bg"))
      screen.drawText(ax + 22, row, value, T.get("text_primary"), T.get("window_bg"))
      row = row + 1
    end

    screen.drawText(ax + 2, row, "═══ System Information ═══", T.get("accent"), T.get("window_bg"))
    row = row + 2

    stat("OS Version", "NEXUS-OS v1.0")
    stat("Uptime", string.format("%.1f seconds", computer.uptime()))
    stat("Total RAM", math.floor(computer.totalMemory() / 1024) .. " KB")
    stat("Free RAM", math.floor(computer.freeMemory() / 1024) .. " KB")
    stat("Used RAM", math.floor((computer.totalMemory() - computer.freeMemory()) / 1024) .. " KB")

    row = row + 1
    local gpu = _G.hw and _G.hw.find("gpu")
    if gpu then
      local gw, gh = gpu.getResolution()
      stat("Resolution", gw .. "x" .. gh)
      stat("Color Depth", tostring(2 ^ gpu.getDepth()) .. " colors")
      stat("VRAM Total", gpu.totalMemory and math.floor(gpu.totalMemory() / 1024) .. " KB" or "N/A")
      stat("VRAM Free", gpu.freeMemory and math.floor(gpu.freeMemory() / 1024) .. " KB" or "N/A")
    end

    row = row + 1
    stat("Computer Addr", computer.address():sub(1, 36))
    stat("Boot Address", computer.getBootAddress():sub(1, 36))

    if _G.scheduler then
      row = row + 1
      stat("Processes", tostring(_G.scheduler.count()))
    end
  end
  body:addChild(sysPanel)

  -- Tab switching
  tabs.onTabChanged = function(idx)
    themePanel.visible = (idx == 1)
    compList.visible   = (idx == 2)
    sysPanel.visible   = (idx == 3)
    if idx == 2 then refreshComponents() end
    body:invalidate()
  end

  -- Header
  local header = Widget.new(0, 0, bw, 1)
  header.draw = function(self, screen)
    local ax, ay = self:absolutePosition()
    screen.drawText(ax, ay, "⚙ SETTINGS", T.get("accent"), T.get("window_bg"))
  end
  body:addChild(header)
end
