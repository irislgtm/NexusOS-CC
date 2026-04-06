-- ============================================================================
-- NEXUS-OS  /bin/ls.lua — Directory listing
-- ============================================================================

local args = { ... }
local path = args[1] or "/"

if _G._fs then
  local entries = _G._fs.list(path)
  if entries then
    for _, name in ipairs(entries) do
      local isDir = _G._fs.isDirectory(path .. "/" .. name)
      if isDir then
        print(name .. "/")
      else
        print(name)
      end
    end
  else
    print("ls: cannot access '" .. path .. "'")
  end
else
  print("ls: filesystem not available")
end
