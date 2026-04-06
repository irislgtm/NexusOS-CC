-- ============================================================================
-- NEXUS-OS  /lib/gui/chart.lua
-- Sparkline / bar chart widget for live data visualization
-- ============================================================================

local Widget = require("gui.widget")
local Screen = require("gui.screen")
local T      = require("theme")

local Chart = setmetatable({}, {__index = Widget})
Chart.__index = Chart

--- Create a chart.
-- @param x,y     Position
-- @param w,h     Size
-- @param ctype   "sparkline" or "bar"
function Chart.new(x, y, w, h, ctype)
  local self = Widget.new(x, y, w, h)
  setmetatable(self, Chart)
  self.chartType  = ctype or "sparkline"
  self.values     = {}
  self.maxValues  = w      -- max data points to retain
  self.minVal     = nil    -- nil = auto-scale
  self.maxVal     = nil
  self.label      = nil    -- top-left label
  self.unit       = ""     -- unit suffix for values
  self.lineColor  = nil    -- override theme
  self.fillColor  = nil
  return self
end

--- Push a new data point.
function Chart:pushValue(v)
  self.values[#self.values + 1] = v
  while #self.values > self.maxValues do
    table.remove(self.values, 1)
  end
  self:invalidate()
end

--- Set all values at once.
function Chart:setValues(vals)
  self.values = vals or {}
  self:invalidate()
end

--- Get current min/max of data.
local function autoRange(values, fixedMin, fixedMax)
  if #values == 0 then return 0, 1 end
  local lo, hi = math.huge, -math.huge
  for _, v in ipairs(values) do
    if v < lo then lo = v end
    if v > hi then hi = v end
  end
  lo = fixedMin or lo
  hi = fixedMax or hi
  if lo == hi then hi = lo + 1 end
  return lo, hi
end

-- Unicode block characters for sub-cell resolution (8 levels)
local BLOCKS = { " ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }

function Chart:draw(screen)
  if not self.visible then return end
  local ax, ay = self:absolutePosition()
  local w, h = self.width, self.height

  -- Background
  screen.fillRect(ax, ay, w, h, T.get("chart_bg"))

  -- Grid lines
  local gridColor = T.get("chart_grid")
  for row = 1, h - 1 do
    if row % 2 == 0 then
      screen.drawHLine(ax, ay + row, w, "·", gridColor, T.get("chart_bg"))
    end
  end

  local lo, hi = autoRange(self.values, self.minVal, self.maxVal)
  local lineColor = self.lineColor or T.get("chart_line")
  local fillColor = self.fillColor or T.get("chart_fill")

  if self.chartType == "bar" then
    local barW = math.max(1, math.floor(w / math.max(1, #self.values)))
    for i, v in ipairs(self.values) do
      local ratio = (v - lo) / (hi - lo)
      local barH = math.max(0, math.floor(ratio * h))
      local bx = ax + (i - 1) * barW
      if bx + barW > ax + w then break end
      if barH > 0 then
        screen.fillRect(bx, ay + h - barH, barW, barH, T.get("chart_bar"))
      end
    end
  else -- sparkline
    -- Draw with sub-cell resolution using block chars
    local dataW = math.min(w, #self.values)
    local startIdx = #self.values - dataW + 1
    for col = 0, dataW - 1 do
      local v = self.values[startIdx + col]
      local ratio = (v - lo) / (hi - lo)
      local cellHeight = ratio * h
      local fullCells = math.floor(cellHeight)
      local frac = cellHeight - fullCells
      local blockIdx = math.floor(frac * 8) + 1
      if blockIdx > 9 then blockIdx = 9 end

      local cx = ax + (w - dataW) + col

      -- Fill column from bottom
      for row = 0, fullCells - 1 do
        local ry = ay + h - 1 - row
        if ry >= ay then
          screen.drawChar(cx, ry, "█", lineColor, T.get("chart_bg"))
        end
      end
      -- Fractional top cell
      if fullCells < h and blockIdx > 1 then
        local ry = ay + h - 1 - fullCells
        if ry >= ay then
          screen.drawChar(cx, ry, BLOCKS[blockIdx], lineColor, T.get("chart_bg"))
        end
      end
    end
  end

  -- Label
  if self.label then
    screen.drawText(ax + 1, ay, self.label, T.get("text_secondary"), T.get("chart_bg"))
  end

  -- Current value
  if #self.values > 0 then
    local cur = self.values[#self.values]
    local valStr = string.format("%.0f%s", cur, self.unit)
    screen.drawText(ax + w - #valStr - 1, ay, valStr, T.get("text_bright"), T.get("chart_bg"))
  end
end

return Chart
