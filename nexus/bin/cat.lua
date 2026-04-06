-- ============================================================================
-- NEXUS-OS  /bin/cat.lua — Display file contents
-- ============================================================================

local args = { ... }
local path = args[1]

if not path then
  print("Usage: cat <file>")
  return
end

if _G._fs then
  local data = _G._fs.read(path)
  if data then
    print(data)
  else
    print("cat: " .. path .. ": No such file")
  end
else
  print("cat: filesystem not available")
end
