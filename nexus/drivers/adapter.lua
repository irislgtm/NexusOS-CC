-- ============================================================================
-- NEXUS-OS  /drivers/adapter.lua
-- Generic adapter block method dispatcher
-- Used by mod-specific drivers that talk through adapter blocks
-- ============================================================================

local component = component or require("component")

local M = {}

--- Find all components of a given type.
-- @return Array of addresses
function M.findAll(ctype)
  local addrs = {}
  if _G.hw and _G.hw.findAll then
    local list = _G.hw.findAll(ctype)
    for _, addr in ipairs(list or {}) do
      addrs[#addrs + 1] = addr
    end
  else
    for addr, t in component.list(ctype) do
      addrs[#addrs + 1] = addr
    end
  end
  return addrs
end

--- Find first component of type.
-- @return proxy or nil
function M.find(ctype)
  if _G.hw and _G.hw.find then
    return _G.hw.find(ctype)
  end
  local addr = component.list(ctype)()
  if addr then return component.proxy(addr) end
  return nil
end

--- Invoke a method on a component proxy, with safe error handling.
-- @param proxy     Component proxy table
-- @param method    Method name string
-- @param ...       Arguments
-- @return result or nil, error
function M.call(proxy, method, ...)
  if not proxy or not proxy[method] then
    return nil, "Method not available: " .. tostring(method)
  end
  local ok, result = pcall(proxy[method], ...)
  if ok then return result
  else return nil, result end
end

--- List available methods on a component.
-- @param addr  Component address
-- @return Table of {methodName → {direct=bool, ...}} or nil
function M.methods(addr)
  if component.methods then
    return component.methods(addr)
  end
  return nil
end

--- Introspect a component — returns type and method list.
function M.info(addr)
  local ctype = component.type(addr)
  local methods = M.methods(addr)
  return { type = ctype, address = addr, methods = methods }
end

return M
