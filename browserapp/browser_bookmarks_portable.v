module main

import gg
import sokol.sapp
import ui2

$if !vox_ui2 ? {
	fn (mut app BrowserApp) handle_portable_bookmark_event(event &gg.Event) bool {
		$if linux || ui2_custom_rendering ? {
			mut owner := unsafe { address_bar_owner }
			owner.app = app
			if ui2.embedded_elements_event(event) {
				app.note_portable_chrome_input_consumed(event.typ)
				if event.typ == .mouse_down { app.suppress_next_click_for_chrome = true }
				request_browser_frame()
				return true
			}
		}
		return false
	}
}

// GG invokes its typed callbacks after event_fn, even when UI2 consumed the
// event. Keep the same keystroke from editing the address or firing twice.
fn (mut app BrowserApp) note_portable_chrome_input_consumed(kind sapp.EventType) {
	if kind == .key_down { app.suppress_next_key_for_chrome = true }
	if kind == .char { app.suppress_next_character_for_chrome = true }
}
