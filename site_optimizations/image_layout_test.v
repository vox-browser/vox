module main

import dom

fn test_image_layout_batching_is_scoped_to_github_http_documents() {
	for address in ['https://github.com/vlang/v', 'http://GITHUB.COM./vlang/v'] {
		assert site_batches_image_completion_layout(address)
	}
	for address in ['https://github.com.example/vlang/v', 'https://github.com@elsewhere.test/',
		'https://example.test/?github.com', 'file:///github.com', 'about:blank'] {
		assert !site_batches_image_completion_layout(address)
	}
}

fn test_github_image_batch_keeps_dirty_geometry_until_frame_completion() {
	mut document := parse_browser_navigation_document('<!doctype html><style>html,body{margin:0}</style><div id="target" style="width:30px;height:20px"></div>',
		dom.URL{value:'https://github.com/vlang/v'}, none)
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{width:320,height:200})
	mut app := &BrowserApp{document:document, viewport_width:320, viewport_height:200}
	app.relayout(320, 312)
	mut target := document.get_element_by_id('target')?
	target.set_attribute_value('style', 'width:80px;height:20px')
	mut target_node := target.as_node()
	target_node.set_needs_layout_update(.html_image_element_update_the_image_data)
	app.frame_preparation_depth = 1
	assert !document.layout_is_up_to_date()
	assert app.defer_site_image_completion_layout() == !disable_github_image_layout_batching
	assert !document.layout_is_up_to_date()
	// A synchronous author query can commit geometry before the frame ends.
	document.update_layout(.debugging)
	app.adopt_current_document_geometry()
	box := app.root_box.find_box(i64(target.as_node().unique_id()))?
	assert box.border_box().width == 80 * document.layout_coordinate_scale()
	assert document.layout_is_up_to_date()
	assert app.paint_commands_pending == !disable_github_image_layout_batching
}

fn test_image_batch_retains_synchronous_boundaries_outside_frames_and_initial_layout() {
	mut document := parse_browser_navigation_document('<!doctype html><input id="editor">',
		dom.URL{value:'https://github.com/vlang/v'}, none)
	defer { document.finalize() }
	mut app := &BrowserApp{document:document, viewport_width:320, viewport_height:200}
	assert !app.defer_site_image_completion_layout()
	app.frame_preparation_depth = 1
	app.initial_layout_pending = true
	assert !app.defer_site_image_completion_layout()
}
