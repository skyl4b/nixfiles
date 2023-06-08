-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
config.color_scheme = 'catppuccin-mocha'
-- config.color_scheme = 'Ubuntu'
config.foreground_text_hsb = {  -- Multiplying factors
  hue = 1.0,
  saturation = 1.0,
  brightness = 1.0,
}

-- Set font
config.font = wezterm.font 'Maple Mono NF'
config.font_size = 12.0
config.freetype_load_target = "Light"

-- Never prompt confirmation
config.window_close_confirmation = 'NeverPrompt'

-- Set no tabs
config.enable_tab_bar = false

-- Remove title bar
config.window_decorations = "RESIZE"

-- Set webgpu front_end
-- config.front_end = "WebGpu"
config.front_end = "Software" -- Disable GPU rendering with nix

-- and finally, return the configuration to wezterm
return config

