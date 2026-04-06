-- ============================================================================
-- NEXUS-OS  /bin/ping.lua — Network ping utility
-- ============================================================================

local net   = require("net")
local modem = require("modem")

local args = { ... }
local target = args[1]

if not target then
  print("Usage: ping <address>")
  print("       ping broadcast")
  return
end

if not modem.isAvailable() then
  print("No modem available.")
  return
end

if target == "broadcast" or target == "*" then
  print("Broadcasting discovery ping...")
  net.discover()
  print("Waiting for responses...")

  -- Wait a few seconds for replies
  local deadline = computer.uptime() + 3
  local count = 0
  while computer.uptime() < deadline do
    local sig = table.pack(coroutine.yield())
    if sig[1] == "net_discovery" then
      count = count + 1
      print(string.format("  Reply from %s (%s) dist=%.0f",
        sig[3] or "?", (sig[2] or ""):sub(1, 8), 0))
    end
  end
  print(count .. " node(s) responded.")
else
  -- Direct ping
  local start = computer.uptime()
  net.send(target, { type = "ping", time = start }, true)
  print("Pinging " .. target:sub(1, 16) .. "...")

  local deadline = start + 5
  while computer.uptime() < deadline do
    local sig = table.pack(coroutine.yield())
    if sig[1] == "net_message" and sig[2] == target then
      local rtt = (computer.uptime() - start) * 1000
      print(string.format("Reply: %.1fms", rtt))
      return
    elseif sig[1] == "net_timeout" then
      break
    end
  end
  print("Request timed out.")
end
