module main

import dom
import os

const retain_initial_resource_viewport_after_style = os.getenv('VOX_RETAIN_INITIAL_RESOURCE_VIEWPORT_AFTER_STYLE') != ''
const initial_resource_viewport_diagnostics = os.getenv('VOX_INITIAL_RESOURCE_VIEWPORT_DIAGNOSTICS') != ''

// Device-layout eligibility resolves display on embedded content. Install the
// real CSS viewport first so media queries do not cascade at the default size
// and then invalidate that work before the first script or native frame.
fn (mut app BrowserApp) prepare_initial_resource_viewport() {
	previous := app.document.viewport_rect()
	before := if initial_resource_viewport_diagnostics {
		app.document.style_invalidation_counters().element_style_recomputations
	} else { u64(0) }
	if retain_initial_resource_viewport_after_style {
		app.sync_layout_coordinate_scale()
	}
	viewport_height := if app.viewport_height > 0 { app.viewport_height } else { initial_height - app.chrome_height() }
	app.document.set_viewport_rect(dom.Rect{
		width: f64(if app.viewport_width > 0 { app.viewport_width } else { initial_width }) / app.page_zoom
		height: f64(viewport_height) / app.page_zoom
	})
	if !retain_initial_resource_viewport_after_style {
		app.sync_layout_coordinate_scale()
	}
	if initial_resource_viewport_diagnostics && !retain_initial_resource_viewport_after_style
		&& previous != app.document.viewport_rect()
		&& app.document.style_invalidation_counters().element_style_recomputations > before {
		eprintln('Vox initial viewport: installed document viewport before device-layout style query; document=${app.document.url.serialize()}')
	}
}
