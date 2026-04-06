-- ============================================================================
-- NEXUS-OS  /boot/03_scheduler.lua
-- Coroutine-based cooperative process scheduler
-- ============================================================================

local computer = computer or require("computer")

local M = {}

----------------------------------------------------------------------------
-- Process table
----------------------------------------------------------------------------
local processes  = {}  -- pid → process record
local nextPid    = 1
local currentPid = 0   -- pid of currently running process (0 = kernel)

-- Process record: { pid, name, co, status, created, error }

----------------------------------------------------------------------------
-- API
----------------------------------------------------------------------------

--- Spawn a new process from a function.
-- @param fn       The function to run as a coroutine
-- @param name     Human-readable process name
-- @return pid     Integer process ID
function M.spawn(fn, name)
  local pid = nextPid
  nextPid = nextPid + 1

  local co = coroutine.create(fn)
  processes[pid] = {
    pid     = pid,
    name    = name or ("proc-" .. pid),
    co      = co,
    status  = "running",
    created = computer.uptime(),
    error   = nil,
  }
  return pid
end

--- Kill a process by pid. It will be removed on next tick.
function M.kill(pid)
  local p = processes[pid]
  if p then
    p.status = "dead"
  end
end

--- Get list of all processes.
-- @return table  Array of {pid, name, status, uptime}
function M.list()
  local result = {}
  local now = computer.uptime()
  for pid, p in pairs(processes) do
    result[#result + 1] = {
      pid    = p.pid,
      name   = p.name,
      status = p.status,
      uptime = now - p.created,
    }
  end
  table.sort(result, function(a, b) return a.pid < b.pid end)
  return result
end

--- Get currently running process pid (0 = kernel context)
function M.current()
  return currentPid
end

--- Get process info by pid
function M.info(pid)
  return processes[pid]
end

--- Get number of living processes
function M.count()
  local n = 0
  for _, p in pairs(processes) do
    if p.status ~= "dead" then n = n + 1 end
  end
  return n
end

----------------------------------------------------------------------------
-- Scheduler tick: resume all coroutines with the latest signal
-- Called from the kernel main loop in init.lua
----------------------------------------------------------------------------

--- Resume all living processes with the given signal.
-- Dead processes are reaped. Returns number of living processes.
function M.tick(signal)
  -- Collect pids (avoid mutating during iteration)
  local pids = {}
  for pid in pairs(processes) do
    pids[#pids + 1] = pid
  end
  table.sort(pids)

  for _, pid in ipairs(pids) do
    local p = processes[pid]
    if p.status == "dead" then
      processes[pid] = nil
    elseif p.co and coroutine.status(p.co) ~= "dead" then
      currentPid = pid
      local ok, err
      if signal then
        ok, err = coroutine.resume(p.co, table.unpack(signal))
      else
        ok, err = coroutine.resume(p.co)
      end
      currentPid = 0
      if not ok then
        p.status = "dead"
        p.error  = tostring(err)
      elseif coroutine.status(p.co) == "dead" then
        p.status = "dead"
      end
    else
      p.status = "dead"
      processes[pid] = nil
    end
  end

  -- Reap dead
  for pid, p in pairs(processes) do
    if p.status == "dead" then
      processes[pid] = nil
    end
  end

  return M.count()
end

----------------------------------------------------------------------------
-- Install globally
----------------------------------------------------------------------------
_G.scheduler = M
package.loaded["scheduler"] = M

hw.gpu.set(1, 3, "[BOOT] Scheduler online | cooperative coroutine model")

return M
