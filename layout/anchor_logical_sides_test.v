module layout

import html

fn test_anchor_logical_sides_follow_physical_axis_in_all_writing_directions() {
	for mode in ['horizontal-tb','vertical-rl','vertical-lr','sideways-rl','sideways-lr'] {
		for direction in ['ltr','rtl'] {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}
				#container{position:relative;width:100px;height:100px;writing-mode:${mode};direction:${direction}}
				#anchor{position:absolute;left:20px;top:30px;width:40px;height:50px;anchor-name:--a}
				#target{position:absolute;position-anchor:--a;width:0;height:0;left:anchor(start);top:anchor(25%)}
				</style><div id="container"><div id="anchor"></div><div id="target"></div></div>')
			defer { document.finalize() }
			run_document_layout(document,200,200) or { panic('layout') }
			x_low := if mode == 'horizontal-tb' { direction == 'ltr' } else { mode in ['vertical-lr','sideways-lr'] }
			y_low := mode == 'horizontal-tb' || (direction == 'ltr') != (mode == 'sideways-lr')
			r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
			assert r.x == if x_low { 20.0 } else { 60.0 }, '${mode} ${direction}: x=${r.x}'
			assert r.y == if y_low { 42.5 } else { 67.5 }, '${mode} ${direction}: y=${r.y}'
		}
	}
}
