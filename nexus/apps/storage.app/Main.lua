-- ============================================================================
-- NEXUS-OS  /apps/storage.app/Main.lua
-- Physical Storage Manager — AE2-like interface for chests via Transposers
-- Browse, search, sort, and transfer items across connected inventories
-- ============================================================================

return function(window, body, workspace)
  local ListView  = require("gui.listview")
  local TabBar    = require("gui.tabbar")
  local Button    = require("gui.button")
  local TextField = require("gui.textfield")
  local Widget    = require("gui.widget")
  local T         = require("theme")
  local Modal     = require("gui.modal")

  local storage
  local hasStorage, _s = pcall(require, "storage")
  if hasStorage then storage = _s end

  local bw, bh = body.width, body.height

  -- ── Tabs ──────────────────────────────────────────────────────────
  local tabs = TabBar.new(0, 0, bw, { "All Items", "Inventories", "Transfer" })
  body:addChild(tabs)

  -- ════════════════════════════════════════════════════════════════════
  -- TAB 1: All Items (AE2-style unified view)
  -- ════════════════════════════════════════════════════════════════════

  -- Search bar
  local searchField = TextField.new(0, 2, bw - 14, "Search items...")
  body:addChild(searchField)

  local searchBtn = Button.new(bw - 13, 2, 7, 1, "Find", function()
    refreshItemList()
  end)
  body:addChild(searchBtn)

  local refreshBtn = Button.new(bw - 5, 2, 5, 1, "Scan", function()
    if storage then
      storage.forceRefresh()
      refreshItemList()
      refreshInvList()
      body:invalidate()
    end
  end)
  body:addChild(refreshBtn)

  -- Summary bar
  local summaryWidget = Widget.new(0, 3, bw, 1)
  summaryWidget.draw = function(self, screen)
    if not self.visible then return end
    local ax, ay = self:absolutePosition()
    if not storage or not storage.isAvailable() then
      screen.drawText(ax + 1, ay, "No Transposers detected. Place Transposer blocks adjacent to chests.",
        T.get("alert_critical"), T.get("window_bg"))
      return
    end
    local s = storage.getSummary()
    local text = string.format(
      " %d types | %d items | %d containers | %d buses",
      s.totalTypes, s.totalItems, s.inventories, s.transposers)
    screen.drawText(ax + 1, ay, text, T.get("text_muted"), T.get("window_bg"))
  end
  body:addChild(summaryWidget)

  -- Item list
  local itemList = ListView.new(0, 4, bw, bh - 6, {
    { key = "label",  title = "Item",   width = bw - 30 },
    { key = "count",  title = "Count",  width = 10 },
    { key = "where",  title = "In",     width = 18 },
  })
  body:addChild(itemList)

  -- Status bar at bottom
  local statusWidget = Widget.new(0, bh - 1, bw, 1)
  statusWidget.draw = function(self, screen)
    if not self.visible then return end
    local ax, ay = self:absolutePosition()
    local uptime = computer and computer.uptime() or 0
    local scanAge = uptime - (storage and storage.getSummary().lastScan or 0)
    local text = string.format(" Last scan: %.0fs ago | Click item for details", scanAge)
    screen.drawText(ax, ay, text, T.get("text_muted"), T.get("window_bg"))
  end
  body:addChild(statusWidget)

  -- ════════════════════════════════════════════════════════════════════
  -- TAB 2: Inventories (per-container view)
  -- ════════════════════════════════════════════════════════════════════

  local invList = ListView.new(0, 2, bw, math.floor(bh / 2) - 2, {
    { key = "idx",   title = "#",         width = 4 },
    { key = "name",  title = "Container", width = bw - 32 },
    { key = "side",  title = "Side",      width = 8 },
    { key = "used",  title = "Used",      width = 8 },
    { key = "size",  title = "Size",      width = 8 },
  })
  invList.visible = false
  body:addChild(invList)

  local invDetailList = ListView.new(0, math.floor(bh / 2) + 1, bw, bh - math.floor(bh / 2) - 3, {
    { key = "slot",  title = "Slot",  width = 6 },
    { key = "label", title = "Item",  width = bw - 24 },
    { key = "count", title = "Count", width = 8 },
    { key = "max",   title = "Max",   width = 8 },
  })
  invDetailList.visible = false
  body:addChild(invDetailList)

  local invDetailLabel = Widget.new(0, math.floor(bh / 2), bw, 1)
  invDetailLabel.visible = false
  invDetailLabel._text = "Select a container above"
  invDetailLabel.draw = function(self, screen)
    if not self.visible then return end
    local ax, ay = self:absolutePosition()
    screen.drawHLine(ax, ay, bw, nil, T.get("border_dim"), T.get("window_bg"))
    screen.drawText(ax + 1, ay, " " .. self._text .. " ",
      T.get("accent"), T.get("window_bg"))
  end
  body:addChild(invDetailLabel)

  -- ════════════════════════════════════════════════════════════════════
  -- TAB 3: Transfer (move items between containers)
  -- ════════════════════════════════════════════════════════════════════

  -- Transfer state (declared before closures that capture these as upvalues)
  local xferFromIdx, xferToIdx, xferItemLabel
  local xferFromName, xferToName, xferStatus
  local selectedInvIdx

  local xferPanel = Widget.new(0, 2, bw, bh - 3)
  xferPanel.visible = false

  xferPanel.draw = function(self, screen)
    if not self.visible then return end
    local ax, ay = self:absolutePosition()
    local w = self.width

    screen.drawText(ax + 2, ay + 1, "Transfer Items Between Containers",
      T.get("accent"), T.get("window_bg"))

    -- Instructions
    screen.drawText(ax + 2, ay + 3, "From:", T.get("text_bright"), T.get("window_bg"))
    screen.drawText(ax + 2, ay + 4,
      xferFromName or "(select from Inventories tab)",
      T.get("text_primary"), T.get("window_bg"))

    screen.drawText(ax + 2, ay + 6, "To:", T.get("text_bright"), T.get("window_bg"))
    screen.drawText(ax + 2, ay + 7,
      xferToName or "(select from Inventories tab)",
      T.get("text_primary"), T.get("window_bg"))

    screen.drawText(ax + 2, ay + 9, "Item:", T.get("text_bright"), T.get("window_bg"))
    screen.drawText(ax + 2, ay + 10,
      xferItemLabel or "(click an item in All Items tab)",
      T.get("text_primary"), T.get("window_bg"))

    -- Transfer status
    if xferStatus then
      screen.drawText(ax + 2, ay + 14, xferStatus,
        T.get("accent"), T.get("window_bg"))
    end
  end
  body:addChild(xferPanel)

  -- Source/Dest selectors (buttons)
  local setFromBtn = Button.new(2, 4, 18, 1, "Set Source [F]", function()
    if not storage then return end
    local invs = storage.getInventories()
    if #invs == 0 then return end
    -- Use currently selected inventory from tab 2
    if selectedInvIdx then
      xferFromIdx = selectedInvIdx
      local inv = invs[selectedInvIdx]
      xferFromName = (inv.name ~= "" and inv.name or "Container") ..
        " (" .. inv.sideName .. ")"
      body:invalidate()
    end
  end)
  setFromBtn.visible = false
  body:addChild(setFromBtn)

  local setToBtn = Button.new(2, 6, 18, 1, "Set Dest [T]", function()
    if not storage then return end
    local invs = storage.getInventories()
    if #invs == 0 then return end
    if selectedInvIdx then
      xferToIdx = selectedInvIdx
      local inv = invs[selectedInvIdx]
      xferToName = (inv.name ~= "" and inv.name or "Container") ..
        " (" .. inv.sideName .. ")"
      body:invalidate()
    end
  end)
  setToBtn.visible = false
  body:addChild(setToBtn)

  local xferGoBtn = Button.new(2, 12, 18, 1, ">> Transfer >>", function()
    if not storage then return end
    if not xferFromIdx or not xferToIdx then
      xferStatus = "Set source and destination first!"
      body:invalidate()
      return
    end
    if not xferItemLabel then
      xferStatus = "Select an item first!"
      body:invalidate()
      return
    end
    local moved = storage.consolidateItem(xferItemLabel, xferToIdx)
    storage.forceRefresh()
    refreshItemList()
    refreshInvList()
    xferStatus = string.format("Moved %d x %s", moved, xferItemLabel)
    body:invalidate()
  end)
  xferGoBtn.visible = false
  body:addChild(xferGoBtn)

  -- ════════════════════════════════════════════════════════════════════
  -- Data Functions
  -- ════════════════════════════════════════════════════════════════════

  local function refreshItemList()
    if not storage or not storage.isAvailable() then
      itemList:setData({})
      return
    end
    local query = searchField.text
    if query == "Search items..." then query = "" end
    local items = storage.searchItems(query)
    local rows = {}
    for _, item in ipairs(items) do
      -- Summarize locations
      local locSet = {}
      for _, loc in ipairs(item.locations) do
        local n = loc.inv.name ~= "" and loc.inv.name or loc.inv.sideName
        locSet[n] = true
      end
      local locs = {}
      for n in pairs(locSet) do locs[#locs + 1] = n end
      rows[#rows + 1] = {
        label = item.label,
        count = tostring(item.totalCount),
        where = table.concat(locs, ","):sub(1, 18),
      }
    end
    itemList:setData(rows)
    body:invalidate()
  end

  local function refreshInvList()
    if not storage or not storage.isAvailable() then
      invList:setData({})
      return
    end
    local invs = storage.getInventories()
    local rows = {}
    for i, inv in ipairs(invs) do
      local used = 0
      for slot = 1, inv.size do
        if inv.slots[slot] then used = used + 1 end
      end
      rows[#rows + 1] = {
        idx  = tostring(i),
        name = inv.name ~= "" and inv.name or "Container",
        side = inv.sideName,
        used = tostring(used),
        size = tostring(inv.size),
      }
    end
    invList:setData(rows)
    body:invalidate()
  end

  -- Inventory detail: show contents when a container is selected
  invList.onSelect = function(self, rowIdx, rowData)
    if not storage or not rowData then return end
    selectedInvIdx = tonumber(rowData.idx)
    local contents = storage.getInventoryContents(selectedInvIdx)
    local rows = {}
    for _, entry in ipairs(contents) do
      rows[#rows + 1] = {
        slot  = tostring(entry.slot),
        label = entry.stack.label or entry.stack.name or "?",
        count = tostring(entry.stack.size or 0),
        max   = tostring(entry.stack.maxSize or 64),
      }
    end
    invDetailList:setData(rows)
    local inv = storage.getInventory(selectedInvIdx)
    invDetailLabel._text = (inv.name ~= "" and inv.name or "Container") ..
      " (" .. inv.sideName .. ") - " .. #contents .. " stacks"
    body:invalidate()
  end

  -- Item click: set transfer item
  itemList.onSelect = function(self, rowIdx, rowData)
    if rowData then
      xferItemLabel = rowData.label
    end
  end

  -- ── Tab Switching ─────────────────────────────────────────────────
  tabs.onTabChanged = function(self, idx)
    -- Tab 1: All Items
    searchField.visible   = (idx == 1)
    searchBtn.visible     = (idx == 1)
    refreshBtn.visible    = (idx == 1)
    summaryWidget.visible = (idx == 1)
    itemList.visible      = (idx == 1)
    statusWidget.visible  = (idx == 1)

    -- Tab 2: Inventories
    invList.visible        = (idx == 2)
    invDetailList.visible  = (idx == 2)
    invDetailLabel.visible = (idx == 2)

    -- Tab 3: Transfer
    xferPanel.visible = (idx == 3)
    setFromBtn.visible = (idx == 3)
    setToBtn.visible   = (idx == 3)
    xferGoBtn.visible  = (idx == 3)

    body:invalidate()
  end

  -- ── Initial Load ──────────────────────────────────────────────────
  if storage then
    storage.rescan()
    refreshItemList()
    refreshInvList()
  end

  -- Auto-refresh timer (every 5 seconds) — cancelled on window close
  local refreshTimerId
  if _G.event and storage then
    refreshTimerId = _G.event.timer(5, function()
      if not storage then return end
      storage.refresh()
      refreshItemList()
      refreshInvList()
    end, math.huge)
  end

  -- Cancel timer when window is closed to prevent ghost refreshes
  if window and window.meta then
    window.meta.app = window.meta.app or {}
    window.meta.app.close = function()
      if refreshTimerId and _G.event then
        _G.event.cancelTimer(refreshTimerId)
      end
    end
  end
end
