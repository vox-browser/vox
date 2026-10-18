module layout

import html

fn test_hover_style_refreshes_retained_paint_without_an_embedder_relayout() {
	mut document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#link { display: block; width: 200px; height: 40px }
		.language :hover { background-color: #eaecf0 }
	</style><div class="language"><a id="link" href="#"><strong id="label">Italiano</strong></a></div>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	label := document.get_element_by_id('label') or { panic('missing label') }
	link := document.get_element_by_id('link') or { panic('missing link') }
	result := document_layout_result(document) or { panic('missing layout') }
	layout_handle := document.layout_engine_handle()
	state := result.state
	initial := display_list_commands(record_retained_display_list(mut document) or { panic('missing initial paint') })
	assert !initial.any(it.color == 'rgb(234 236 240)')

	document.set_hovered_node(label.as_node())
	document.update_layout(.event_handler_handle_mouse_move)
	assert document.layout_engine_handle() == layout_handle
	assert result.state == state
	hovered := display_list_commands(record_retained_display_list(mut document) or { panic('missing hovered paint') })
	assert hovered.any(it.color == 'rgb(234 236 240)' && it.width == 200)
	assert !initial.any(it.color == 'rgb(234 236 240)')
	assert !result.paint_tree_needs_style_update

	// A clean frame reuses its snapshot and phase caches.
	paint_children := result.paint_tree.children.data
	phase_commands := result.paint_phase_commands.data
	document.set_needs_repaint_with_invalidation(.paint_commands)
	_ = record_retained_display_list(mut document) or { panic('missing repeated paint') }
	assert result.paint_tree.children.data == paint_children
	assert result.paint_phase_commands.data == phase_commands

	document.set_hovered_node(none)
	document.update_layout(.event_handler_handle_mouse_move)
	unhovered := display_list_commands(record_retained_display_list(mut document) or { panic('missing unhovered paint') })
	assert !unhovered.any(it.color == 'rgb(234 236 240)')
	assert hovered.any(it.color == 'rgb(234 236 240)')
	assert document.layout_engine_handle() == layout_handle
	assert link.get_bounding_client_rect().width == 200
}

fn test_hover_style_refreshes_hit_testing_before_the_next_paint() {
	mut document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#link { width: 100px; height: 40px }
		#link:hover { transform: translateX(100px) }
	</style><div id="link"></div>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	link := document.get_element_by_id('link') or { panic('missing link') }
	assert (document.element_from_point(20, 20) or { panic('missing initial hit') }) == link
	layout_handle := document.layout_engine_handle()
	document.set_hovered_node(link.as_node())
	document.update_layout(.event_handler_handle_mouse_move)
	assert document.layout_engine_handle() == layout_handle
	assert (document.element_from_point(120, 20) or { panic('missing translated hit') }) == link
	assert (document.element_from_point(20, 20) or { panic('missing background hit') }) != link
	assert link.get_bounding_client_rect().x == 100
}

fn test_hover_background_and_underline_keep_unrelated_paint_caches() {
	mut document := html.parse_document('<!doctype html><style>
		html,body{margin:0}a{display:block;width:200px;text-decoration:none}
		a:hover{background:#eaecf0}a:hover strong{text-decoration:underline}
	</style><a id="link" href="#"><strong>Italiano</strong></a>'
		+ '<svg id="unrelated" width="100" height="100"><path d="M0 0H100V100H0Z" fill="green"/></svg>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	link := document.get_element_by_id('link') or { panic('missing link') }
	_ = record_retained_display_list(mut document) or { panic('missing initial paint') }
	mut result := document_layout_result(document) or { panic('missing layout') }
	children := result.paint_tree.children.data
	phase_storage := result.paint_phase_commands.data
	mut unchanged_bucket := -1
	for index, bucket in result.paint_phase_commands {
		if bucket.any(it.kind == 'draw_svg_path') { unchanged_bucket = index; break }
	}
	assert unchanged_bucket >= 0
	svg_commands := result.paint_phase_commands[unchanged_bucket].data
	for hovered in [true, false, true] {
		if hovered { document.set_hovered_node(link.as_node()) }
		else { document.set_hovered_node(none) }
		document.update_layout(.event_handler_handle_mouse_move)
		commands := display_list_commands(record_retained_display_list(mut document) or { panic('missing hover paint') })
		assert commands.any(it.color == 'rgb(234 236 240)') == hovered
		assert commands.any(it.kind == 'draw_line') == hovered
		assert result.paint_tree.children.data == children
		assert result.paint_phase_commands.data == phase_storage
		assert result.paint_phase_commands[unchanged_bucket].data == svg_commands
	}
	local_dump := (record_retained_display_list(mut document) or { panic('missing local recording') }).dump()
	refresh_document_paint_tree(document, mut result, 320, 200)
	full_dump := (record_retained_display_list(mut document) or { panic('missing full recording') }).dump()
	assert local_dump == full_dump
}

fn test_local_hover_underline_propagates_through_block_descendants() {
	mut document := html.parse_document('<!doctype html><style>
		a{display:block;text-decoration:none}strong{display:block}
		a:hover{text-decoration:underline;background:#eaecf0}
	</style><a id="link" href="#"><strong>Italiano</strong></a>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	link := document.get_element_by_id('link') or { panic('missing link') }
	_ = record_retained_display_list(mut document) or { panic('missing initial recording') }
	document.set_hovered_node(link.as_node())
	document.update_layout(.event_handler_handle_mouse_move)
	local := record_retained_display_list(mut document) or { panic('missing local recording') }
	local_dump := local.dump()
	assert display_list_commands(local).any(it.kind == 'draw_line')
	mut result := document_layout_result(document) or { panic('missing layout') }
	refresh_document_paint_tree(document, mut result, 320, 200)
	full_dump := (record_retained_display_list(mut document) or { panic('missing full recording') }).dump()
	assert local_dump == full_dump
}
