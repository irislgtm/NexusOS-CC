-- ============================================================================
-- NEXUS-OS  /apps/tracker.app/Main.lua
-- Entity Tracker: live radar, threat classification, alert system
-- ============================================================================

return function(window, body, workspace)
  local Screen   = require("gui.screen")
  local Radar    = require("gui.radar")
  local ListView = require("gui.listview")
  local Button   = require("gui.button")
  local Progress = require("gui.progress")
  local TabBar   = require("gui.tabbar")
  local Chart    = require("gui.chart")
  local T        = require("theme")
  local ipc      = require("ipc")

  local motion
  local hasMotion, _m = pcall(require, "motion")
  if hasMotion then motion = _m end

  local bw, bh = body.width, body.height

  -- ── Tab bar ───────────────────────────────────────────────────────────
  local tabs = TabBar.new(0, 0, bw, { "Radar", "Contact List", "Alerts" })
  body:addChild(tabs)

  -- ── Radar View ────────────────────────────────────────────────────────
  local radarW = math.floor(bw * 0.6)
  local radarH = bh - 4
  local radar = Radar.new(0, 2, radarW, radarH, 32)
  body:addChild(radar)

  -- Entity stats sidebar
  local statsX = radarW + 1
  local statsW = bw - radarW - 1

  -- ── Contact List View ─────────────────────────────────────────────────
  local listView = ListView.new(0, 2, bw, bh - 4, {
    { name = "Name",     width = 16 },
    { name = "Class",    width = 10 },
    { name = "Dist",     width = 8 },
    { name = "Speed",    width = 8 },
    { name = "Last Seen", width = 12 },
  })
  listView.visible = false
  body:addChild(listView)

  -- ── Alert config ──────────────────────────────────────────────────────
  local alertLog = {}
  local alertsVisible = false

  -- ── Tab switching ─────────────────────────────────────────────────────
  tabs.onTabChanged = function(idx)
    radar.visible    = (idx == 1)
    listView.visible = (idx == 2)
    alertsVisible    = (idx == 3)
    body:invalidate()
  end

  -- ── Filter state ──────────────────────────────────────────────────────
  local filters = {
    player  = true,
    hostile = true,
    passive = false,
    unknown = true,
    drone   = true,
  }

  -- Filter buttons in sidebar
  local filterY = 3
  local filterBtns = {}
  for _, cls in ipairs({ "player", "hostile", "passive", "unknown", "drone" }) do
    local btn = Button.new(statsX, filterY, statsW - 1, 1,
      (filters[cls] and "●" or "○") .. " " .. cls,
      function(self)
        filters[cls] = not filters[cls]
        self.text = (filters[cls] and "●" or "○") .. " " .. cls
        body:invalidate()
      end)
    filterBtns[cls] = btn
    body:addChild(btn)
    filterY = filterY + 2
  end

  -- ── Refresh ticker ────────────────────────────────────────────────────
  local contactHistory = {}   -- for sparkline
  local refreshCount = 0

  local function refresh()
    if not motion then return end
    local contacts = motion.getContacts()

    -- Apply filters
    local filtered = {}
    for _, c in ipairs(contacts) do
      if filters[c.classification] then
        filtered[#filtered + 1] = c
      end
    end

    -- Update radar
    local radarEntities = {}
    for _, c in ipairs(filtered) do
      radarEntities[#radarEntities + 1] = {
        name = c.name,
        x = c.x,
        z = c.z,
        classification = c.classification,
        distance = c.distance,
      }
    end
    radar:setEntities(radarEntities)

    -- Update list view
    local rows = {}
    for _, c in ipairs(filtered) do
      rows[#rows + 1] = {
        c.name or "?",
        c.classification or "?",
        string.format("%.1f", c.distance or 0),
        string.format("%.1f", c.speed or 0),
        string.format("%.0fs", (computer.uptime() - (c.lastSeen or 0))),
      }
    end
    listView:setData(rows)

    -- Track history for sparkline
    refreshCount = refreshCount + 1
    if refreshCount % 5 == 0 then
      contactHistory[#contactHistory + 1] = #filtered
      if #contactHistory > 50 then table.remove(contactHistory, 1) end
    end

    -- Alert: new player detected
    for _, c in ipairs(contacts) do
      if c.classification == "player" then
        local alertKey = c.name .. "_" .. math.floor(computer.uptime() / 10)
        local found = false
        for _, a in ipairs(alertLog) do
          if a.key == alertKey then found = true; break end
        end
        if not found then
          alertLog[#alertLog + 1] = {
            key = alertKey,
            time = computer.uptime(),
            text = "PLAYER DETECTED: " .. (c.name or "unknown") ..
              " at " .. string.format("%.0f", c.distance or 0) .. "m",
          }
          -- Publish alert via IPC
          ipc.publish("alert", {
            type = "player_detected",
            name = c.name,
            distance = c.distance,
          })
        end
      end
    end

    body:invalidate()
  end

  -- Register timer for refresh
  if _G.event then
    _G.event.timer(1, refresh, math.huge)
  end

  -- Initial refresh
  refresh()
end
