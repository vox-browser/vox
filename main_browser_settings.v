module main

import gg

fn is_browser_settings_shortcut(key gg.KeyCode, modifier gg.Modifier) bool {
	return key == .comma && modifier == .super
}

fn show_browser_settings() {
	$if vox_ui2 ? {
		show_native_browser_settings()
	}
}
