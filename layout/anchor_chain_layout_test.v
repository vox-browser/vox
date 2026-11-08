module layout

import html

fn test_anchor_dependency_chain_uses_preceding_positioned_boxes() {
	mut source := '<!doctype html><style>body{margin:0}#cb{position:relative;width:700px;height:500px}.box{width:50px;height:50px;position:absolute;anchor-name:--box}.area{position-anchor:--box;position-area:right center;margin-left:10px}.fn{position-anchor:--box;left:calc(anchor(right) + 10px)}</style><div id="cb"><div class="box" id="b0" style="top:0;left:0"></div>'
	for index in 1..10 { source += '<div id="b${index}" class="box ${if index%2 == 1 { "area" } else { "fn" }}"></div>' }
	source += '</div>'
	mut document := html.parse_document(source)
	defer { document.finalize() }
	run_document_layout(document,800,600) or { panic('layout') }
	for index in 0..10 {
		r := (document.get_element_by_id('b${index}') or { panic('box') }).get_bounding_client_rect()
		assert r.x == index*60,'box ${index}: ${r.x}'
	}
}
