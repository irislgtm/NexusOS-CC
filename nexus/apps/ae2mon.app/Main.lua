-- ============================================================================
-- NEXUS-OS  /apps/ae2mon.app/Main.lua
-- AE2 Network Monitor: storage, power, crafting jobs, item search
-- ============================================================================

return function(window, body, workspace)
  local ListView  = require("gui.listview")
  local TabBar    = require("gui.tabbar")
  local Progress  = require("gui.progress")
  local Chart     = require("gui.chart")
  local Button    = require("gui.button")
  local TextField = require("gui.textfield")
  local Widget    = require("gui.widget")
  local T         = require("theme")

  local ae2
  local hasAE2, _a = pcall(require, "ae2")
  if hasAE2 then ae2 = _a end

  local bw, bh = body.width, body.height

  -- Tabs
  local tabs = TabBar.new(0, 0, bw, { "Overview", "Items", "Crafting" })
  body:addChild(tabs)

  -- ── Overview Tab ──────────────────────────────────────────────────────
  local overviewPanel = Widget.new(0, 2, bw, bh - 4)
  overviewPanel.draw = function(self, screen)
    if not self.visible then return end
    local ax, ay = self:absolutePosition()

    if not ae2 or not ae2.isAvailable() then
      screen.drawText(ax + 2, ay + 2, "No AE2 controller detected.",
        T.get("alert_critical"), T.get("window_bg"))
      screen.drawText(ax + 2, ay + 3, "Connect ME Controller or Interface via Adapter block.",
        T.get("text_muted"), T.get("window_bg"))
      return
    end

    local info = ae2.getStorageSummary()

    screen.drawText(ax + 2, ay + 1, "═══ Storage ═══", T.get("accent"), T.get("window_bg"))
    screen.drawText(ax + 2, ay + 2, "Item Types:  " .. tostring(info.types),
      T.get("text_primary"), T.get("window_bg"))
    screen.drawText(ax + 2, ay + 3, "Total Items: " .. tostring(info.totalItems),
      T.get("text_primary"), T.get("window_bg"))

    screen.drawText(ax + 2, ay + 5, "═══ Power ═══", T.get("accent"), T.get("window_bg"))
    screen.drawText(ax + 2, ay + 6, string.format("Stored:  %.0f / %.0f AE",
      info.energy, info.maxEnergy), T.get("text_primary"), T.get("window_bg"))
    screen.drawText(ax + 2, ay + 7, string.format("Usage:   %.1f AE/t", info.avgPower),
      T.get("text_primary"), T.get("window_bg"))

    -- CPUs
    local cpus = ae2.getCpus()
    screen.drawText(ax + 2, ay + 9, "═══ Crafting CPUs ═══", T.get("accent"), T.get("window_bg"))
    screen.drawText(ax + 2, ay + 10, "Active CPUs: " .. #cpus,
      T.get("text_primary"), T.get("window_bg"))
  end
  body:addChild(overviewPanel)

  -- Power progress bar
  local powerBar = Progress.new(2, bh - 5, bw - 4, 0)
  body:addChild(powerBar)

  -- Power history chart
  local powerChart = Chart.new(2, bh - 10, bw - 4, 4, "sparkline")
  powerChart.label = "Power"
  body:addChild(powerChart)

  -- ── Items Tab ─────────────────────────────────────────────────────────
  local searchField = TextField.new(0, 2, bw - 12, "Search items...")
  searchField.visible = false
  body:addChild(searchField)

  local searchBtn = Button.new(bw - 10, 2, 10, 1, " Search ", function()
    if not ae2 then return end
    local results = ae2.searchItems(searchField.text)
    local rows = {}
    for _, item in ipairs(results) do
      rows[#rows + 1] = {
        item.label or item.name or "?",
        tostring(item.size or 0),
        item.isCraftable and "Yes" or "No",
      }
    end
    table.sort(rows, function(a, b) return tonumber(a[2]) > tonumber(b[2]) end)
    itemList:setData(rows)
    body:invalidate()
  end)
  searchBtn.visible = false
  body:addChild(searchBtn)

  local itemList = ListView.new(0, 4, bw, bh - 8, {
    { name = "Item",      width = bw - 22 },
    { name = "Count",     width = 10 },
    { name = "Craftable", width = 8 },
  })
  itemList.visible = false
  body:addChild(itemList)

  -- ── Crafting Tab ──────────────────────────────────────────────────────
  local craftList = ListView.new(0, 2, bw, bh - 4, {
    { name = "CPU",     width = 10 },
    { name = "Busy",    width = 6 },
    { name = "Storage", width = 10 },
    { name = "Coprocessors", width = 12 },
  })
  craftList.visible = false
  body:addChild(craftList)

  -- Tab switching
  tabs.onTabChanged = function(idx)
    overviewPanel.visible = (idx == 1)
    powerBar.visible      = (idx == 1)
    powerChart.visible    = (idx == 1)
    searchField.visible   = (idx == 2)
    searchBtn.visible     = (idx == 2)
    itemList.visible      = (idx == 2)
    craftList.visible     = (idx == 3)
    body:invalidate()
  end

  -- ── Refresh ───────────────────────────────────────────────────────────
  local function refresh()
    if not ae2 or not ae2.isAvailable() then return end

    -- Power bar
    local pct = ae2.getEnergyPercent()
    powerBar:setValue(pct / 100)

    -- Power chart history
    powerChart:pushValue(ae2.getStoredPower() / math.max(1, ae2.getMaxStoredPower()) * 100)

    -- CPU list
    local cpus = ae2.getCpus()
    local cpuRows = {}
    for i, cpu in ipairs(cpus) do
      cpuRows[i] = {
        "CPU " .. i,
        cpu.busy and "Yes" or "No",
        tostring(cpu.storage or 0),
        tostring(cpu.coprocessors or 0),
      }
    end
    craftList:setData(cpuRows)

    body:invalidate()
  end

  if _G.event then
    _G.event.timer(2, refresh, math.huge)
  end

  -- Header
  local header = Widget.new(0, 0, bw, 1)
  header.draw = function(self, screen)
    local ax, ay = self:absolutePosition()
    screen.drawText(ax, ay, "▣ AE2 NETWORK MONITOR", T.get("accent"), T.get("window_bg"))
    local status = ae2 and ae2.isAvailable() and "CONNECTED" or "OFFLINE"
    local sColor = ae2 and ae2.isAvailable() and T.get("alert_ok") or T.get("alert_critical")
    screen.drawText(ax + 25, ay, status, sColor, T.get("window_bg"))
  end
  body:addChild(header)

  refresh()
end
