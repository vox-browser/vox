module layout

import html

fn test_normal_vertical_block_flow_places_orthogonal_anchors_before_positioning() {
	for mode in ['vertical-lr','vertical-rl'] {
		for direction in ['ltr','rtl'] {
			for child_mode in ['horizontal-tb','vertical-lr','vertical-rl'] {
				mut document := html.parse_document('<!doctype html><style>body{margin:0}#container{position:relative;width:600px;height:400px;writing-mode:${mode};direction:${direction}}#a1{anchor-name:--a1;width:100px;height:100px;margin-left:100px;margin-top:100px;${if mode == "vertical-rl" { "margin-right:400px;" } else { "" }}${if direction == "rtl" { "margin-bottom:200px;" } else { "" }}}#a2{anchor-name:--a2;width:100px;height:100px;margin-top:300px;${if mode == "vertical-rl" { "margin-right:-600px;" } else { "margin-left:300px;" }}}#a1,#a2{writing-mode:${child_mode}}#target{position:absolute;left:anchor(--a1 right);top:anchor(--a1 bottom);right:anchor(--a2 left);bottom:anchor(--a2 top)}</style><div id="container"><div id="a1"></div><div id="a2"></div><div id="target"></div></div>')
				defer { document.finalize() }
				run_document_layout(document,800,600) or { panic('layout') }
				r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
				assert r.x == 200 && r.y == 200 && r.width == 300 && r.height == 100,'${mode} ${direction} ${child_mode}: ${r.x},${r.y} ${r.width}x${r.height}'
			}
		}
	}
}
