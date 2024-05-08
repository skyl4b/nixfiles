-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
config.color_scheme = "Catppuccin Mocha (Gogh)"
config.foreground_text_hsb = { -- Multiplying factors
	hue = 1.0,
	saturation = 1.0,
	brightness = 1.0,
}

-- Set background
config.window_background_opacity = 0.95

-- Set font
config.font = wezterm.font_with_fallback({
	{
		family = "Monaspace Krypton",
		harfbuzz_features = {
			"ss01=1",
			"ss02=1",
			"ss03=1",
			"ss04=1",
			"ss05=1",
			"ss06=1",
			"ss07=1",
			"ss08=1",
			"calt=1",
			"dlig=1",
		},
	},
	{ family = "Symbols Nerd Font Mono", scale = 0.90 },
})
config.font_size = 12.0
config.freetype_load_target = "Light"
config.use_cap_height_to_scale_fallback_fonts = true

-- Never prompt confirmation for closing
config.window_close_confirmation = "NeverPrompt"

-- Set no tabs
config.enable_tab_bar = false

-- Remove title bar
config.window_decorations = "RESIZE"

-- Set webgpu front_end
-- config.front_end = "WebGpu"
-- config.front_end = "Software" -- Disable GPU rendering with nix

-- Dont hide mouse
config.hide_mouse_cursor_when_typing = false

-- Set kitty keyboard protocol
config.enable_kitty_keyboard = true

-- Disable warnings about missing glyphs
config.warn_about_missing_glyphs = false

-- and finally, return the configuration to wezterm
return config
