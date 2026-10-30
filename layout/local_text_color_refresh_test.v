module layout

import html

fn test_local_text_color_refresh_matches_full_current_color_paint_and_keeps_geometry() {
	mut document := html.parse_document('<!doctype html><style>
		html,body{margin:0}#clip{transform:translate(10px,10px);overflow:hidden;width:200px;height:120px}
		a{display:block;width:100px;color:blue;border:2px solid currentColor;outline:1px solid currentColor;
		background:linear-gradient(currentColor,transparent);box-shadow:2px 2px 1px currentColor}
		a:hover{color:red}
	</style><div id="clip"><a id="link"><strong>toggle comment</strong></a></div>
	<svg width="10" height="10"><path d="M0 0H10V10H0Z" fill="green"/></svg>')
	_ = layout_document_typed_in_viewport(document, 320, 240)
	link := document.get_element_by_id('link')?
	mut result := document_layout_result(document)?
	_ = document.record_display_list()?
	for hovered in [true, false, true] {
		children := result.paint_tree.children.data
		if hovered {
			document.set_hovered_node(link.as_node())
		} else {
			document.set_hovered_node(none)
		}
		document.update_layout(.event_handler_handle_mouse_move)
		assert document.element_from_point(30, 20)? == link || document.element_from_point(30, 20)?.closest('a')? == link
		local := document.record_display_list()?
		assert result.paint_tree.children.data == children
		commands := display_list_commands(local)
		assert commands.any(it.kind == 'draw_text' && it.color == if hovered {
			'rgb(255 0 0)'
		} else {
			'rgb(0 0 255)'
		})
		local_dump := local.dump()
		refresh_document_paint_tree(document, mut result, 320, 240)
		assert (document.record_display_list()?).dump() == local_dump
	}
}

fn test_text_color_changes_with_filters_or_svg_keep_the_full_refresh() {
	for content in [
		'<a id="link" style="filter:drop-shadow(2px 2px currentColor)">filtered</a>',
		'<a id="link"><svg width="20" height="20"><path d="M0 0H20V20H0Z" fill="currentColor"/></svg></a>',
	] {
		mut document := html.parse_document('<!doctype html><style>a{display:block;color:blue}a:hover{color:red}</style>' + content)
		_ = layout_document_typed_in_viewport(document, 320, 240)
		link := document.get_element_by_id('link')?
		mut result := document_layout_result(document)?
		_ = document.record_display_list()?
		children := result.paint_tree.children.data
		document.set_hovered_node(link.as_node())
		document.update_layout(.event_handler_handle_mouse_move)
		local_dump := (document.record_display_list()?).dump()
		assert result.paint_tree.children.data != children
		refresh_document_paint_tree(document, mut result, 320, 240)
		assert (document.record_display_list()?).dump() == local_dump
	}
}

fn test_inherited_color_qualification_keeps_custom_property_font_changes_in_layout() {
	mut document := html.parse_document('<!doctype html><style>
		a{display:block;--size:12px;color:blue}a:hover{--size:40px;color:red}
		strong{font-size:var(--size)}
	</style><a id="link"><strong id="label">comment</strong></a>')
	_ = layout_document_typed_in_viewport(document, 320, 240)
	link := document.get_element_by_id('link')?
	label := document.get_element_by_id('label')?
	before := label.get_bounding_client_rect()
	document.set_hovered_node(link.as_node())
	document.update_layout(.event_handler_handle_mouse_move)
	assert label.get_bounding_client_rect().height > before.height * 2
	list := document.record_display_list()?
	commands := display_list_commands(list)
	assert commands.any(it.kind == 'draw_text' && it.font_size == 40 && it.color == 'rgb(255 0 0)')
}
