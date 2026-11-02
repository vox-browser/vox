module layout

import dom
import html
import platform

fn test_native_viewport_scrolling_reuses_recording_storage() {
	url := dom.URL{value: 'https://scroll-storage.example/'}
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>html,body{margin:0}p{height:30px}</style>'
		+ '<p>scrolling text and <a href="/">a link</a></p>'.repeat(80))
	allocations.finish()
	defer {
		handle := document.layout_engine_handle()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		retire_native_document_layout(handle)
		document.release_native_storage()
	}
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut plan := ChromiumRasterLayerPlan{}
	mut before_document := i64(0)
	mut before_base := i64(0)
	for frame in 0 .. 120 {
		y := f64((frame % 20) * 20)
		document.set_viewport_rect(dom.Rect{0, y, 320, 200})
		list := document.record_viewport_display_list() or { panic('missing scroll recording') }
		commands := display_list_commands(list)
		update_chromium_raster_layer_plan_for_viewport(document, commands, 2,
			LayoutRect{0, y, 320, 200}, mut plan)
		if frame == 39 {
			before_document = document.native_storage().arena.usage().used
			before_base = platform.thread_arena_usage().used
		}
	}
	$if prealloc {
		document_growth := document.native_storage().arena.usage().used - before_document
		base_growth := platform.thread_arena_usage().used - before_base
		assert document_growth < 64 * 1024, '${document_growth} document bytes retained after warmup'
		assert base_growth < 64 * 1024, '${base_growth} persistent bytes retained after warmup'
	}
}
