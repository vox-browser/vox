module main

import html
import layout

fn test_auto_flex_basis_consumes_the_preferred_intrinsic_width_keyword() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}.container{display:flex;width:30px}.item{flex:none}.item span{display:inline-block;width:20px;height:1px}</style><div class="container"><div id="minimum" class="item" style="width:min-content"><span></span><span></span></div></div><div class="container"><div id="maximum" class="item" style="width:max-content"><span></span><span></span></div></div><div class="container"><div id="fit" class="item" style="width:fit-content"><span></span><span></span></div></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	for id, expected in {'minimum':20, 'maximum':40, 'fit':30} {
		r := (document.get_element_by_id(id) or { panic(id) }).get_bounding_client_rect()
		assert r.width == expected, '${id}: ${r.width}'
	}
}

fn test_outside_markers_do_not_contribute_to_floating_list_item_intrinsic_width() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}li{float:left;clear:left}#inside{list-style-position:inside}li::marker{content:"marker"}</style><ol><li id="outside"></li><li id="inside"></li></ol>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	outside := (document.get_element_by_id('outside') or { panic('outside') }).get_bounding_client_rect()
	inside := (document.get_element_by_id('inside') or { panic('inside') }).get_bounding_client_rect()
	assert outside.width == 0, '${outside.width}'
	assert inside.width > 0, '${inside.width}'
}
