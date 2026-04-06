-- ============================================================================
-- NEXUS-OS  /apps/mapper.app/Main.lua
-- Geolyzer Map: 2D top-down terrain view, ore highlighting, Y-layer nav
-- ============================================================================

return function(window, body, workspace)
  local Widget   = require("gui.widget")
  local Button   = require("gui.button")
  local Screen   = require("gui.screen")
  local T        = require("theme")

  local geolyzer
  local hasGeo, _g = pcall(require, "geolyzer")
  if hasGeo then geolyzer = _g end

  local bw, bh = body.width, body.height

  -- Map state
  local yLevel = 0       -- relative Y offset
  local radius = 5
  local scanData = {}    -- [x][z] = hardness
  local scanning = false

  -- Hardness → color mapping
  local function blockColor(h)
    if h <= 0 then return T.get("desktop_bg") end
    if h < 0.5 then return 0x553300 end      -- dirt/sand
    if h < 1.5 then return 0x666666 end      -- stone
    if h < 3.0 then return 0x888888 end      -- harder stone
    if h < 5.0 then return 0x00CCFF end      -- ore range
    if h < 50  then return 0xFFFF00 end      -- very hard
    return 0xAA00AA                            -- obsidian+
  end

  -- Characters for density
  local function blockChar(h)
    if h <= 0 then return " " end
    if h < 0.5 then return "░" end
    if h < 1.5 then return "▒" end
    if h < 3.0 then return "▓" end
    return "█"
  end

  -- Map widget
  local mapWidget = Widget.new(0, 3, bw - 12, bh - 4)
  mapWidget.draw = function(self, screen)
    if not self.visible then return end
    local ax, ay = self:absolutePosition()
    local mw, mh = self.width, self.height

    screen.fillRect(ax, ay, mw, mh, T.get("desktop_bg"))

    local cx = math.floor(mw / 2)
    local cy = math.floor(mh / 2)

    -- Draw scanned blocks
    for x = -radius, radius do
      if scanData[x] then
        for z = -radius, radius do
          local h = scanData[x][z]
          if h then
            local px = ax + cx + x
            local py = ay + cy + z
            if px >= ax and px < ax + mw and py >= ay and py < ay + mh then
              local color = blockColor(h)
              local ch = blockChar(h)
              screen.drawChar(px, py, ch, color, T.get("desktop_bg"))
            end
          end
        end
      end
    end

    -- Center marker (geolyzer position)
    screen.drawChar(ax + cx, ay + cy, "+", T.get("text_bright"), T.get("desktop_bg"))

    -- Grid label
    screen.drawText(ax, ay + mh - 1,
      "Y=" .. tostring(yLevel) .. " R=" .. tostring(radius),
      T.get("text_muted"), T.get("desktop_bg"))
  end
  body:addChild(mapWidget)

  -- Controls sidebar
  local ctrlX = bw - 11

  -- Y level controls
  local yLabel = Widget.new(ctrlX, 3, 10, 1)
  yLabel.draw = function(self, screen)
    local ax, ay = self:absolutePosition()
    screen.drawText(ax, ay, "Y: " .. tostring(yLevel), T.get("text_primary"), T.get("window_bg"))
  end
  body:addChild(yLabel)

  local yUp = Button.new(ctrlX, 5, 10, 1, "   ▲ Up  ", function()
    yLevel = yLevel + 1
    body:invalidate()
  end)
  body:addChild(yUp)

  local yDown = Button.new(ctrlX, 7, 10, 1, "  ▼ Down ", function()
    yLevel = yLevel - 1
    body:invalidate()
  end)
  body:addChild(yDown)

  -- Scan button
  local scanBtn = Button.new(ctrlX, 10, 10, 1, " ◎ Scan  ", function()
    if scanning then return end
    if not geolyzer or not geolyzer.isAvailable() then return end
    scanning = true
    scanBtn.text = " Scanning"
    body:invalidate()

    -- Perform scan in current process
    local grid, err = geolyzer.scanLayer(yLevel, radius)
    if grid then
      scanData = grid
    end
    scanning = false
    scanBtn.text = " ◎ Scan  "
    body:invalidate()
  end)
  body:addChild(scanBtn)

  -- Radius controls
  local rUp = Button.new(ctrlX, 13, 10, 1, " R+ (max8)", function()
    radius = math.min(8, radius + 1)
    body:invalidate()
  end)
  body:addChild(rUp)

  local rDown = Button.new(ctrlX, 15, 10, 1, " R- (min2)", function()
    radius = math.max(2, radius - 1)
    body:invalidate()
  end)
  body:addChild(rDown)

  -- Save/Load
  local saveBtn = Button.new(ctrlX, 18, 10, 1, "  Save   ", function()
    if _G._fs and next(scanData) then
      local serial = require("serial")
      local data = serial.serialize({ y = yLevel, r = radius, map = scanData })
      local name = "scan_y" .. tostring(yLevel) .. ".dat"
      _G._fs.write("/var/maps/" .. name, data)
    end
  end)
  body:addChild(saveBtn)

  -- Ore legend
  local legendY = 21
  local legends = {
    { "░ Soft",    0x553300 },
    { "▒ Stone",   0x666666 },
    { "▓ Hard",    0x888888 },
    { "█ Ore",     0x00CCFF },
    { "█ Dense",   0xFFFF00 },
  }
  for _, leg in ipairs(legends) do
    local lw = Widget.new(ctrlX, legendY, 10, 1)
    local legText, legColor = leg[1], leg[2]
    lw.draw = function(self, screen)
      local ax, ay = self:absolutePosition()
      screen.drawText(ax, ay, legText, legColor, T.get("window_bg"))
    end
    body:addChild(lw)
    legendY = legendY + 1
  end

  -- Header info
  local header = Widget.new(0, 0, bw, 2)
  header.draw = function(self, screen)
    local ax, ay = self:absolutePosition()
    screen.drawText(ax, ay, "▦ GEOLYZER MAP", T.get("accent"), T.get("window_bg"))
    local status = geolyzer and geolyzer.isAvailable() and "ONLINE" or "NO SENSOR"
    local statusColor = geolyzer and geolyzer.isAvailable() and T.get("alert_ok") or T.get("alert_critical")
    screen.drawText(ax + 20, ay, status, statusColor, T.get("window_bg"))
  end
  body:addChild(header)
end
