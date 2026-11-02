module main

import css
import dom
import layout
import processmetrics

// Native capture already waits for fonts before publishing document pixels.
// Start the selected text faces before geometry, then let their HTML loading
// tasks settle. A forced geometry query still uses the ordinary layout hook.
fn (mut app BrowserApp) prepare_initial_document_layout(width int, height int) {
	native_capture := app.ctx != unsafe { nil } && app.ctx.native_rendering
		&& app.screenshot_path != ''
	if !native_capture || app.layout_tree_only || app.js_runtime != unsafe { nil }
		|| app.document.layout_root != unsafe { nil } {
		app.relayout(width, height)
		return
	}
	app.defer_initial_rendering_opportunity(true)
	viewport_width := if width > 0 { width } else { initial_width }
	viewport_height := if height > app.chrome_height() { height - app.chrome_height() } else { 1 }
	app.install_viewport_before_style_query(viewport_width, viewport_height)
	app.sync_layout_coordinate_scale()
	app.sync_window_activity()
	app.document.set_viewport_rect(dom.Rect{
		width: f64(viewport_width) / app.page_zoom
		height: f64(viewport_height) / app.page_zoom
	})
	layout.prepare_initial_document_fonts(app.document)
	if !app.initial_text_fonts_are_loading() {
		app.relayout(width, height)
		return
	}
	app.viewport_width = viewport_width
	app.viewport_height = viewport_height
	app.applied_page_zoom = app.page_zoom
	app.content_height = viewport_height
	app.initial_layout_pending = true
	app.paint_commands_pending = true
	if processmetrics.instructions_enabled() {
		eprintln('Vox initial font layout: capture geometry deferred until requested faces settle')
	}
	if app.frame_preparation_depth == 0 { request_browser_frame() }
}

fn (app &BrowserApp) initial_text_fonts_are_loading() bool {
	owner := app.document.existing_font_face_set() or { return false }
	if owner.font_face_set_record() == unsafe { nil } { return false }
	fonts := unsafe { &css.FontFaceSet(owner.font_face_set_record()) }
	// The ready promise also waits for layout. Only outstanding face requests
	// can hold initial geometry, otherwise capture would deadlock on itself.
	return fonts.loading_fonts().len > 0
}

fn (app &BrowserApp) initial_layout_waits_for_fonts() bool {
	return app.initial_layout_pending && app.document != unsafe { nil }
		&& app.initial_text_fonts_are_loading()
}

fn (mut app BrowserApp) defer_initial_rendering_opportunity(deferred bool) {
	if app.page_model == unsafe { nil } { return }
	mut client := app.page_model.client()
	client.defer_rendering_opportunities(deferred)
}
