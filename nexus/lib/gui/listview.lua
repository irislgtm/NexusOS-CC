-- ============================================================================
-- NEXUS-OS  /lib/gui/listview.lua
-- Scrollable data list with sortable columns
-- ============================================================================

local Widget = require("gui.widget")
local Screen = require("gui.screen")
local T      = require("theme")

local ListView = setmetatable({}, {__index = Widget})
ListView.__index = ListView

--- Create a list view.
-- @param x,y       Position
-- @param w,h       Size
-- @param columns   Array of { key, title, width } column definitions
function ListView.new(x, y, w, h, columns)
  local self = Widget.new(x, y, w, h)
  setmetatable(self, ListView)
  self.columns   = columns or {}
  self.data      = {}         -- array of row tables (keyed by column.key)
  self.scrollY   = 0          -- scroll offset (rows)
  self.selected  = 0          -- selected row index (1-based, 0=none)
  self.sortCol   = nil        -- column key to sort by
  self.sortAsc   = true
  self.onSelect  = nil        -- callback(self, rowIndex, rowData)
  self.rowColors = nil        -- function(rowData) → fg color override
  return self
end

--- Set the data source. Data is an array of tables with column keys.
function ListView:setData(data)
  self.data = data or {}
  if self.sortCol then self:sort() end
  self:invalidate()
end

--- Sort data by the current sort column.
function ListView:sort()
  if not self.sortCol then return end
  local key = self.sortCol
  local asc = self.sortAsc
  table.sort(self.data, function(a, b)
    local va, vb = a[key], b[key]
    if va == nil then return false end
    if vb == nil then return true end
    if asc then return va < vb else return va > vb end
  end)
end

--- Get the number of visible rows (excluding header).
function ListView:visibleRows()
  return self.height - 1  -- 1 row for header
end

function ListView:draw(screen)
  if not self.visible then return end
  local ax, ay = self:absolutePosition()

  -- Header row
  local hx = ax
  screen.fillRect(ax, ay, self.width, 1, T.get("highlight_bg"))
  for _, col in ipairs(self.columns) do
    local title = col.title or col.key
    if #title > col.width then title = title:sub(1, col.width) end
    local sortIndicator = ""
    if self.sortCol == col.key then
      sortIndicator = self.sortAsc and " ▲" or " ▼"
    end
    screen.drawText(hx, ay, title .. sortIndicator, T.get("text_secondary"), T.get("highlight_bg"))
    hx = hx + col.width + 1
  end

  -- Data rows
  local maxRows = self:visibleRows()
  local bg = T.get("window_bg")
  for row = 1, maxRows do
    local dataIdx = row + self.scrollY
    local ry = ay + row
    if dataIdx <= #self.data then
      local rowData = self.data[dataIdx]
      local isSelected = (dataIdx == self.selected)
      local rowBg = isSelected and T.get("selection_bg") or bg
      local rowFg = isSelected and T.get("selection_fg") or T.get("text_primary")

      -- Custom row color
      if self.rowColors and not isSelected then
        local c = self.rowColors(rowData)
        if c then rowFg = c end
      end

      screen.fillRect(ax, ry, self.width, 1, rowBg)
      local cx = ax
      for _, col in ipairs(self.columns) do
        local val = tostring(rowData[col.key] or "")
        if #val > col.width then val = val:sub(1, col.width - 1) .. "…" end
        screen.drawText(cx, ry, val, rowFg, rowBg)
        cx = cx + col.width + 1
      end
    else
      screen.fillRect(ax, ry, self.width, 1, bg)
    end
  end

  -- Scrollbar (if needed)
  if #self.data > maxRows then
    local sbHeight = math.max(1, math.floor(maxRows * maxRows / #self.data))
    local sbPos = math.floor(self.scrollY / math.max(1, #self.data - maxRows) * (maxRows - sbHeight))
    local sbX = ax + self.width - 1
    for i = 0, maxRows - 1 do
      local ch = (i >= sbPos and i < sbPos + sbHeight) and "█" or "░"
      screen.drawChar(sbX, ay + 1 + i, ch, T.get("scrollbar_fg"), T.get("scrollbar_bg"))
    end
  end
end

function ListView:eventHandler(workspace, eventName, ...)
  if not self.visible then return false end
  local args = {...}

  if eventName == "touch" then
    local screenAddr, px, py = args[1], args[2], args[3]
    if not self:contains(px, py) then return false end

    local ax, ay = self:absolutePosition()
    local relY = py - ay

    if relY == 0 then
      -- Header click → sort by column
      local cx = 0
      for _, col in ipairs(self.columns) do
        if px >= ax + cx and px < ax + cx + col.width then
          if self.sortCol == col.key then
            self.sortAsc = not self.sortAsc
          else
            self.sortCol = col.key
            self.sortAsc = true
          end
          self:sort()
          self:invalidate()
          return true
        end
        cx = cx + col.width + 1
      end
    else
      -- Row click → select
      local dataIdx = relY + self.scrollY
      if dataIdx >= 1 and dataIdx <= #self.data then
        self.selected = dataIdx
        if self.onSelect then
          self.onSelect(self, dataIdx, self.data[dataIdx])
        end
        self:invalidate()
      end
      return true
    end

  elseif eventName == "scroll" then
    local screenAddr, px, py, direction = args[1], args[2], args[3], args[4]
    if self:contains(px, py) then
      local maxScroll = math.max(0, #self.data - self:visibleRows())
      self.scrollY = math.max(0, math.min(maxScroll, self.scrollY - direction))
      self:invalidate()
      return true
    end
  end

  return false
end

return ListView
