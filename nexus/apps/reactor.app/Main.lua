-- ============================================================================
-- NEXUS-OS  /apps/reactor.app/Main.lua
-- Multi-Reactor Monitor: Big Reactors, IC2, Mekanism, Draconic
-- ============================================================================

return function(window, body, workspace)
  local TabBar   = require("gui.tabbar")
  local Progress = require("gui.progress")
  local Chart    = require("gui.chart")
  local Button   = require("gui.button")
  local Widget   = require("gui.widget")
  local T        = require("theme")

  -- Try loading all reactor drivers
  local br, ic2, mek, drac
  local hasBR,  _br  = pcall(require, "bigreactors"); if hasBR  then br  = _br  end
  local hasIC2, _ic2 = pcall(require, "ic2");         if hasIC2 then ic2 = _ic2 end
  local hasMek, _mek = pcall(require, "mekanism");    if hasMek then mek = _mek end
  local hasDr,  _dr  = pcall(require, "draconic");    if hasDr  then drac = _dr  end

  local bw, bh = body.width, body.height

  -- Detect available reactors
  local availTabs = {}
  if br   and br.hasReactor()     then availTabs[#availTabs + 1] = "Big Reactor" end
  if br   and br.hasTurbine()     then availTabs[#availTabs + 1] = "BR Turbine"  end
  if ic2  and ic2.hasReactor()    then availTabs[#availTabs + 1] = "IC2 Reactor" end
  if drac and drac.hasReactor()   then availTabs[#availTabs + 1] = "Draconic"    end
  if mek  and mek.hasInductionMatrix() then availTabs[#availTabs + 1] = "Mek Matrix" end
  if #availTabs == 0 then availTabs = { "No Reactors" } end

  local tabs = TabBar.new(0, 0, bw, availTabs)
  body:addChild(tabs)

  -- ── Generic reactor display panel ─────────────────────────────────────
  local infoPanel = Widget.new(0, 2, bw, bh - 4)
  local currentData = {}

  infoPanel.draw = function(self, screen)
    if not self.visible then return end
    local ax, ay = self:absolutePosition()
    local row = ay

    for _, entry in ipairs(currentData) do
      if entry.type == "header" then
        screen.drawText(ax + 2, row, entry.text, T.get("accent"), T.get("window_bg"))
      elseif entry.type == "stat" then
        screen.drawText(ax + 2, row, entry.label .. ":", T.get("text_secondary"), T.get("window_bg"))
        local valColor = entry.color or T.get("text_primary")
        screen.drawText(ax + 22, row, entry.value, valColor, T.get("window_bg"))
      elseif entry.type == "separator" then
        screen.drawHLine(ax + 2, row, bw - 4, "─", T.get("border_dim"), T.get("window_bg"))
      end
      row = row + 1
    end
  end
  body:addChild(infoPanel)

  -- Energy bar
  local energyBar = Progress.new(2, bh - 4, bw - 4, 0)
  body:addChild(energyBar)

  -- Energy history
  local energyChart = Chart.new(2, bh - 9, bw - 4, 4, "sparkline")
  energyChart.label = "Energy"
  body:addChild(energyChart)

  -- Control buttons
  local toggleBtn = Button.new(2, bh - 2, 14, 1, " Toggle On/Off", function()
    local tabName = availTabs[tabs.activeTab or 1]
    if tabName == "Big Reactor" and br then
      br.setReactorActive(not br.getReactorActive())
    elseif tabName == "BR Turbine" and br then
      br.setTurbineActive(not br.getTurbineActive())
    elseif tabName == "Draconic" and drac then
      -- Toggle not straightforward for draconic
    end
  end)
  body:addChild(toggleBtn)

  -- ── Refresh function ──────────────────────────────────────────────────
  local function refresh()
    currentData = {}
    local tabName = availTabs[tabs.activeTab or 1]

    if tabName == "Big Reactor" and br then
      local info = br.getReactorInfo()
      currentData = {
        { type = "header", text = "═══ Big Reactor ═══" },
        { type = "stat", label = "Status", value = info.active and "ACTIVE" or "INACTIVE",
          color = info.active and T.get("alert_ok") or T.get("alert_critical") },
        { type = "stat", label = "Energy Stored", value = string.format("%.0f RF", info.energy) },
        { type = "stat", label = "RF/t Produced", value = string.format("%.1f", info.produced) },
        { type = "separator" },
        { type = "stat", label = "Fuel Temp", value = string.format("%.0f°C", info.fuelTemp),
          color = info.fuelTemp > 1000 and T.get("alert_warn") or T.get("text_primary") },
        { type = "stat", label = "Casing Temp", value = string.format("%.0f°C", info.casingTemp) },
        { type = "stat", label = "Fuel Level", value = string.format("%.1f%%", info.fuelPct) },
        { type = "stat", label = "Consumed/t", value = string.format("%.3f mB", info.consumed) },
        { type = "stat", label = "Waste", value = string.format("%.0f mB", info.waste) },
        { type = "stat", label = "Control Rods", value = tostring(info.rods) },
      }
      energyBar:setValue(info.energy / 10000000)
      energyChart:pushValue(info.produced)

    elseif tabName == "BR Turbine" and br then
      local info = br.getTurbineInfo()
      currentData = {
        { type = "header", text = "═══ Big Reactor Turbine ═══" },
        { type = "stat", label = "Status", value = info.active and "ACTIVE" or "INACTIVE",
          color = info.active and T.get("alert_ok") or T.get("alert_critical") },
        { type = "stat", label = "Rotor Speed", value = string.format("%.0f RPM", info.rpm),
          color = (info.rpm > 1800 and info.rpm < 1820) and T.get("alert_ok") or T.get("alert_warn") },
        { type = "stat", label = "RF/t Produced", value = string.format("%.1f", info.produced) },
        { type = "stat", label = "Flow Rate", value = string.format("%.0f / %.0f mB/t", info.flow, info.flowMax) },
        { type = "stat", label = "Energy Stored", value = string.format("%.0f RF", info.energy) },
      }
      energyBar:setValue(info.energy / 1000000)
      energyChart:pushValue(info.rpm)

    elseif tabName == "IC2 Reactor" and ic2 then
      local info = ic2.getReactorInfo()
      currentData = {
        { type = "header", text = "═══ IC2 Nuclear Reactor ═══" },
        { type = "stat", label = "Status", value = info.active and "ACTIVE" or "INACTIVE",
          color = info.active and T.get("alert_ok") or T.get("alert_critical") },
        { type = "stat", label = "Heat", value = string.format("%.0f / %.0f (%.1f%%)",
          info.heat, info.maxHeat, info.heatPct),
          color = info.heatPct > 70 and T.get("alert_critical") or T.get("text_primary") },
        { type = "stat", label = "EU Output", value = string.format("%.0f EU/t", info.euOut) },
      }
      energyBar:setValue(1 - info.heatPct / 100)

    elseif tabName == "Draconic" and drac then
      local info = drac.getReactorInfo()
      if info then
        currentData = {
          { type = "header", text = "═══ Draconic Reactor ═══" },
          { type = "stat", label = "Status", value = tostring(info.status or "unknown") },
          { type = "stat", label = "Temperature", value = string.format("%.0f°C", info.temperature or 0),
            color = (info.temperature or 0) > 7000 and T.get("alert_critical") or T.get("text_primary") },
          { type = "stat", label = "Field Strength", value = string.format("%.0f / %.0f",
            info.fieldStrength or 0, info.maxFieldStrength or 0) },
          { type = "stat", label = "Saturation", value = string.format("%.0f / %.0f",
            info.saturation or 0, info.maxSaturation or 0) },
          { type = "stat", label = "Generation", value = string.format("%.0f RF/t",
            info.generationRate or 0) },
          { type = "stat", label = "Fuel", value = string.format("%.2f%%",
            (info.fuelConversion or 0) / math.max(1, info.maxFuelConversion or 1) * 100) },
        }
        local fs = (info.fieldStrength or 0) / math.max(1, info.maxFieldStrength or 1)
        energyBar:setValue(fs)
        energyChart:pushValue(info.generationRate or 0)
      end

    elseif tabName == "Mek Matrix" and mek then
      local info = mek.getInductionInfo()
      if info then
        currentData = {
          { type = "header", text = "═══ Mekanism Induction Matrix ═══" },
          { type = "stat", label = "Stored", value = string.format("%.0f / %.0f J",
            info.stored, info.capacity) },
          { type = "stat", label = "Input", value = string.format("%.0f J/t", info.input) },
          { type = "stat", label = "Output", value = string.format("%.0f J/t", info.output) },
          { type = "stat", label = "Fill", value = string.format("%.2f%%",
            info.stored / math.max(1, info.capacity) * 100) },
        }
        energyBar:setValue(info.stored / math.max(1, info.capacity))
        energyChart:pushValue(info.input)
      end

    else
      currentData = {
        { type = "header", text = "No reactor hardware detected." },
        { type = "stat", label = "Tip", value = "Connect reactor via OC Adapter block." },
      }
    end

    body:invalidate()
  end

  if _G.event then
    _G.event.timer(2, refresh, math.huge)
  end

  -- Header
  local header = Widget.new(0, 0, bw, 1)
  header.draw = function(self, screen)
    local ax, ay = self:absolutePosition()
    screen.drawText(ax, ay, "☢ REACTOR CONTROL", T.get("accent"), T.get("window_bg"))
  end
  body:addChild(header)

  refresh()
end
