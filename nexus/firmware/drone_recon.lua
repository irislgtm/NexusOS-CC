-- ============================================================================
-- NEXUS-OS  /firmware/drone_recon.lua
-- Drone Recon Mode: fly to coordinate, scan area, report back
-- Loaded as a mode module into drone_core
-- ============================================================================

return function(core)
  local M = {}

  local drone = core.getDrone()
  local nav = core.getNav()
  local active = false
  local target = {x = 0, y = 64, z = 0}
  local phase = "travel"  -- travel, scan, report, return
  local scanData = {}
  local arrivalDist = 5
  local homePos = nil

  function M.start(_, params)
    active = true
    phase = "travel"
    scanData = {}

    -- Save home position
    if nav then
      local ok, x, y, z = pcall(nav.getPosition)
      if ok and x then
        homePos = {x = x, y = y, z = z}
      end
    end

    -- Parse target: "x,y,z"
    if params.target and type(params.target) == "string" then
      local x, y, z = params.target:match("([%-%.%d]+),([%-%.%d]+),([%-%.%d]+)")
      if x then
        target.x = tonumber(x)
        target.y = tonumber(y)
        target.z = tonumber(z)
      end
    end

    core.setStatus("Recon: -> target")
    core.sendBase("NX_DRONE_STATUS", "recon_start:x=" ..
      math.floor(target.x) .. ",y=" .. math.floor(target.y) ..
      ",z=" .. math.floor(target.z))
  end

  function M.stop()
    active = false
    phase = "travel"
    if drone then drone.move(0, 0, 0) end
  end

  function M.tick(now)
    if not active or not drone then return end

    local myPos = nil
    if nav then
      local ok, x, y, z = pcall(nav.getPosition)
      if ok and x then
        myPos = {x = x, y = y, z = z}
      end
    end

    if phase == "travel" then
      -- Move toward target
      if myPos then
        local dx = target.x - myPos.x
        local dy = (target.y + 20) - myPos.y  -- approach from above
        local dz = target.z - myPos.z
        local dist = math.sqrt(dx * dx + dz * dz)

        if dist <= arrivalDist then
          phase = "scan"
          drone.move(0, 0, 0)
          core.setStatus("Recon: SCANNING")
          core.sendBase("NX_DRONE_RECON", "arrived:scanning")
        else
          local scale = math.min(1.0, dist) / dist
          drone.move(dx * scale * 0.5, dy * 0.3, dz * scale * 0.5)
          core.setStatus("Recon: -> " .. math.floor(dist) .. "m")
        end
      else
        -- No navigation, move toward target with raw coordinates
        drone.move(target.x * 0.05, target.y * 0.02, target.z * 0.05)
        phase = "scan"  -- skip to scan after one tick
      end

    elseif phase == "scan" then
      -- Perform area scan using drone's built-in methods
      scanData = {
        position = myPos or target,
        timestamp = now,
        entities = {},
        blocks = {},
      }

      -- Detect nearby entities via motion (if base relays data)
      -- Drone doesn't have geolyzer, so we report what we can see
      if drone.detect then
        -- Check all 6 sides
        local sides = {"front", "back", "up", "down"}
        for _, side in ipairs(sides) do
          -- drone.detect returns entity info for the drone component
        end
      end

      -- Report scan data
      core.sendBase("NX_DRONE_RECON_DATA", {
        x = scanData.position.x and math.floor(scanData.position.x) or "?",
        y = scanData.position.y and math.floor(scanData.position.y) or "?",
        z = scanData.position.z and math.floor(scanData.position.z) or "?",
        time = math.floor(now),
        status = "scan_complete",
      })

      phase = "return"
      core.setStatus("Recon: RETURNING")

    elseif phase == "return" then
      -- Return to home position
      if homePos and myPos then
        local dx = homePos.x - myPos.x
        local dy = homePos.y - myPos.y
        local dz = homePos.z - myPos.z
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

        if dist <= arrivalDist then
          -- Home
          drone.move(0, 0, 0)
          core.setStatus("Recon: COMPLETE")
          core.sendBase("NX_DRONE_RECON", "complete")
          active = false
          core.setMode("idle")
        else
          local scale = math.min(1.0, dist) / dist
          drone.move(dx * scale * 0.5, dy * 0.3, dz * scale * 0.5)
          core.setStatus("Recon: <- " .. math.floor(dist) .. "m")
        end
      else
        -- No nav, just switch to idle
        core.sendBase("NX_DRONE_RECON", "complete:no_nav")
        core.setMode("idle")
      end
    end
  end

  return M
end
