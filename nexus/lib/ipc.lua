-- ============================================================================
-- NEXUS-OS  /lib/ipc.lua
-- Pub/sub inter-process message bus
-- ============================================================================

local M = {}

-- channel → { handler1, handler2, ... }
local subscribers = {}

--- Publish a message on a channel.
-- @param channel  String channel name
-- @param ...      Payload data
function M.publish(channel, ...)
  local subs = subscribers[channel]
  if not subs then return end
  for i = #subs, 1, -1 do
    local ok, err = pcall(subs[i], channel, ...)
    if not ok then
      -- Remove broken handler
      table.remove(subs, i)
    end
  end
end

--- Subscribe to a channel.
-- @param channel  String channel name
-- @param handler  Function(channel, ...)
-- @return handler (use for unsubscribe)
function M.subscribe(channel, handler)
  if not subscribers[channel] then
    subscribers[channel] = {}
  end
  local subs = subscribers[channel]
  subs[#subs + 1] = handler
  return handler
end

--- Unsubscribe a handler from a channel.
function M.unsubscribe(channel, handler)
  local subs = subscribers[channel]
  if not subs then return false end
  for i = #subs, 1, -1 do
    if subs[i] == handler then
      table.remove(subs, i)
      return true
    end
  end
  return false
end

--- Unsubscribe handler from all channels.
function M.unsubscribeAll(handler)
  for ch, subs in pairs(subscribers) do
    for i = #subs, 1, -1 do
      if subs[i] == handler then
        table.remove(subs, i)
      end
    end
  end
end

--- Get list of channels with subscriber counts.
function M.channels()
  local result = {}
  for ch, subs in pairs(subscribers) do
    result[ch] = #subs
  end
  return result
end

--- Clear all subscriptions.
function M.clear()
  subscribers = {}
end

return M
