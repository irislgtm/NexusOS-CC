-- ============================================================================
-- NEXUS-OS  /lib/serial.lua
-- Compact table serialization for configs and network payloads
-- ============================================================================

local M = {}

local function serializeValue(v, seen)
  local t = type(v)
  if t == "nil" then
    return "nil"
  elseif t == "boolean" then
    return v and "true" or "false"
  elseif t == "number" then
    if v ~= v then return "0/0" end          -- NaN
    if v == math.huge then return "1/0" end
    if v == -math.huge then return "-1/0" end
    return tostring(v)
  elseif t == "string" then
    return string.format("%q", v)
  elseif t == "table" then
    if seen[v] then error("circular reference in serialize") end
    seen[v] = true
    local parts = {}
    local arrLen = #v
    -- Array portion
    for i = 1, arrLen do
      parts[#parts + 1] = serializeValue(v[i], seen)
    end
    -- Hash portion
    for k, val in pairs(v) do
      if type(k) == "number" and k >= 1 and k <= arrLen and k == math.floor(k) then
        -- skip, already in array portion
      else
        local kStr
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
          kStr = k
        else
          kStr = "[" .. serializeValue(k, seen) .. "]"
        end
        parts[#parts + 1] = kStr .. "=" .. serializeValue(val, seen)
      end
    end
    seen[v] = nil
    return "{" .. table.concat(parts, ",") .. "}"
  else
    error("cannot serialize type: " .. t)
  end
end

--- Serialize a value to a Lua-evaluable string.
-- @param value   Any serializable value (nil, bool, number, string, table)
-- @return string
function M.serialize(value)
  return serializeValue(value, {})
end

--- Deserialize a string back to a value.
-- Only evaluates safe Lua literals (no function calls).
-- @param str  String produced by serialize()
-- @return value
function M.unserialize(str)
  if type(str) ~= "string" then return nil end
  -- Validate: only allow safe Lua literal characters
  local safe = str:gsub("[%w%s%p]", "")
  if #safe > 0 then return nil end
  local fn, err = load("return " .. str, "=unserialize", "t", {})
  if not fn then return nil end
  local ok, result = pcall(fn)
  if not ok then return nil end
  return result
end

return M
