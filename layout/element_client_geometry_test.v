module layout

import html

fn test_standards_root_and_quirks_body_client_sizes_use_viewport() {
	for doctype in ['<!doctype html>', ''] {
		document :=
			html.parse_document('${doctype}<style>html,body{margin:0;width:40px;height:30px}</style><body></body>')
		_ = layout_document_typed_in_viewport(document, 200, 100)
		root := document.document_element()?
		body := document.body()?
		if document.in_quirks_mode() {
			assert body.client_width() == 200
			assert body.client_height() == 100
			assert root.client_width() == 40
			assert root.client_height() == 30
		} else {
			assert root.client_width() == 200
			assert root.client_height() == 100
			assert body.client_width() == 40
			assert body.client_height() == 30
		}
	}
}

fn test_client_geometry_excludes_inline_none_and_contents_boxes() {
	document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}span{border:7px solid;padding:4px}#block{display:inline-block;width:30px;height:20px;border-top:3.5px solid;border-left:2.5px solid;padding:4px}#hidden{display:none}#contents{display:contents}</style><span id="inline">word</span><span id="block">word</span><span id="hidden">word</span><span id="contents">word</span>')
	_ = layout_document_typed_in_viewport(document, 200, 100)
	for id in ['inline', 'hidden', 'contents'] {
		element := document.get_element_by_id(id)?
		assert element.client_left() == 0
		assert element.client_top() == 0
		assert element.client_width() == 0
		assert element.client_height() == 0
	}
	block := document.get_element_by_id('block')?
	assert block.client_left() == 2
	assert block.client_top() == 3
	assert block.client_width() == 38
	assert block.client_height() == 28
}

fn test_client_border_geometry_reads_live_visible_computed_borders() {
	document :=
		html.parse_document('<!doctype html><div id="block" style="border-top:6px solid;border-left:5px solid"></div>')
	_ = layout_document_typed_in_viewport(document, 200, 100)
	mut block := document.get_element_by_id('block')?
	assert block.client_left() == 5
	assert block.client_top() == 6
	block.set_attribute_value('style', 'border-top:20px hidden;border-left:20px none')
	assert block.client_left() == 0
	assert block.client_top() == 0
}

fn test_client_size_includes_inline_replaced_boxes() {
	document := html.parse_document('<!doctype html><canvas id="canvas" style="width:37px;height:23px;padding:4px"></canvas>')
	_ = layout_document_typed_in_viewport(document, 200, 100)
	canvas := document.get_element_by_id('canvas')?
	assert canvas.client_width() == 45
	assert canvas.client_height() == 31
}
