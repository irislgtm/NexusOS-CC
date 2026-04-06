-- NEXUS-OS Bootstrap -- paste this on pastebin, then in-game: pastebin run <code>
-- Replace the URL below with your raw GitHub URL to install.lua
local url = "https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME/main/nexus/install.lua"
local r = require("component").internet.request(url)
local s = ""
repeat local c = r.read(4096); if c then s=s..c end until not c
r.close()
local f = io.open("/tmp/install.lua","w"); f:write(s); f:close()
loadfile("/tmp/install.lua")()
