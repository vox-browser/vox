module layout

import html

fn test_retained_flow_keeps_old_paint_and_rewraps_text_after_parent_width_changes() {
	mut document :=
		html.parse_document('<!doctype html><div id="changed"></div><section id="left" style="width:300px;color:red"><div id="moving"><p id="text">Retained text wraps into more lines when its ancestor moves into a narrower parent.</p></div></section><section id="right" style="width:80px;color:blue"></section>')
	_ = layout_document_typed_in_viewport(document, 400, 300)
	text := document.get_element_by_id('text')?
	previous_handle := text.as_node().unsafe_layout_node()?.real_layout_handle()
	previous_height := text.get_bounding_client_rect().height
	previous_paint := document.record_display_list()?
	previous_dump := previous_paint.dump()
	mut left := document.get_element_by_id('left')?
	left.set_attribute_value('style', 'width:80px;color:blue')
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p>new branch</p>')!
	document.update_layout(.debugging)
	assert text.as_node().unsafe_layout_node()?.real_layout_handle() == previous_handle
	assert text.get_bounding_client_rect().height > previous_height
	assert previous_paint.dump() == previous_dump
	current := document.record_display_list()?
	commands := display_list_commands(current)
	assert commands.any(it.kind == 'draw_text' && it.color == 'rgb(0 0 255)')
	current_dump := current.dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list()?).dump() == current_dump
}
