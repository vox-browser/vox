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
	initial := display_list_commands(document.record_display_list() or { panic('missing initial paint') })
	assert !initial.any(it.color == 'rgb(234 236 240)')

	document.set_hovered_node(label.as_node())
	document.update_layout(.event_handler_handle_mouse_move)
	assert document.layout_engine_handle() == layout_handle
	assert result.state == state
	hovered := display_list_commands(document.record_display_list() or { panic('missing hovered paint') })
	assert hovered.any(it.color == 'rgb(234 236 240)' && it.width == 200)
	assert !initial.any(it.color == 'rgb(234 236 240)')
	assert !result.paint_tree_needs_style_update

	// A clean frame reuses its snapshot and phase caches.
	paint_children := result.paint_tree.children.data
	phase_commands := result.paint_phase_commands.data
	document.set_needs_repaint_with_invalidation(.paint_commands)
	_ = document.record_display_list() or { panic('missing repeated paint') }
	assert result.paint_tree.children.data == paint_children
	assert result.paint_phase_commands.data == phase_commands

	document.set_hovered_node(none)
	document.update_layout(.event_handler_handle_mouse_move)
	unhovered := display_list_commands(document.record_display_list() or { panic('missing unhovered paint') })
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
