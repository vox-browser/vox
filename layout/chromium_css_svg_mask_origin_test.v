module layout

import dom
import html
import http
import loader
import math

fn register_mask_origin_test_svg() string {
	address := 'https://css-mask-origin.test/shape.svg'
	mut resources := if loader.is_initialized() { loader.ResourceLoader.the() } else { loader.initialize() }
	resources.register_network_response(address, loader.NetworkResponse{
		data: '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path fill="black" d="M2 3C7 0 13 2 14 8L12 14H3Z"/></svg>'.bytes()
		headers: [http.Header{name:'Content-Type',value:'image/svg+xml'}]
	})
	return address
}

fn test_chromium_css_svg_mask_snaps_only_its_paint_origin() {
	address := register_mask_origin_test_svg()
	for policy in [dom.FontRenderingPolicy.libweb,.chromium] {
		for origin in [f64(10.25),10.5,10.75,-1.5] {
			mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{position:absolute;left:${origin}px;top:${origin}px;width:16px;height:16px;background:red;mask-image:url("${address}");mask-size:100%}</style><div id="target"></div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(policy)
			root := layout_document_typed_in_viewport(document,100,80)
			element := document.get_element_by_id('target') or { panic('missing target') }
			box := root.find_box(i64(element.as_node().unique_id())) or { panic('missing box') }
			mask := box.svg_mask or { panic('missing mask') }
			assert mask.operations.len == 1
			assert mask.operations[0].kind == .path
			expected := if policy == .chromium { math.floor(origin+.5) } else { origin }
			assert mask.operations[0].transform.e == expected
			assert mask.operations[0].transform.f == expected
			assert element.get_bounding_client_rect().x == origin
			assert element.get_bounding_client_rect().y == origin
		}
	}
}

fn test_svg_image_inside_a_mask_keeps_its_fractional_svg_coordinates() {
	address := register_mask_origin_test_svg()
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><svg width="100" height="80"><defs><mask id="mask" maskUnits="userSpaceOnUse" x="0" y="0" width="100" height="80"><image href="${address}" x="10.5" y="20.5" width="16" height="16"/></mask></defs><rect id="target" width="100" height="80" mask="url(#mask)"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document,100,80)
	element := document.get_element_by_id('target') or { panic('missing target') }
	box := root.find_box(i64(element.as_node().unique_id())) or { panic('missing box') }
	mask := box.svg_mask or { panic('missing SVG mask') }
	assert mask.operations.len == 1
	assert mask.operations[0].kind == .path
	assert mask.operations[0].transform.e == 10.5
	assert mask.operations[0].transform.f == 20.5
}
