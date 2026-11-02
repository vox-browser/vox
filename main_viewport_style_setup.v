module main

import dom
import os

const retain_late_viewport_setup = os.getenv('VOX_RETAIN_LATE_VIEWPORT_SETUP') != ''
const viewport_style_setup_diagnostics = os.getenv('VOX_VIEWPORT_STYLE_SETUP_DIAGNOSTICS') != ''

// Native layout-scale selection can resolve author styles for SVG/embedded
// content. Install the viewport before that first style consumer, just as the
// layout entry point does before its cascade. Keep the existing scroll origin.
fn (mut app BrowserApp) install_viewport_before_style_query(width int, height int) {
	if retain_late_viewport_setup || app.document == unsafe { nil } { return }
	before := app.document.viewport_rect()
	viewport := dom.Rect{
		x:      before.x
		y:      before.y
		width:  f64(width) / app.page_zoom
		height: f64(height) / app.page_zoom
	}
	if before.width == viewport.width && before.height == viewport.height { return }
	app.document.set_viewport_rect(viewport)
	// Preinstalling the rectangle must not hide the resize from the typed
	// layout entry point, whose own old/new viewport comparison now matches.
	app.document.set_needs_full_style_update(true)
	app.document.set_needs_full_layout_tree_update(true)
	if viewport_style_setup_diagnostics {
		eprintln('Vox viewport style setup: installed final viewport before native style query; document=${app.document.url.serialize()}; from=${before.width},${before.height}; to=${viewport.width},${viewport.height}')
	}
}
