-- ============================================================================
-- NEXUS-OS  /boot/04_events.lua
-- Event system: listen, once, push, pull, timer
-- ============================================================================

local computer = computer or require("computer")

local M = {}

----------------------------------------------------------------------------
-- Internal state
----------------------------------------------------------------------------
local listeners = {}      -- name → { handler1, handler2, ... }
local onceQueue = {}      -- name → { handler1, handler2, ... }
local timers    = {}      -- id → { interval, callback, remaining, lastFire }
local nextTimer = 1
local pushed    = {}      -- queue of synthetic signals
local pushedHead = 1       -- index of next signal to pop

----------------------------------------------------------------------------
-- Listener management
----------------------------------------------------------------------------

--- Register a persistent event handler.
-- @param name     Signal name (e.g. "key_down", "touch")
-- @param handler  function(eventName, ...)
-- @return handler (for later removal)
function M.listen(name, handler)
  if not listeners[name] then
    listeners[name] = {}
  end
  -- Prevent duplicates
  for _, h in ipairs(listeners[name]) do
    if h == handler then return handler end
  end
  table.insert(listeners[name], handler)
  return handler
end

--- Remove a persistent handler.
function M.unlisten(name, handler)
  local list = listeners[name]
  if not list then return false end
  for i, h in ipairs(list) do
    if h == handler then
      table.remove(list, i)
      return true
    end
  end
  return false
end

--- Register a one-shot handler (auto-removed after first fire).
function M.once(name, handler)
  if not onceQueue[name] then
    onceQueue[name] = {}
  end
  table.insert(onceQueue[name], handler)
  return handler
end

--- Inject a synthetic signal into the queue.
function M.push(name, ...)
  pushed[#pushed + 1] = table.pack(name, ...)
end

--- Coroutine-friendly blocking wait for a signal.
-- @param name     Optional signal name filter
-- @param timeout  Optional timeout in seconds (default: math.huge)
-- @return eventName, ... or nil on timeout
function M.pull(name, timeout)
  local deadline
  if type(name) == "number" then
    -- pull(timeout) form — no name filter
    timeout = name
    name = nil
  end
  timeout = timeout or math.huge
  deadline = computer.uptime() + timeout

  while true do
    local signal = table.pack(coroutine.yield())
    if signal.n > 0 then
      if name == nil or signal[1] == name then
        return table.unpack(signal, 1, signal.n)
      end
    end
    if computer.uptime() >= deadline then
      return nil
    end
  end
end

--- Create a repeating timer.
-- @param interval  Seconds between fires
-- @param callback  function() to call
-- @param times     Number of fires (default: math.huge = infinite)
-- @return timerId
function M.timer(interval, callback, times)
  local id = nextTimer
  nextTimer = nextTimer + 1
  timers[id] = {
    interval  = interval,
    callback  = callback,
    remaining = times or math.huge,
    lastFire  = computer.uptime(),
  }
  return id
end

--- Cancel a timer.
function M.cancelTimer(id)
  timers[id] = nil
end

----------------------------------------------------------------------------
-- Dispatch: called from kernel main loop with each signal
----------------------------------------------------------------------------

--- Process all listeners and timers for the given signal.
-- Called before scheduler.tick() in the kernel loop.
function M.dispatch(signal)
  local name = signal and signal[1]

  -- Fire persistent listeners
  if name and listeners[name] then
    -- Copy list to allow modification during iteration
    local list = {}
    for _, h in ipairs(listeners[name]) do list[#list + 1] = h end
    for _, h in ipairs(list) do
      local ok, err = pcall(h, table.unpack(signal, 1, signal.n or #signal))
      if not ok then
        -- Log error silently; don't crash the event system
      end
    end
  end

  -- Fire one-shot listeners
  if name and onceQueue[name] then
    local list = onceQueue[name]
    onceQueue[name] = nil
    for _, h in ipairs(list) do
      pcall(h, table.unpack(signal, 1, signal.n or #signal))
    end
  end

  -- Fire timers
  local now = computer.uptime()
  local expired = {}
  for id, t in pairs(timers) do
    if now - t.lastFire >= t.interval then
      t.lastFire = now
      t.remaining = t.remaining - 1
      pcall(t.callback)
      if t.remaining <= 0 then
        expired[#expired + 1] = id
      end
    end
  end
  for _, id in ipairs(expired) do
    timers[id] = nil
  end
end

--- Pop a synthetic signal if any exist.
function M.popPushed()
  if pushedHead <= #pushed then
    local sig = pushed[pushedHead]
    pushed[pushedHead] = nil  -- allow GC
    pushedHead = pushedHead + 1
    -- Reset when queue is drained to prevent unbounded index growth
    if pushedHead > #pushed then
      pushed = {}
      pushedHead = 1
    end
    return sig
  end
  return nil
end

--- Get count of registered listeners (for diagnostics)
function M.listenerCount()
  local n = 0
  for _, list in pairs(listeners) do n = n + #list end
  return n
end

--- Get count of active timers
function M.timerCount()
  local n = 0
  for _ in pairs(timers) do n = n + 1 end
  return n
end

----------------------------------------------------------------------------
-- Install globally
----------------------------------------------------------------------------
_G.event = M
package.loaded["event"] = M

hw.gpu.set(1, 4, "[BOOT] Event system online | listen/pull/push/timer")

return M
