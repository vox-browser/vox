module layout

import css
import dom
import html

fn test_anchor_positions_follow_intervening_scroll_containers() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#container{position:relative;width:400px;height:400px}#scroller{overflow:scroll;width:400px;height:400px}#anchor{anchor-name:--a;margin-top:200px;margin-left:100px;width:100px;height:50px}#target{position:absolute;position-anchor:--a;left:anchor(left);top:anchor(bottom);width:100px;height:100px}</style><div id="container"><div id="scroller"><div id="anchor"></div><div style="height:1000px"></div><div id="target"></div></div></div>')
	defer { document.finalize() }
	run_document_layout(document,800,600) or { panic('layout') }
	mut scroller := document.get_element_by_id('scroller') or { panic('scroller') }
	scroller.set_scroll_offset(none,dom.CSSPixelPoint_{x_:0,y_:100})
	run_document_layout(document,800,600) or { panic('layout') }
	r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
	assert r.x==100 && r.y==150,'${r.x},${r.y}'
}
