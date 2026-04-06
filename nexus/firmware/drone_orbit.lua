-- ============================================================================
-- NEXUS-OS  /firmware/drone_orbit.lua
-- Drone Orbit Mode: circle a target coordinate at configurable radius
-- Loaded as a mode module into drone_core
-- ============================================================================

return function(core)
  local M = {}

  local drone = core.getDrone()
  local nav = core.getNav()
  local active = false
  local center = {x = 0, y = 0, z = 0}
  local radius = 15
  local altitude = 20
  local speed = 0.15  -- radians per tick
  local angle = 0
  local orbitCount = 0

  function M.start(_, params)
    active = true
    angle = 0
    orbitCount = 0

    -- Parse parameters: "x,y,z,radius" or "radius" (orbit current pos)
    if params.params and type(params.params) == "string" then
      local parts = {}
      for p in params.params:gmatch("[^,]+") do
        parts[#parts + 1] = tonumber(p)
      end
      if #parts >= 4 then
        center.x = parts[1]
        center.y = parts[2]
        center.z = parts[3]
        radius = parts[4]
      elseif #parts >= 1 then
        radius = parts[1]
        -- Use current position as center
        if nav then
          local ok, x, y, z = pcall(nav.getPosition)
          if ok and x then
            center.x = x
            center.y = y
            center.z = z
          end
        end
      end
    end

    if params.altitude then
      altitude = tonumber(params.altitude) or 20
    end

    core.setStatus("Orbit: r=" .. radius)
    core.sendBase("NX_DRONE_STATUS", "orbit_start:r=" .. radius ..
      ",cx=" .. math.floor(center.x) ..
      ",cz=" .. math.floor(center.z))
  end

  function M.stop()
    active = false
    if drone then drone.move(0, 0, 0) end
  end

  function M.tick(now)
    if not active or not drone then return end

    -- Advance angle
    angle = angle + speed
    if angle >= 2 * math.pi then
      angle = angle - 2 * math.pi
      orbitCount = orbitCount + 1
      core.sendBase("NX_DRONE_ORBIT", {
        orbits = orbitCount,
        radius = radius,
        cx = math.floor(center.x),
        cz = math.floor(center.z),
      })
    end

    -- Calculate target position on circle
    local targetX = center.x + math.cos(angle) * radius
    local targetZ = center.z + math.sin(angle) * radius
    local targetY = center.y + altitude

    -- Move toward target
    local myPos = nil
    if nav then
      local ok, mx, my, mz = pcall(nav.getPosition)
      if ok and mx then
        myPos = {x = mx, y = my, z = mz}
      end
    end

    if myPos then
      local dx = targetX - myPos.x
      local dy = targetY - myPos.y
      local dz = targetZ - myPos.z
      drone.move(dx * 0.5, dy * 0.5, dz * 0.5)

      core.setStatus(string.format("Orbit: %d° r=%d #%d",
        math.floor(math.deg(angle)), radius, orbitCount))
    else
      -- No navigation, use raw circular motion
      local dx = math.cos(angle) * radius * 0.1
      local dz = math.sin(angle) * radius * 0.1
      drone.move(dx, 0, dz)
      core.setStatus("Orbit: ~" .. math.floor(math.deg(angle)) .. "°")
    end
  end

  return M
end
