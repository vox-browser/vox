module layout

import html

fn test_normal_vertical_block_flow_places_orthogonal_anchors_before_positioning() {
	for mode in ['vertical-lr','vertical-rl'] {
		for direction in ['ltr','rtl'] {
			for child_mode in ['horizontal-tb','vertical-lr','vertical-rl'] {
				mut document := html.parse_document('<!doctype html><style>body{margin:0}#container{position:relative;width:600px;height:400px;writing-mode:${mode};direction:${direction}}#a1{anchor-name:--a1;width:100px;height:100px;margin-left:100px;margin-top:100px;${if mode == "vertical-rl" { "margin-right:400px;" } else { "" }}${if direction == "rtl" { "margin-bottom:200px;" } else { "" }}}#a2{anchor-name:--a2;width:100px;height:100px;margin-top:300px;${if mode == "vertical-rl" { "margin-right:-600px;" } else { "margin-left:300px;" }}}#a1,#a2{writing-mode:${child_mode}}#target{position:absolute;left:anchor(--a1 right);top:anchor(--a1 bottom);right:anchor(--a2 left);bottom:anchor(--a2 top)}</style><div id="container"><div id="a1"></div>
<div id="a2"></div>
<div id="target"></div></div>')
				defer { document.finalize() }
				run_document_layout(document,800,600) or { panic('layout') }
				r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
				assert r.x == 200 && r.y == 200 && r.width == 300 && r.height == 100,'${mode} ${direction} ${child_mode}: ${r.x},${r.y} ${r.width}x${r.height}'
			}
		}
	}
}

fn test_vertical_block_flow_repositions_after_repeated_writing_mode_changes() {
	mut document := html.parse_document('<!doctype html><style>:root,body{margin:0}#container{position:relative;width:600px;height:400px}#a1{anchor-name:--a1;width:100px;height:100px;margin-left:100px;margin-top:100px}.htb-rtl #a1{margin-right:400px}.vlr-rtl #a1{margin-bottom:200px}.vrl-ltr #a1{margin-right:400px}.vrl-rtl #a1{margin-right:400px;margin-bottom:200px}#a2{anchor-name:--a2;width:100px;height:100px;margin-left:500px;margin-top:100px}.vlr-ltr #a2,.vlr-rtl #a2{margin-left:300px;margin-top:300px}.vrl-ltr #a2,.vrl-rtl #a2{margin-right:-600px;margin-top:300px}#target{position:absolute;left:anchor(--a1 right);top:anchor(--a1 bottom);right:anchor(--a2 left);bottom:anchor(--a2 top)}.htb-ltr{writing-mode:horizontal-tb;direction:ltr}.htb-rtl{writing-mode:horizontal-tb;direction:rtl}.vlr-ltr{writing-mode:vertical-lr;direction:ltr}.vlr-rtl{writing-mode:vertical-lr;direction:rtl}.vrl-ltr{writing-mode:vertical-rl;direction:ltr}.vrl-rtl{writing-mode:vertical-rl;direction:rtl}</style><div id="container"><div id="a1"></div>
<div id="a2"></div>
<div id="target"></div></div>')
	defer { document.finalize() }
	mut container := document.get_element_by_id('container') or { panic('container') }
	mut a1 := document.get_element_by_id('a1') or { panic('a1') }
	mut a2 := document.get_element_by_id('a2') or { panic('a2') }
	mut target := document.get_element_by_id('target') or { panic('target') }
	for mode in ['htb-ltr','htb-rtl','vlr-ltr','vlr-rtl','vrl-ltr','vrl-rtl'] {
		container.set_attribute_value('class',mode)
		a1.set_attribute_value('class','htb-ltr')
		a2.set_attribute_value('class','htb-ltr')
		target.set_attribute_value('class','htb-ltr')
		result := run_document_layout(document,800,600) or { panic('layout') }
		r := target.get_bounding_client_rect()
		a := a1.get_bounding_client_rect()
		bridge := a1.as_node().unsafe_layout_node() or { panic('bridge') }
		node := unsafe { &Node(bridge.real_layout_handle()) }
		used := result.state.get(node.as_node_with_style() or { panic('styled') })
		assert r.x==200 && r.y==200 && r.width==300 && r.height==100,'${mode}: target ${r.x},${r.y} ${r.width}x${r.height}; anchor ${a.x},${a.y}, width ${a.width}; offset ${used.offset.x()},${used.offset.y()}, margin ${used.margin_left},${used.margin_right}'
		container.remove_attribute('class')
		a1.remove_attribute('class')
		a2.remove_attribute('class')
		target.remove_attribute('class')
	}
}
