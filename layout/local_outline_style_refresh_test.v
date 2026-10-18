module layout

import html

fn test_local_outline_refresh_preserves_geometry_and_matches_full_recording() {
	mut document :=
		html.parse_document('<!doctype html><style>#clip{transform:translate(8px,12px);overflow:hidden;width:240px;height:120px}a{display:block;width:120px;outline:none}a.on{outline:3px dashed red;outline-offset:2px}</style><div id="clip"><a id="control">comment toggle</a></div><svg width="10" height="10"><rect width="10" height="10" fill="green"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 240)
	mut control := document.get_element_by_id('control')?
	mut result := document_layout_result(document)?
	old := document.record_display_list()?
	old_commands := display_list_commands(old)
	old_snapshot := old_commands.map('${it.kind}:${it.x}:${it.y}:${it.color}:${it.text}')
	for class_name in ['on', '', 'on'] {
		storage := result.paint_tree.children.data
		geometry := control.get_bounding_client_rect()
		control.set_attribute_value('class', class_name)
		document.update_layout(.debugging)
		current := document.record_display_list()?
		assert result.paint_tree.children.data == storage
		assert control.get_bounding_client_rect() == geometry
		local_dump := current.dump()
		refresh_document_paint_tree(document, mut result, 320, 240)
		assert (document.record_display_list()?).dump() == local_dump
		assert old_commands.map('${it.kind}:${it.x}:${it.y}:${it.color}:${it.text}') == old_snapshot
	}
}

fn test_local_inline_outline_refresh_updates_multiline_pieces_and_auto_style() {
	mut document :=
		html.parse_document('<!doctype html><style>p{width:100px}span{outline:none}span.on{outline:2px auto;outline-offset:-1px}</style><p><span id="control">a long inline comment label that wraps</span></p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 240)
	mut control := document.get_element_by_id('control')?
	mut result := document_layout_result(document)?
	_ = document.record_display_list()?
	for class_name in ['on', ''] {
		storage := result.paint_tree.children.data
		control.set_attribute_value('class', class_name)
		document.update_layout(.debugging)
		local_dump := (document.record_display_list()?).dump()
		assert result.paint_tree.children.data == storage
		refresh_document_paint_tree(document, mut result, 320, 240)
		assert (document.record_display_list()?).dump() == local_dump
	}
}
