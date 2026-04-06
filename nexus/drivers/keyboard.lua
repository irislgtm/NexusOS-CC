-- ============================================================================
-- NEXUS-OS  /drivers/keyboard.lua
-- Key state tracker and hotkey registry
-- ============================================================================

local M = {}

-- Key state: keycode → true/false
local pressed = {}

-- Registered hotkeys: { {mods={ctrl?,shift?,alt?}, key=code, fn=callback} }
local hotkeys = {}

-- Common OC key codes (from keyboard component)
M.keys = {
  enter     = 28,
  back      = 14,
  tab       = 15,
  space     = 57,
  lshift    = 42,
  rshift    = 54,
  lcontrol  = 29,
  rcontrol  = 157,
  lalt      = 56,
  ralt      = 184,
  escape    = 1,
  up        = 200,
  down      = 208,
  left      = 203,
  right     = 205,
  home      = 199,
  ["end"]   = 207,
  pageUp    = 201,
  pageDown  = 209,
  insert    = 210,
  delete    = 211,
  f1 = 59, f2 = 60, f3 = 61, f4 = 62, f5 = 63,
  f6 = 64, f7 = 65, f8 = 66, f9 = 67, f10 = 68,
  f11 = 87, f12 = 88,
  q = 16, w = 17, e = 18, r = 19, t = 20,
  y = 21, u = 22, i = 23, o = 24, p = 25,
  a = 30, s = 31, d = 32, f = 33, g = 34,
  h = 35, j = 36, k = 37, l = 38,
  z = 44, x = 45, c = 46, v = 47, b = 48,
  n = 49, m = 50,
}

--- Check if a key is currently pressed.
function M.isDown(code)
  return pressed[code] == true
end

--- Check if any ctrl key is held.
function M.isCtrl()
  return pressed[29] == true or pressed[157] == true
end

--- Check if any shift key is held.
function M.isShift()
  return pressed[42] == true or pressed[54] == true
end

--- Check if any alt key is held.
function M.isAlt()
  return pressed[56] == true or pressed[184] == true
end

--- Register a hotkey binding.
-- @param combo  String like "ctrl+q", "ctrl+shift+s", "f5"
-- @param fn     Callback function (receives char, code)
-- @return handle   Use to unbind later
function M.bind(combo, fn)
  local mods = { ctrl = false, shift = false, alt = false }
  local keyName

  for part in combo:lower():gmatch("[^+]+") do
    part = part:match("^%s*(.-)%s*$")
    if part == "ctrl" or part == "control" then
      mods.ctrl = true
    elseif part == "shift" then
      mods.shift = true
    elseif part == "alt" then
      mods.alt = true
    else
      keyName = part
    end
  end

  local code = M.keys[keyName]
  if not code then return nil end

  local entry = { mods = mods, key = code, fn = fn, combo = combo }
  hotkeys[#hotkeys + 1] = entry
  return entry
end

--- Remove a hotkey binding.
function M.unbind(handle)
  for i = #hotkeys, 1, -1 do
    if hotkeys[i] == handle then
      table.remove(hotkeys, i)
      return true
    end
  end
  return false
end

--- Process key_down event. Call from event handler.
-- Returns true if a hotkey was triggered.
function M.onKeyDown(_, _, char, code)
  pressed[code] = true

  -- Check hotkeys
  for _, hk in ipairs(hotkeys) do
    if hk.key == code then
      local match = true
      if hk.mods.ctrl  and not M.isCtrl()  then match = false end
      if hk.mods.shift and not M.isShift() then match = false end
      if hk.mods.alt   and not M.isAlt()   then match = false end
      if match then
        hk.fn(char, code)
        return true
      end
    end
  end
  return false
end

--- Process key_up event.
function M.onKeyUp(_, _, char, code)
  pressed[code] = nil
end

--- Install event listeners (call once during boot).
function M.install()
  if _G.event then
    _G.event.listen("key_down", M.onKeyDown)
    _G.event.listen("key_up", M.onKeyUp)
  end
end

return M
