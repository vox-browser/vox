module layout

import html
import http
import loader
import painting

fn test_css_svg_mask_images_retain_translated_vector_geometry_and_alpha() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{margin:22px 0 0 18px;width:16px;height:16px;background:red;mask-image:url("https://css-mask.test/icon.svg");mask-size:100%}</style><div id="target"></div>')
	defer { document.finalize() }
	mut resources := if loader.is_initialized() { loader.ResourceLoader.the() } else { loader.initialize() }
	resources.register_network_response('https://css-mask.test/icon.svg', loader.NetworkResponse{
		data: '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path fill="black" fill-opacity="0.5" d="M2 3H14V13H2Z"/></svg>'.bytes()
		headers: [http.Header{name:'Content-Type',value:'image/svg+xml'}]
	})
	root := layout_document_typed_in_viewport(document,100,80)
	element := document.get_element_by_id('target') or { panic('missing target') }
	box := root.find_box(i64(element.as_node().unique_id())) or { panic('missing box') }
	mask := box.clips().svg_mask or { panic('missing CSS SVG mask') }
	assert mask.mask_type == .alpha
	assert mask.operations.len == 1
	path := mask.operations[0]
	assert path.kind == .path
	assert path.path.segments.len > 0
	assert path.fill_opacity == 0.5
	assert path.transform.e == 18
	assert path.transform.f == 22
	assert mask.bounding_rect == painting.IntRect{18,22,16,16}
}
