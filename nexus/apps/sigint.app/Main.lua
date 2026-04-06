-- ============================================================================
-- NEXUS-OS  /apps/sigint.app/Main.lua
-- Signal Intelligence: modem scanner, packet log, frequency chart
-- ============================================================================

return function(window, body, workspace)
  local ListView = require("gui.listview")
  local TabBar   = require("gui.tabbar")
  local Chart    = require("gui.chart")
  local Button   = require("gui.button")
  local Widget   = require("gui.widget")
  local T        = require("theme")

  local modem
  local hasModem, _m = pcall(require, "modem")
  if hasModem then modem = _m end

  local bw, bh = body.width, body.height

  -- Packet log
  local packets = {}
  local MAX_PACKETS = 500
  local portStats = {}   -- port → count
  local knownAddrs = {}  -- addr → { firstSeen, lastSeen, count }
  local scanning = false
  local scanPorts = {}   -- ports we opened for scanning

  -- Tabs
  local tabs = TabBar.new(0, 0, bw, { "Packet Feed", "Freq Chart", "Known Nodes" })
  body:addChild(tabs)

  -- ── Packet Feed ───────────────────────────────────────────────────────
  local packetList = ListView.new(0, 2, bw, bh - 6, {
    { name = "Time",   width = 8 },
    { name = "From",   width = 12 },
    { name = "Port",   width = 6 },
    { name = "Dist",   width = 6 },
    { name = "Preview", width = bw - 36 },
  })
  body:addChild(packetList)

  -- ── Freq Chart ────────────────────────────────────────────────────────
  local freqChart = Chart.new(2, 3, bw - 4, bh - 6, "bar")
  freqChart.label = "Messages per Port"
  freqChart.visible = false
  body:addChild(freqChart)

  -- ── Known Nodes ───────────────────────────────────────────────────────
  local nodeList = ListView.new(0, 2, bw, bh - 6, {
    { name = "Address",    width = 14 },
    { name = "First Seen", width = 10 },
    { name = "Last Seen",  width = 10 },
    { name = "Packets",    width = 8 },
  })
  nodeList.visible = false
  body:addChild(nodeList)

  -- Tab switching
  tabs.onTabChanged = function(idx)
    packetList.visible = (idx == 1)
    freqChart.visible  = (idx == 2)
    nodeList.visible   = (idx == 3)
    body:invalidate()
  end

  -- ── Scan Controls ─────────────────────────────────────────────────────
  local scanBtn = Button.new(0, bh - 3, 14, 1, " ◎ Start Scan", function()
    if scanning then
      -- Stop
      scanning = false
      scanBtn.text = " ◎ Start Scan"
      for _, port in ipairs(scanPorts) do
        if modem then modem.close(port) end
      end
      scanPorts = {}
    else
      -- Start scanning common ports
      if not modem or not modem.isAvailable() then return end
      scanning = true
      scanBtn.text = " ■ Stop Scan "
      -- Open a range of ports
      for port = 1, 100 do
        modem.open(port)
        scanPorts[#scanPorts + 1] = port
      end
      -- Also open high ports
      for _, port in ipairs({ 443, 1000, 5000, 9100, 9101, 9102, 9200, 65535 }) do
        modem.open(port)
        scanPorts[#scanPorts + 1] = port
      end
    end
    body:invalidate()
  end)
  body:addChild(scanBtn)

  local clearBtn = Button.new(16, bh - 3, 10, 1, " Clear ", function()
    packets = {}
    portStats = {}
    knownAddrs = {}
    packetList:setData({})
    nodeList:setData({})
    freqChart:setValues({})
    body:invalidate()
  end)
  body:addChild(clearBtn)

  local countLabel = Widget.new(28, bh - 3, 20, 1)
  countLabel.draw = function(self, screen)
    local ax, ay = self:absolutePosition()
    screen.drawText(ax, ay, "Pkts: " .. #packets,
      T.get("text_secondary"), T.get("window_bg"))
  end
  body:addChild(countLabel)

  -- ── Packet capture handler ────────────────────────────────────────────
  local function onModemMessage(_, localAddr, remoteAddr, port, distance, ...)
    if not scanning then return end
    local now = computer.uptime()

    -- Build payload preview
    local parts = { ... }
    local preview = ""
    for i, p in ipairs(parts) do
      if type(p) == "string" then
        preview = preview .. p:sub(1, 40)
      else
        preview = preview .. tostring(p)
      end
      if i < #parts then preview = preview .. " | " end
    end
    preview = preview:sub(1, bw - 36)

    -- Store packet
    local pkt = {
      time = now,
      from = remoteAddr,
      port = port,
      distance = distance or 0,
      preview = preview,
      payload = parts,
    }
    packets[#packets + 1] = pkt
    if #packets > MAX_PACKETS then table.remove(packets, 1) end

    -- Port stats
    portStats[port] = (portStats[port] or 0) + 1

    -- Known addresses
    local shortAddr = remoteAddr:sub(1, 12)
    if not knownAddrs[shortAddr] then
      knownAddrs[shortAddr] = { firstSeen = now, lastSeen = now, count = 0 }
    end
    knownAddrs[shortAddr].lastSeen = now
    knownAddrs[shortAddr].count = knownAddrs[shortAddr].count + 1

    -- Update views
    -- Packet list
    local rows = {}
    for i = #packets, math.max(1, #packets - 100), -1 do
      local p = packets[i]
      rows[#rows + 1] = {
        string.format("%.1f", p.time),
        (p.from or "?"):sub(1, 10) .. "..",
        tostring(p.port),
        string.format("%.0f", p.distance),
        p.preview,
      }
    end
    packetList:setData(rows)

    -- Freq chart
    local chartVals = {}
    local sortedPorts = {}
    for p in pairs(portStats) do sortedPorts[#sortedPorts + 1] = p end
    table.sort(sortedPorts)
    for _, p in ipairs(sortedPorts) do
      chartVals[#chartVals + 1] = portStats[p]
    end
    freqChart:setValues(chartVals)

    -- Node list
    local nodeRows = {}
    for addr, info in pairs(knownAddrs) do
      nodeRows[#nodeRows + 1] = {
        addr,
        string.format("%.0f", info.firstSeen),
        string.format("%.0f", info.lastSeen),
        tostring(info.count),
      }
    end
    nodeList:setData(nodeRows)

    body:invalidate()
  end

  -- Install listener
  if _G.event then
    _G.event.listen("modem_message", onModemMessage)
  end

  -- Header
  local header = Widget.new(0, 0, bw, 1)
  header.draw = function(self, screen)
    local ax, ay = self:absolutePosition()
    screen.drawText(ax, ay, "⚡ SIGNAL INTELLIGENCE", T.get("accent"), T.get("window_bg"))
    local status = modem and modem.isAvailable() and "MODEM ONLINE" or "NO MODEM"
    local sColor = modem and modem.isAvailable() and T.get("alert_ok") or T.get("alert_critical")
    screen.drawText(ax + 25, ay, status, sColor, T.get("window_bg"))
    if scanning then
      screen.drawText(ax + 42, ay, "● SCANNING", T.get("alert_warn"), T.get("window_bg"))
    end
  end
  body:addChild(header)
end
