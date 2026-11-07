module main

import browserbookmarks
import dom
import html
import layout

fn test_initial_viewport_uses_loaded_bookmark_and_debug_chrome() {
	for visible in [false, true] {
		for debug in [false, true] {
			mut store := browserbookmarks.open('')!
			store.visible = visible
			mut app := BrowserApp{bookmarks: store, chrome_debug: debug}
			expected := 1065 - 84 - if visible { 28 } else { 0 } - if debug { 32 } else { 0 }
			app.prepare_initial_viewport(1065, 0)
			assert app.viewport_height == expected
			assert app.viewport_height + app.chrome_height() == 1065
			app.prepare_initial_viewport(1065, 600)
			assert app.viewport_height == 600
			app.prepare_initial_viewport(1, 0)
			assert app.viewport_height == 1
		}
	}
}

fn test_visible_bookmark_bar_does_not_require_a_second_initial_document_layout() {
	mut store := browserbookmarks.open('')!
	store.visible = true
	mut app := BrowserApp{bookmarks: store, viewport_width: 1708}
	app.prepare_initial_viewport(1065, 0)
	assert app.viewport_height == 953
	u := dom.URL{value: 'https://initial-viewport.test/'}
	mut document := html.create_navigation_document(u, u.origin(), none)!
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>html,body{margin:0}div{height:100vh}</style><div id="viewport">Initial geometry</div>')
	allocations.finish()
	defer {
		handle := document.layout_engine_handle()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		layout.retire_native_document_layout(handle)
		document.release_native_storage()
	}
	layout.enable_native_paint_tree_storage(document)
	_ = layout.layout_document_typed_in_viewport(document, f64(app.viewport_width), f64(app.viewport_height))
	generation := document.layout_pass_generation
	assert generation > 0
	assert document.get_element_by_id('viewport')?.get_bounding_client_rect().height == 953
	first := document.layout_engine_handle()
	// The first native frame now requests the same viewport as navigation.
	_ = layout.layout_document_typed_in_viewport(document, 1708, f64(1065 - app.chrome_height()))
	assert document.layout_engine_handle() == first
	assert document.layout_pass_generation == generation
}
