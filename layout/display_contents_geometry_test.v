module layout

import html

fn test_switching_to_display_contents_detaches_the_previous_principal_box() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{width:100px;height:20px}#child{width:50px;height:10px}</style><div id="outer"><div id="child"></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document,800,600)
	mut outer := document.get_element_by_id('outer') or { panic('outer') }
	assert outer.client_width() == 100
	outer.set_attribute_value('style','display:contents')
	_ = layout_document_typed_in_viewport(document,800,600)
	assert outer.client_width() == 0
	assert outer.client_height() == 0
	assert outer.get_client_rects().len == 0
	assert outer.as_node().layout_node() == none
	assert (document.get_element_by_id('child') or { panic('child') }).get_bounding_client_rect().width == 50
}
