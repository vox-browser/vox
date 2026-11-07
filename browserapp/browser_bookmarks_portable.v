module main

import gg
import ui2

$if !vox_ui2 ? {
	fn (mut app BrowserApp) handle_portable_bookmark_event(event &gg.Event) bool {
		$if linux || ui2_custom_rendering ? {
			mut owner := unsafe { address_bar_owner }
			owner.app = app
			if ui2.embedded_elements_event(event) {
				if event.typ == .mouse_down { app.suppress_next_click_for_chrome = true }
				request_browser_frame()
				return true
			}
		}
		return false
	}
}
