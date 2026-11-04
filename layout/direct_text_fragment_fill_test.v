module layout

import html

fn test_text_transport_snapshot_survives_later_text_and_style_changes() {
	mut document := html.parse_document('<!doctype html><p id="text" style="font-size:19px;color:rgb(9,19,29)">alpha<span>beta</span></p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 240)
	first := storage_text_lines(document, 'text')
	assert first.len == 1
	assert first[0].fragments.map(it.text).join('') == 'alphabeta'
	assert first[0].fragments[0].font_size == 19
	assert first[0].fragments[0].color.r == 9
	assert first[0].fragments[0].color.g == 19
	assert first[0].fragments[0].color.b == 29

	mut target := document.get_element_by_id('text') or { panic('missing text') }
	target.set_attribute_value('style', 'font-size:23px;color:rgb(39,49,59)')
	mut node := target.as_node()
	node.set_text_content('replacement')!
	_ = layout_document_typed_in_viewport(document, 400, 240)
	second := storage_text_lines(document, 'text')
	assert second.len == 1
	assert second[0].fragments.map(it.text).join('') == 'replacement'
	assert second[0].fragments[0].font_size == 23
	assert second[0].fragments[0].color.r == 39
	assert first[0].fragments.map(it.text).join('') == 'alphabeta'
	assert first[0].fragments[0].font_size == 19
	assert first[0].fragments[0].color.r == 9
}

fn test_text_transport_keeps_atomic_boxes_between_styled_glyph_runs() {
	mut document := html.parse_document('<!doctype html><p id="text" style="font-size:20px;white-space:nowrap">left<span style="display:inline-block;width:17px;height:11px"></span><span style="color:rgb(70,80,90)">right</span></p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 240)
	lines := storage_text_lines(document, 'text')
	assert lines.len == 1
	assert lines[0].fragments.len == 2
	assert lines[0].fragments[0].text == 'left'
	assert lines[0].fragments[1].text == 'right'
	assert lines[0].fragments[1].x >= lines[0].fragments[0].x + lines[0].fragments[0].width + 17
	assert lines[0].fragments[1].color.r == 70
	assert lines[0].fragments[1].color.g == 80
	assert lines[0].fragments[1].color.b == 90
}
