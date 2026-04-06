-- ============================================================================
-- NEXUS-OS  /bin/top.lua — Process monitor
-- ============================================================================

local process = require("process")

local procs = process.list()

-- Header
local fmt = "%-6s %-20s %-10s %10s"
print(string.format(fmt, "PID", "NAME", "STATUS", "UPTIME"))
print(string.rep("-", 50))

for _, p in ipairs(procs) do
  local uptime = string.format("%.1fs", p.uptime or 0)
  print(string.format(fmt, tostring(p.pid), p.name or "?", p.status or "?", uptime))
end

print("")
print("Processes: " .. #procs .. "  |  Memory: " ..
  math.floor((computer.totalMemory() - computer.freeMemory()) / 1024) .. "KB / " ..
  math.floor(computer.totalMemory() / 1024) .. "KB")
