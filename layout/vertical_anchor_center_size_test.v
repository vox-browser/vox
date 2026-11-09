module layout

import html

fn test_vertical_anchor_center_shrink_to_fit_uses_inline_min_content_height() {
	for values in [[0, 100, 0], [60, 60, 35], [100, 100, 0]] {
		maximum, expected_height, expected_top := values[0], values[1], values[2]
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#container{position:relative;width:100px;height:100px}#anchor{position:relative;anchor-name:--a;left:40px;top:40px;width:50px;height:50px}#target{position:absolute;position-anchor:--a;writing-mode:vertical-rl;align-self:anchor-center;right:anchor(left);width:20px;${if maximum > 0 {
			'max-height:${maximum}px;'
		} else {
			''
		}}}#target::after{content:"a a a a a a a a a a a a a a a a a a"}</style><div id="container"><div id="anchor"></div><div id="target"></div></div>')
		defer { document.finalize() }
		run_document_layout(document, 800, 600) or { panic('layout') }
		r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
		assert r.height == expected_height && r.y == expected_top, 'max ${maximum}: ${r.height},${r.y}'
	}
}
