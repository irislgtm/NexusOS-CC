-- ============================================================================
-- NEXUS-OS  /lib/theme.lua
-- Color theme system with 3 schemes: matrix, phantom, ember
-- Hot-reloadable. All visual constants live here — zero hex literals elsewhere.
-- ============================================================================

local M = {}

----------------------------------------------------------------------------
-- Color Schemes
----------------------------------------------------------------------------

M.schemes = {

  matrix = {
    -- Desktop & general
    desktop_bg         = 0x000000,
    desktop_fg         = 0x00FF41,
    desktop_accent     = 0x003300,

    -- Windows
    window_bg          = 0x0A0A0A,
    window_border      = 0x00FF41,
    window_border_inactive = 0x004400,
    titlebar_bg        = 0x002200,
    titlebar_fg        = 0x00FF41,
    titlebar_active_bg = 0x004400,
    titlebar_active_fg = 0x00FF88,

    -- Text hierarchy
    text_primary       = 0x00FF88,
    text_secondary     = 0x008844,
    text_muted         = 0x004422,
    text_bright        = 0xFFFFFF,
    text_input         = 0xFFFFFF,

    -- Accent & highlight
    accent             = 0x00FFCC,
    highlight_bg       = 0x003300,
    highlight_fg       = 0x00FF41,
    selection_bg       = 0x005500,
    selection_fg       = 0xFFFFFF,

    -- Alerts / severity
    alert_info         = 0x0088FF,
    alert_warn         = 0xFFAA00,
    alert_error        = 0xFF2222,
    alert_critical     = 0xFF00FF,
    alert_success      = 0x00FF41,

    -- Buttons
    button_bg          = 0x001A00,
    button_fg          = 0x00FF41,
    button_hover_bg    = 0x003300,
    button_active_bg   = 0x005500,
    button_disabled_fg = 0x333333,

    -- Status bar / taskbar
    taskbar_bg         = 0x0A1A0A,
    taskbar_fg         = 0x00FF41,
    taskbar_active_bg  = 0x004400,

    -- Scrollbar
    scrollbar_bg       = 0x111111,
    scrollbar_fg       = 0x00FF41,

    -- Radar / tracker
    radar_bg           = 0x000000,
    radar_grid         = 0x002200,
    radar_ring         = 0x004400,
    radar_compass      = 0x00FF41,
    entity_player      = 0x00FFFF,
    entity_hostile     = 0xFF2222,
    entity_passive     = 0x00CC44,
    entity_unknown     = 0xFFAA00,
    entity_drone       = 0xFF00FF,

    -- Charts
    chart_bg           = 0x0A0A0A,
    chart_grid         = 0x1A1A1A,
    chart_line         = 0x00FF41,
    chart_fill         = 0x002200,
    chart_bar          = 0x00CC33,

    -- Borders / dividers
    border_bright      = 0x00FF41,
    border_dim         = 0x003300,
    divider            = 0x222222,

    -- Modal
    modal_overlay      = 0x000000,
    modal_bg           = 0x111111,
    modal_border       = 0x00FF41,
    modal_title        = 0x00FF88,
  },

  phantom = {
    desktop_bg         = 0x0D0D1A,
    desktop_fg         = 0xAA88FF,
    desktop_accent     = 0x1A1A33,

    window_bg          = 0x111122,
    window_border      = 0x8866FF,
    window_border_inactive = 0x333355,
    titlebar_bg        = 0x1A1133,
    titlebar_fg        = 0xAA88FF,
    titlebar_active_bg = 0x2A1A55,
    titlebar_active_fg = 0xCCAAFF,

    text_primary       = 0xCCAAFF,
    text_secondary     = 0x7766AA,
    text_muted         = 0x443366,
    text_bright        = 0xFFFFFF,
    text_input         = 0xFFFFFF,

    accent             = 0x00DDFF,
    highlight_bg       = 0x221144,
    highlight_fg       = 0xCCAAFF,
    selection_bg       = 0x332266,
    selection_fg       = 0xFFFFFF,

    alert_info         = 0x00BBFF,
    alert_warn         = 0xFFBB33,
    alert_error        = 0xFF3355,
    alert_critical     = 0xFF00AA,
    alert_success      = 0x44FF88,

    button_bg          = 0x1A1133,
    button_fg          = 0xAA88FF,
    button_hover_bg    = 0x2A1A55,
    button_active_bg   = 0x3A2A77,
    button_disabled_fg = 0x333333,

    taskbar_bg         = 0x0A0A15,
    taskbar_fg         = 0x8866CC,
    taskbar_active_bg  = 0x221144,

    scrollbar_bg       = 0x111122,
    scrollbar_fg       = 0x8866FF,

    radar_bg           = 0x0D0D1A,
    radar_grid         = 0x1A1A33,
    radar_ring         = 0x332266,
    radar_compass      = 0xAA88FF,
    entity_player      = 0x00DDFF,
    entity_hostile     = 0xFF3355,
    entity_passive     = 0x44FF88,
    entity_unknown     = 0xFFBB33,
    entity_drone       = 0xFF00AA,

    chart_bg           = 0x111122,
    chart_grid         = 0x1A1A33,
    chart_line         = 0xAA88FF,
    chart_fill         = 0x1A1133,
    chart_bar          = 0x8866CC,

    border_bright      = 0x8866FF,
    border_dim         = 0x332255,
    divider            = 0x222233,

    modal_overlay      = 0x000000,
    modal_bg           = 0x151528,
    modal_border       = 0x8866FF,
    modal_title        = 0xCCAAFF,
  },

  ember = {
    desktop_bg         = 0x0D0000,
    desktop_fg         = 0xFF4411,
    desktop_accent     = 0x1A0A00,

    window_bg          = 0x110808,
    window_border      = 0xFF4411,
    window_border_inactive = 0x552211,
    titlebar_bg        = 0x220E00,
    titlebar_fg        = 0xFF6633,
    titlebar_active_bg = 0x441A00,
    titlebar_active_fg = 0xFF8844,

    text_primary       = 0xFF8844,
    text_secondary     = 0xAA5533,
    text_muted         = 0x553322,
    text_bright        = 0xFFFFFF,
    text_input         = 0xFFFFFF,

    accent             = 0xFFCC00,
    highlight_bg       = 0x331100,
    highlight_fg       = 0xFF6633,
    selection_bg       = 0x552200,
    selection_fg       = 0xFFFFFF,

    alert_info         = 0x33AAFF,
    alert_warn         = 0xFFCC00,
    alert_error        = 0xFF1111,
    alert_critical     = 0xFF00FF,
    alert_success      = 0x33FF66,

    button_bg          = 0x1A0A00,
    button_fg          = 0xFF6633,
    button_hover_bg    = 0x331A00,
    button_active_bg   = 0x552A00,
    button_disabled_fg = 0x333333,

    taskbar_bg         = 0x0A0000,
    taskbar_fg         = 0xCC4411,
    taskbar_active_bg  = 0x331100,

    scrollbar_bg       = 0x110808,
    scrollbar_fg       = 0xFF4411,

    radar_bg           = 0x0D0000,
    radar_grid         = 0x1A0A00,
    radar_ring         = 0x441100,
    radar_compass      = 0xFF4411,
    entity_player      = 0x33AAFF,
    entity_hostile     = 0xFF1111,
    entity_passive     = 0x33FF66,
    entity_unknown     = 0xFFCC00,
    entity_drone       = 0xFF00FF,

    chart_bg           = 0x110808,
    chart_grid         = 0x1A0A0A,
    chart_line         = 0xFF4411,
    chart_fill         = 0x220E00,
    chart_bar          = 0xCC4411,

    border_bright      = 0xFF4411,
    border_dim         = 0x441100,
    divider            = 0x221111,

    modal_overlay      = 0x000000,
    modal_bg           = 0x151010,
    modal_border       = 0xFF4411,
    modal_title        = 0xFF8844,
  },
}

----------------------------------------------------------------------------
-- Active theme state
----------------------------------------------------------------------------

M.active = nil      -- reference to current scheme table
M.activeName = nil   -- name of current scheme

--- Get a single color by key from the active theme.
-- @param key  Color key (e.g. "desktop_bg", "entity_hostile")
-- @return number  Color value (0xRRGGBB)
function M.get(key)
  if M.active and M.active[key] then
    return M.active[key]
  end
  return 0xFFFFFF  -- ultimate fallback: white
end

--- Set the active color scheme by name.
-- @param name  "matrix", "phantom", or "ember"
-- @return boolean  success
function M.setScheme(name)
  if M.schemes[name] then
    M.active = M.schemes[name]
    M.activeName = name
    -- Nil unused scheme tables to free RAM (only one scheme is active at a time)
    for k in pairs(M.schemes) do
      if k ~= name then M.schemes[k] = nil end
    end
    return true
  end
  return false
end

--- Initialize the theme system. Loads from /etc/os.cfg or defaults to matrix.
function M.init()
  local themeName = "matrix"
  -- Try to load from config
  pcall(function()
    local config = require("config")
    local cfg = config.load("/etc/os.cfg")
    if cfg and cfg.theme and M.schemes[cfg.theme] then
      themeName = cfg.theme
    end
  end)
  M.setScheme(themeName)
end

--- Save current theme choice to /etc/os.cfg
function M.save()
  pcall(function()
    local config = require("config")
    local cfg = config.load("/etc/os.cfg") or {}
    cfg.theme = M.activeName
    config.save("/etc/os.cfg", cfg)
  end)
end

--- Reload the theme (re-read from config and trigger repaint).
-- Apps should listen for the "theme_changed" event.
function M.reload()
  M.init()
  if event and event.push then
    event.push("theme_changed", M.activeName)
  end
end

--- List available scheme names.
function M.list()
  return { "matrix", "phantom", "ember" }
end

return M
