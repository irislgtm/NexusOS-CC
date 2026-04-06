-- ============================================================================
-- NEXUS-OS  /lib/gui/radar.lua
-- 2D radar overlay widget with compass rose and entity blips
-- ============================================================================

local Widget = require("gui.widget")
local Screen = require("gui.screen")
local T      = require("theme")

local Radar = setmetatable({}, {__index = Widget})
Radar.__index = Radar

--- Create a radar widget.
-- @param x,y     Position
-- @param w,h     Size (should be roughly square, h ~= w/2 due to char aspect)
-- @param range   Max detection range in blocks (default 32)
function Radar.new(x, y, w, h, range)
  local self = Widget.new(x, y, w, h)
  setmetatable(self, Radar)
  self.entities   = {}
  self.range      = range or 32
  self.showGrid   = true
  self.showLabels = true
  return self
end

--- Set entity data.
-- Each entity: { name, x, z, classification, distance }
-- classification: "player", "hostile", "passive", "unknown", "drone"
function Radar:setEntities(entities)
  self.entities = entities or {}
  self:invalidate()
end

--- Get color for entity classification
local function entityColor(cl)
  return T.get("entity_" .. (cl or "unknown"))
end

--- Get blip character for classification
local function entityChar(cl)
  if cl == "player"  then return "@" end
  if cl == "hostile"  then return "!" end
  if cl == "passive"  then return "·" end
  if cl == "drone"    then return "◆" end
  return "?"
end

function Radar:draw(screen)
  if not self.visible then return end
  local ax, ay = self:absolutePosition()
  local w, h = self.width, self.height

  -- Background
  screen.fillRect(ax, ay, w, h, T.get("radar_bg"))

  local cx = ax + math.floor(w / 2)
  local cy = ay + math.floor(h / 2)
  local rx = math.floor(w / 2) - 1   -- horizontal radius
  local ry = math.floor(h / 2) - 1   -- vertical radius

  -- Grid / range rings
  if self.showGrid then
    -- Crosshair
    screen.drawHLine(ax + 1, cy, w - 2, "·", T.get("radar_grid"), T.get("radar_bg"))
    screen.drawVLine(cx, ay + 1, h - 2, ":", T.get("radar_grid"), T.get("radar_bg"))

    -- Range ring (approximate ellipse using chars)
    local ringColor = T.get("radar_ring")
    for angle = 0, 360, 5 do
      local rad = math.rad(angle)
      local px = cx + math.floor(math.sin(rad) * rx * 0.7 + 0.5)
      local py = cy - math.floor(math.cos(rad) * ry * 0.7 + 0.5)
      if px > ax and px < ax + w - 1 and py > ay and py < ay + h - 1 then
        screen.drawChar(px, py, "·", ringColor, T.get("radar_bg"))
      end
    end
  end

  -- Center marker
  screen.drawChar(cx, cy, "+", T.get("text_bright"), T.get("radar_bg"))

  -- Compass labels
  local compassColor = T.get("radar_compass")
  screen.drawChar(cx, ay, "N", compassColor, T.get("radar_bg"))
  screen.drawChar(cx, ay + h - 1, "S", compassColor, T.get("radar_bg"))
  screen.drawChar(ax, cy, "W", compassColor, T.get("radar_bg"))
  screen.drawChar(ax + w - 1, cy, "E", compassColor, T.get("radar_bg"))

  -- Entity blips
  for _, ent in ipairs(self.entities) do
    local nx = (ent.x or 0) / self.range  -- normalized -1..1
    local nz = (ent.z or 0) / self.range

    local px = cx + math.floor(nx * rx + 0.5)
    local py = cy + math.floor(nz * ry + 0.5)

    -- Clamp to radar bounds
    px = math.max(ax + 1, math.min(ax + w - 2, px))
    py = math.max(ay + 1, math.min(ay + h - 2, py))

    local cl = ent.classification or "unknown"
    local color = entityColor(cl)
    local ch = entityChar(cl)

    screen.drawChar(px, py, ch, color, T.get("radar_bg"))

    -- Label (if space allows and labels enabled)
    if self.showLabels and ent.name and #ent.name > 0 then
      local label = ent.name:sub(1, 8)
      local lx = px + 1
      if lx + #label > ax + w then lx = px - #label - 1 end
      if lx >= ax and lx + #label <= ax + w then
        screen.drawText(lx, py, label, color, T.get("radar_bg"))
      end
    end
  end

  -- Range label
  local rangeStr = tostring(self.range) .. "m"
  screen.drawText(ax + w - #rangeStr - 1, ay + h - 1, rangeStr,
    T.get("text_muted"), T.get("radar_bg"))

  -- Entity count
  local countStr = tostring(#self.entities)
  screen.drawText(ax + 1, ay + h - 1, countStr, T.get("text_secondary"), T.get("radar_bg"))
end

return Radar
