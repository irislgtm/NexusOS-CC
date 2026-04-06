-- ============================================================================
-- NEXUS-OS  /bin/sh.lua
-- Shell command interpreter
-- ============================================================================

local M = {}

-- Command search paths
local PATHS = { "/bin/", "/apps/" }

-- Command history
local history = {}
local MAX_HISTORY = 100

-- Environment
local env = {
  PATH = "/bin/",
  HOME = "/",
  USER = "operator",
  HOSTNAME = "nexus",
  SHELL = "/bin/sh.lua",
}

--- Resolve a command name to a file path.
local function resolveCommand(name)
  -- Absolute path
  if name:sub(1, 1) == "/" then
    if _G._fs and _G._fs.exists(name) then return name end
    return nil
  end
  -- Search paths
  for _, dir in ipairs(PATHS) do
    local path = dir .. name
    if _G._fs and _G._fs.exists(path) then return path end
    path = dir .. name .. ".lua"
    if _G._fs and _G._fs.exists(path) then return path end
  end
  return nil
end

--- Split command line into tokens.
local function tokenize(line)
  local tokens = {}
  local i = 1
  while i <= #line do
    -- Skip whitespace
    while i <= #line and line:sub(i, i):match("%s") do i = i + 1 end
    if i > #line then break end

    local ch = line:sub(i, i)
    if ch == '"' then
      -- Quoted string
      local j = line:find('"', i + 1, true)
      if j then
        tokens[#tokens + 1] = line:sub(i + 1, j - 1)
        i = j + 1
      else
        tokens[#tokens + 1] = line:sub(i + 1)
        break
      end
    else
      -- Unquoted word
      local j = line:find("%s", i)
      if j then
        tokens[#tokens + 1] = line:sub(i, j - 1)
        i = j
      else
        tokens[#tokens + 1] = line:sub(i)
        break
      end
    end
  end
  return tokens
end

--- Expand environment variables ($VAR).
local function expandVars(token)
  return token:gsub("%$(%w+)", function(var)
    return env[var] or ""
  end)
end

-- ── Built-in commands ───────────────────────────────────────────────────

local builtins = {}

builtins.help = function()
  local gpu = _G.hw and _G.hw.find("gpu")
  local out = {
    "NEXUS-OS Shell",
    "Built-in commands: help, cd, pwd, set, export, env, echo, clear, exit, history",
    "External: ls, cat, top, ping, ifconfig, reboot, edit",
    "Use 'desktop' to launch GUI.",
  }
  for _, line in ipairs(out) do
    if gpu then gpu.set(1, ({gpu.getResolution()})[2], line) end
    print(line)
  end
end

builtins.cd = function(args)
  -- Stub: OC doesn't have cwd per se, but we track in env
  env.PWD = args[1] or "/"
end

builtins.pwd = function()
  print(env.PWD or "/")
end

builtins.echo = function(args)
  print(table.concat(args, " "))
end

builtins.set = function(args)
  if #args >= 2 then
    env[args[1]] = table.concat(args, " ", 2)
  else
    for k, v in pairs(env) do
      print(k .. "=" .. tostring(v))
    end
  end
end

builtins.export = builtins.set

builtins.env = function()
  for k, v in pairs(env) do
    print(k .. "=" .. tostring(v))
  end
end

builtins.clear = function()
  local gpu = _G.hw and _G.hw.find("gpu")
  if gpu then
    local w, h = gpu.getResolution()
    gpu.fill(1, 1, w, h, " ")
  end
end

builtins.exit = function()
  return "EXIT"
end

builtins.history = function()
  for i, cmd in ipairs(history) do
    print(string.format("%4d  %s", i, cmd))
  end
end

-- ── Execution ───────────────────────────────────────────────────────────

--- Execute a single command line.
-- @return "EXIT" to stop shell, nil otherwise
function M.execute(line)
  if not line or #line == 0 then return end

  -- History
  if #history >= MAX_HISTORY then table.remove(history, 1) end
  history[#history + 1] = line

  -- Tokenize and expand
  local tokens = tokenize(line)
  if #tokens == 0 then return end

  for i, t in ipairs(tokens) do
    tokens[i] = expandVars(t)
  end

  local cmd = tokens[1]
  local args = {}
  for i = 2, #tokens do args[#args + 1] = tokens[i] end

  -- Check builtins
  if builtins[cmd] then
    return builtins[cmd](args)
  end

  -- Resolve external command
  local path = resolveCommand(cmd)
  if not path then
    print("sh: command not found: " .. cmd)
    return
  end

  -- Load and execute
  local fn, err = loadfile(path)
  if not fn then
    print("sh: error loading " .. cmd .. ": " .. tostring(err))
    return
  end

  local ok, result = xpcall(fn, debug.traceback, table.unpack(args))
  if not ok then
    print("sh: " .. cmd .. ": " .. tostring(result))
  end
  return result
end

--- Interactive shell loop. Reads from keyboard via event system.
function M.interactive()
  local gpu = _G.hw and _G.hw.find("gpu")
  local w, h = 160, 50
  if gpu then w, h = gpu.getResolution() end

  local cursorY = 1
  local inputBuf = ""

  local function writeLine(text)
    if gpu then
      if cursorY > h then
        gpu.copy(1, 2, w, h - 1, 0, -1)
        gpu.fill(1, h, w, 1, " ")
        cursorY = h
      end
      gpu.set(1, cursorY, text)
      cursorY = cursorY + 1
    end
  end

  -- Override print for shell context
  local oldPrint = print
  _G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring(select(i, ...))
    end
    writeLine(table.concat(parts, "\t"))
  end

  writeLine("NEXUS-OS Shell v1.0  (type 'help' for commands)")

  while true do
    -- Show prompt
    if gpu then
      if cursorY > h then
        gpu.copy(1, 2, w, h - 1, 0, -1)
        gpu.fill(1, h, w, 1, " ")
        cursorY = h
      end
      gpu.set(1, cursorY, (env.USER or "$") .. "@" .. (env.HOSTNAME or "nexus") .. "> ")
    end

    -- Read line via events
    inputBuf = ""
    local promptLen = #((env.USER or "$") .. "@" .. (env.HOSTNAME or "nexus") .. "> ")

    while true do
      local sig = table.pack(coroutine.yield())
      if sig[1] == "key_down" then
        local char, code = sig[3], sig[4]
        if code == 28 then -- Enter
          break
        elseif code == 14 then -- Backspace
          if #inputBuf > 0 then
            inputBuf = inputBuf:sub(1, -2)
            if gpu then
              gpu.fill(promptLen + 1, cursorY, w - promptLen, 1, " ")
              gpu.set(promptLen + 1, cursorY, inputBuf)
            end
          end
        elseif char and char >= 32 and char < 127 then
          inputBuf = inputBuf .. string.char(char)
          if gpu then
            gpu.set(promptLen + 1, cursorY, inputBuf)
          end
        end
      end
    end

    cursorY = cursorY + 1
    local result = M.execute(inputBuf)
    if result == "EXIT" then break end
  end

  _G.print = oldPrint
end

--- Get history.
function M.getHistory()
  return history
end

--- Get/set environment variable.
function M.getenv(key)
  return env[key]
end

function M.setenv(key, value)
  env[key] = value
end

return M
