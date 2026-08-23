-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Drop default webapp shortcuts I don't use.
-- Was: Google Maps
hl.unbind("SUPER + SHIFT + S")
-- Was: New email
hl.unbind("SUPER + SHIFT + ALT + E")
-- Was: Zoom in / Reset zoom
hl.unbind("SUPER + CTRL + Z")
hl.unbind("SUPER + CTRL + ALT + Z")

-- Vicinae replaces the Omarchy menu launcher on SUPER+SPACE.
-- Was: Omarchy menu
hl.unbind("SUPER + SPACE")
o.bind("SUPER + SPACE", "Launch apps (Vicinae)", "vicinae toggle")

-- Personal task apps.
o.bind("SUPER + ALT + T", "Dooing Claude backlog", "omarchy-launch-dooing-claude")
o.bind("SUPER + SHIFT + T", "Taskle", "omarchy-launch-taskle")
