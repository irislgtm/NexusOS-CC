-- ============================================================================
-- NEXUS-OS  /bin/ifconfig.lua — Network interface status
-- ============================================================================

local modem = require("modem")

if not modem.isAvailable() then
  print("No modem detected.")
  return
end

print("Network Interface")
print(string.rep("-", 40))
print("  Address:    " .. (modem.getAddress() or "N/A"))
print("  Wireless:   " .. tostring(modem.isWireless()))
print("  Strength:   " .. tostring(modem.getStrength()))
print("  Max Packet: " .. tostring(modem.maxPacketSize()) .. " bytes")

-- Show open ports
local net = require("net")
local ports = net.getPorts()
print("  Ports:      " .. ports.data .. " (data), " .. ports.ack .. " (ack), " ..
  ports.disc .. " (disc), " .. ports.drone .. " (drone)")

-- Known nodes
local nodes = net.getNodes()
print("")
print("Known Nodes: " .. #nodes)
for _, node in ipairs(nodes) do
  print(string.format("  %-12s  %s  dist=%.0f  age=%.0fs",
    node.name or "?",
    node.address:sub(1, 8) .. "...",
    node.distance or 0,
    node.age or 0))
end
