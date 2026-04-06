-- ============================================================================
-- NEXUS-OS  /lib/process.lua
-- High-level process management built on top of the coroutine scheduler
-- ============================================================================

local M = {}

--- Spawn a new process.
-- @param fn    Function to run
-- @param name  Process name
-- @param env   Optional environment table
-- @return pid
function M.spawn(fn, name, env)
  if not _G.scheduler then
    error("Scheduler not initialized")
  end
  return _G.scheduler.spawn(fn, name)
end

--- Kill a process by PID.
function M.kill(pid)
  if not _G.scheduler then return false end
  return _G.scheduler.kill(pid)
end

--- List all processes.
-- @return Array of { pid, name, status, uptime }
function M.list()
  if not _G.scheduler then return {} end
  return _G.scheduler.list()
end

--- Get info about a specific process.
function M.info(pid)
  local procs = M.list()
  for _, p in ipairs(procs) do
    if p.pid == pid then return p end
  end
  return nil
end

--- Find process by name.
function M.findByName(name)
  local procs = M.list()
  local results = {}
  for _, p in ipairs(procs) do
    if p.name == name then
      results[#results + 1] = p
    end
  end
  return results
end

--- Check if a process is alive.
function M.isAlive(pid)
  local p = M.info(pid)
  return p ~= nil and p.status ~= "dead"
end

--- Get count of running processes.
function M.count()
  local procs = M.list()
  local n = 0
  for _, p in ipairs(procs) do
    if p.status ~= "dead" then n = n + 1 end
  end
  return n
end

--- Spawn and forget — runs function, auto-cleans.
function M.exec(fn, name)
  return M.spawn(function()
    local ok, err = xpcall(fn, debug.traceback)
    if not ok then
      if _G.event then
        _G.event.push("process_error", name, err)
      end
    end
  end, name)
end

return M
