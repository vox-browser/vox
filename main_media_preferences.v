module main

import page

fn C.native_prefers_reduced_transparency() int

fn configure_browser_media_preferences(mut model page.Page, native_window bool) {
	$if macos {
		if native_window {
			model.set_prefers_reduced_transparency(C.native_prefers_reduced_transparency() != 0)
		}
	}
}
