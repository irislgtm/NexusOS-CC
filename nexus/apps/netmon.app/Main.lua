-- ============================================================================
-- NEXUS-OS  /apps/netmon.app/Main.lua
-- Network Topology Monitor: discovered nodes, traffic stats
-- ============================================================================

return function(window, body, workspace)
  local ListView = require("gui.listview")
  local Chart    = require("gui.chart")
  local Button   = require("gui.button")
  local Widget   = require("gui.widget")
  local T        = require("theme")
  local net      = require("net")
  local modem    = require("modem")

  local bw, bh = body.width, body.height

  -- Node list
  local nodeList = ListView.new(0, 2, bw, bh - 8, {
    { name = "Name",     width = 14 },
    { name = "Address",  width = 14 },
    { name = "Distance", width = 10 },
    { name = "Age",      width = 8 },
  })
  body:addChild(nodeList)

  -- Traffic chart
  local trafficChart = Chart.new(2, bh - 5, bw - 4, 4, "sparkline")
  trafficChart.label = "Nodes"
  body:addChild(trafficChart)

  -- Discover button
  local discoverBtn = Button.new(0, bh - 1, 14, 1, " ◎ Discover ", function()
    net.discover()
  end)
  body:addChild(discoverBtn)

  -- Refresh
  local function refresh()
    local nodes = net.getNodes()
    local rows = {}
    for _, node in ipairs(nodes) do
      rows[#rows + 1] = {
        node.name or "?",
        (node.address or "?"):sub(1, 12) .. "..",
        string.format("%.0f", node.distance or 0),
        string.format("%.0fs", node.age or 0),
      }
    end
    nodeList:setData(rows)
    trafficChart:pushValue(#nodes)
    body:invalidate()
  end

  if _G.event then
    _G.event.timer(3, refresh, math.huge)
    _G.event.listen("net_discovery", function() refresh() end)
  end

  -- Header
  local header = Widget.new(0, 0, bw, 1)
  header.draw = function(self, screen)
    local ax, ay = self:absolutePosition()
    screen.drawText(ax, ay, "⊞ NETWORK MONITOR", T.get("accent"), T.get("window_bg"))
    local addr = modem.getAddress()
    if addr then
      screen.drawText(ax + 22, ay, "Local: " .. addr:sub(1, 12),
        T.get("text_muted"), T.get("window_bg"))
    end
  end
  body:addChild(header)

  refresh()
end
