-- ============================================================================
-- NEXUS-OS  /firmware/drone_boot.lua
-- EEPROM Bootstrap: init modem, request code OTA, execute
-- This file must be < 4KB to fit in EEPROM
-- ============================================================================
-- Flash this onto drone's EEPROM. On boot, it:
-- 1. Finds modem component
-- 2. Broadcasts a code request on port 9200
-- 3. Receives the runtime code via modem
-- 4. Loads and executes it

local component = component
local computer = computer

-- Find modem
local modem
for addr, ctype in component.list("modem") do
  modem = component.proxy(addr)
  break
end
if not modem then
  computer.beep(1000, 0.5)
  computer.shutdown()
  return
end

-- Open drone port
modem.open(9200)
modem.setStrength(400)

-- Request code from controller
modem.broadcast(9200, "NX_DRONE_BOOT", computer.address())

-- Wait for code response (timeout 30s)
local deadline = computer.uptime() + 30
while computer.uptime() < deadline do
  local sig, _, from, port, _, msgType, code = computer.pullSignal(1)
  if sig == "modem_message" and port == 9200 then
    if msgType == "NX_DRONE_CODE" and type(code) == "string" then
      -- ACK
      modem.send(from, 9200, "NX_DRONE_ACK", computer.address())
      -- Load and execute
      local fn, err = load(code, "=drone_runtime")
      if fn then
        fn(modem, from)
      else
        modem.broadcast(9200, "NX_DRONE_ERR", computer.address(), tostring(err))
      end
      return
    end
  end
end

-- Timeout — beep and retry
computer.beep(500, 0.3)
computer.beep(500, 0.3)
-- Reboot to retry
computer.shutdown(true)
