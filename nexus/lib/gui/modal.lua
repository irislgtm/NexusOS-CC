-- ============================================================================
-- NEXUS-OS  /lib/gui/modal.lua
-- Modal dialog overlay: alert, confirm, input prompt
-- ============================================================================

local Widget    = require("gui.widget")
local Container = require("gui.container")
local Screen    = require("gui.screen")
local Button    = require("gui.button")
local TextField = require("gui.textfield")
local T         = require("theme")

local Modal = setmetatable({}, {__index = Container})
Modal.__index = Modal

--- Create a modal dialog that covers the workspace.
-- @param opts  {title, message, mode, onResult}
--   mode: "alert" (OK), "confirm" (Yes/No), "input" (text + OK/Cancel)
function Modal.new(opts)
  opts = opts or {}
  local mode    = opts.mode or "alert"
  local title   = opts.title or "Dialog"
  local message = opts.message or ""
  local onResult = opts.onResult  -- callback(result): true/false/string/nil

  -- Size the dialog
  local dw = math.max(30, math.min(60, #message + 6))
  local dh = (mode == "input") and 9 or 7

  -- Center on screen (uses hw.gpu to query resolution)
  local sw, sh = 160, 50
  if _G.hw and _G.hw.find then
    local gpu = _G.hw.find("gpu")
    if gpu then sw, sh = gpu.getResolution() end
  end
  local dx = math.floor((sw - dw) / 2)
  local dy = math.floor((sh - dh) / 2)

  local self = Container.new(dx, dy, dw, dh)
  setmetatable(self, Modal)

  self.title    = title
  self.message  = message
  self.mode     = mode
  self.onResult = onResult
  self.result   = nil
  self.field    = nil

  -- Word-wrap message
  local lines = {}
  local maxLineW = dw - 4
  local remaining = message
  while #remaining > 0 do
    if #remaining <= maxLineW then
      lines[#lines + 1] = remaining
      break
    end
    local cut = remaining:sub(1, maxLineW):match(".*()%s") or maxLineW
    lines[#lines + 1] = remaining:sub(1, cut):match("^(.-)%s*$")
    remaining = remaining:sub(cut + 1):match("^%s*(.*)$") or ""
  end
  self._lines = lines

  -- Build buttons / input field
  local btnY = dh - 2

  if mode == "alert" then
    local okBtn = Button.new(math.floor(dw / 2) - 3, btnY, 8, 1, "[ OK ]", function()
      self:close(true)
    end)
    self:addChild(okBtn)

  elseif mode == "confirm" then
    local yesBtn = Button.new(math.floor(dw / 2) - 9, btnY, 8, 1, "[ Yes ]", function()
      self:close(true)
    end)
    local noBtn = Button.new(math.floor(dw / 2) + 2, btnY, 8, 1, "[ No ]", function()
      self:close(false)
    end)
    self:addChild(yesBtn)
    self:addChild(noBtn)

  elseif mode == "input" then
    local fieldY = btnY - 2
    self.field = TextField.new(3, fieldY, dw - 6, opts.placeholder or "")
    self:addChild(self.field)

    local okBtn = Button.new(math.floor(dw / 2) - 11, btnY, 10, 1, "[ OK ]", function()
      self:close(self.field.text)
    end)
    local cancelBtn = Button.new(math.floor(dw / 2) + 2, btnY, 10, 1, "[ Cancel ]", function()
      self:close(nil)
    end)
    self:addChild(okBtn)
    self:addChild(cancelBtn)
  end

  return self
end

--- Close dialog and fire callback
function Modal:close(result)
  self.result = result
  -- Remove self from parent
  if self.parent then
    self.parent:removeChild(self)
    if self.parent.invalidate then self.parent:invalidate() end
  end
  if self.onResult then
    self.onResult(result)
  end
end

--- Draw the modal (dim overlay + dialog box)
function Modal:draw(screen)
  if not self.visible then return end
  local ax, ay = self:absolutePosition()
  local w, h = self.width, self.height

  -- Dialog border + background
  local bgColor     = T.get("modal_bg")
  local borderColor = T.get("modal_border")
  local titleColor  = T.get("modal_title")
  local textColor   = T.get("text_primary")

  screen.fillRect(ax, ay, w, h, bgColor)
  screen.drawBorder(ax, ay, w, h, borderColor, bgColor, "single")

  -- Title bar
  screen.drawHLine(ax + 1, ay, w - 2, " ", titleColor, T.get("accent"))
  local titleStr = " " .. self.title:sub(1, w - 4) .. " "
  screen.drawText(ax + math.floor((w - #titleStr) / 2), ay,
    titleStr, titleColor, T.get("accent"))

  -- Message lines
  for i, line in ipairs(self._lines) do
    local ly = ay + 1 + i
    if ly < ay + h - 2 then
      screen.drawText(ax + 2, ly, line:sub(1, w - 4), textColor, bgColor)
    end
  end

  -- Draw child widgets (buttons, text field)
  for _, child in ipairs(self.children) do
    child:draw(screen)
  end
end

--- Modal captures all events (blocking click-through)
function Modal:eventHandler(workspace, eName, ...)
  -- Forward keyboard events to text field if present
  if self.field and (eName == "key_down" or eName == "clipboard") then
    self.field:eventHandler(workspace, eName, ...)
    return true
  end

  -- Forward touch to children
  if eName == "touch" or eName == "drag" or eName == "drop" then
    -- Use container's normal dispatch for positioned events
    Container.eventHandler(self, workspace, eName, ...)
    return true  -- always consume to block click-through
  end

  -- Consume all other events to prevent passthrough
  return true
end

-- Convenience constructors
function Modal.alert(title, message, onDone)
  return Modal.new({title = title, message = message, mode = "alert", onResult = onDone})
end

function Modal.confirm(title, message, onResult)
  return Modal.new({title = title, message = message, mode = "confirm", onResult = onResult})
end

function Modal.prompt(title, message, placeholder, onResult)
  return Modal.new({
    title = title, message = message, mode = "input",
    placeholder = placeholder, onResult = onResult
  })
end

return Modal
