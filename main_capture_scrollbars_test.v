module main

import dom

fn test_chromium_capture_ignores_incidental_overlay_scrollbar_hover() {
	$if macos {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		mut app := BrowserApp{document: document, screenshot_path: 'capture.png'}
		app.overlay_scrollbars.hovered = true
		app.prepare_overlay_scrollbars()
		if app.overlay_scrollbars.enabled {
			assert app.overlay_scrollbars.paint_opacity == 0
			app.screenshot_path = ''
			app.prepare_overlay_scrollbars()
			assert app.overlay_scrollbars.paint_opacity == 1
		}
	}
}
