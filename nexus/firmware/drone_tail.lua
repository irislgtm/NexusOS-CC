-- ============================================================================
-- NEXUS-OS  /firmware/drone_tail.lua
-- Drone Tail Mode: follow a target player using motion detection
-- Loaded as a mode module into drone_core
-- ============================================================================

return function(core)
  local M = {}

  local drone = core.getDrone()
  local nav = core.getNav()
  local target = nil
  local followDist = 8
  local altitude = 15
  local lastSeen = 0
  local searchTimer = 0
  local searchPattern = 0
  local active = false

  function M.start(_, params)
    target = params.target or "Player"
    if params.distance then
      followDist = tonumber(params.distance) or 8
    end
    active = true
    lastSeen = computer.uptime()
    core.setStatus("Tail: " .. target)
    core.sendBase("NX_DRONE_STATUS", "tailing:" .. target)
  end

  function M.stop()
    active = false
    target = nil
    if drone then drone.move(0, 0, 0) end
  end

  function M.tick(now)
    if not active or not drone then return end

    -- Use motion sensor if available (detect nearby entities)
    local detected = false
    local dx, dy, dz = 0, 0, 0

    -- Check for modem-relayed position data from base
    -- Base station can relay player positions from its motion sensor
    -- For now, use a search pattern when target not visible

    if now - lastSeen > 10 then
      -- Lost target, execute search pattern
      searchTimer = searchTimer + 0.5
      searchPattern = searchPattern + 1
      local radius = math.min(searchPattern * 2, 32)
      local angle = (searchPattern * 0.7) % (2 * math.pi)
      dx = math.cos(angle) * radius * 0.3
      dz = math.sin(angle) * radius * 0.3
      dy = altitude * 0.1 -- maintain altitude

      drone.move(dx, dy, dz)
      core.setStatus("Tail: SEARCHING " .. target)

      if searchPattern > 50 then
        -- Give up, report lost
        core.sendBase("NX_DRONE_ALERT", "target_lost:" .. target)
        core.setMode("idle")
        return
      end
    end
  end

  -- Called when base relays target position
  function M.onTargetPosition(x, y, z)
    if not active or not drone then return end
    lastSeen = computer.uptime()
    searchPattern = 0

    -- Calculate relative movement
    local myPos = nil
    if nav then
      local ok, mx, my, mz = pcall(nav.getPosition)
      if ok and mx then
        myPos = {x = mx, y = my, z = mz}
      end
    end

    if myPos then
      local dx = x - myPos.x
      local dy = (y + altitude) - myPos.y -- stay above target
      local dz = z - myPos.z
      local dist = math.sqrt(dx * dx + dz * dz)

      if dist > followDist then
        -- Move toward target but stop at followDist
        local scale = (dist - followDist) / dist
        drone.move(dx * scale, dy, dz * scale)
        core.setStatus("Tail: -> " .. target .. " " .. math.floor(dist) .. "m")
      else
        core.setStatus("Tail: @ " .. target .. " " .. math.floor(dist) .. "m")
      end
    else
      -- No nav, use raw offsets — move toward broadcast position
      drone.move(x * 0.3, altitude * 0.1, z * 0.3)
      core.setStatus("Tail: ~> " .. target)
    end

    core.sendBase("NX_DRONE_TELEMETRY_TAIL", {
      target = target,
      lastSeen = lastSeen,
      searching = false,
    })
  end

  return M
end
