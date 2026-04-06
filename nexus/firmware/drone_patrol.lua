-- ============================================================================
-- NEXUS-OS  /firmware/drone_patrol.lua
-- Drone Patrol Mode: cycle through waypoints, report contacts
-- Loaded as a mode module into drone_core
-- ============================================================================

return function(core)
  local M = {}

  local drone = core.getDrone()
  local nav = core.getNav()
  local waypoints = {}
  local currentWP = 1
  local active = false
  local arrivalDist = 3
  local patrolSpeed = 0.6
  local moveTimer = 0
  local dwellTime = 5 -- seconds to pause at each waypoint
  local dwelling = false
  local dwellStart = 0

  function M.start(_, params)
    active = true
    currentWP = 1
    dwelling = false

    -- Parse waypoints from params
    -- Format: "x1,y1,z1;x2,y2,z2;..." or use navigation waypoints
    if params.waypoints and type(params.waypoints) == "string" then
      for wp in params.waypoints:gmatch("[^;]+") do
        local x, y, z = wp:match("([%-%.%d]+),([%-%.%d]+),([%-%.%d]+)")
        if x then
          waypoints[#waypoints + 1] = {
            x = tonumber(x),
            y = tonumber(y),
            z = tonumber(z),
          }
        end
      end
    end

    -- Fallback: get navigation waypoints if available
    if #waypoints == 0 and nav then
      local ok, wps = pcall(nav.getWaypoints, 200)
      if ok and wps then
        for _, wp in ipairs(wps) do
          local pos = wp.position or wp
          if pos.x then
            waypoints[#waypoints + 1] = {
              x = pos.x, y = pos.y, z = pos.z,
              label = wp.label or ("WP" .. #waypoints + 1),
            }
          end
        end
      end
    end

    -- Fallback: generate a simple square patrol pattern
    if #waypoints == 0 then
      local r = 30
      waypoints = {
        {x = r,  y = 15, z = 0,  label = "N"},
        {x = 0,  y = 15, z = r,  label = "E"},
        {x = -r, y = 15, z = 0,  label = "S"},
        {x = 0,  y = 15, z = -r, label = "W"},
      }
    end

    core.setStatus("Patrol: " .. #waypoints .. " WPs")
    core.sendBase("NX_DRONE_STATUS", "patrol_start:wp=" .. #waypoints)
  end

  function M.stop()
    active = false
    waypoints = {}
    if drone then drone.move(0, 0, 0) end
  end

  function M.tick(now)
    if not active or not drone or #waypoints == 0 then return end

    -- Dwelling at waypoint
    if dwelling then
      if now - dwellStart >= dwellTime then
        dwelling = false
        currentWP = (currentWP % #waypoints) + 1
        core.sendBase("NX_DRONE_PATROL", {
          wp = currentWP,
          label = waypoints[currentWP].label or ("WP" .. currentWP),
          total = #waypoints,
        })
      end
      return
    end

    -- Move toward current waypoint
    local wp = waypoints[currentWP]
    if not wp then return end

    -- Calculate movement
    local myPos = nil
    if nav then
      local ok, mx, my, mz = pcall(nav.getPosition)
      if ok and mx then
        myPos = {x = mx, y = my, z = mz}
      end
    end

    if myPos then
      local dx = wp.x - myPos.x
      local dy = wp.y - myPos.y
      local dz = wp.z - myPos.z
      local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

      if dist <= arrivalDist then
        -- Arrived at waypoint
        dwelling = true
        dwellStart = now
        drone.move(0, 0, 0) -- stop
        core.setStatus("Patrol: @ " .. (wp.label or ("WP" .. currentWP)))
        core.sendBase("NX_DRONE_PATROL_ARRIVE", {
          wp = currentWP,
          label = wp.label or ("WP" .. currentWP),
          x = math.floor(myPos.x),
          y = math.floor(myPos.y),
          z = math.floor(myPos.z),
        })
      else
        -- Move toward waypoint
        local scale = math.min(patrolSpeed, dist) / dist
        drone.move(dx * scale, dy * scale, dz * scale)
        core.setStatus("Patrol: -> " .. (wp.label or ("WP" .. currentWP)) .. " " .. math.floor(dist) .. "m")
      end
    else
      -- No navigation, use raw relative coords
      moveTimer = moveTimer + 0.5
      if moveTimer >= 3 then
        moveTimer = 0
        drone.move(wp.x * 0.1, wp.y * 0.1, wp.z * 0.1)
        -- Cycle through waypoints on timer without distance check
        if moveTimer == 0 then
          dwelling = true
          dwellStart = now
        end
      end
    end
  end

  return M
end
