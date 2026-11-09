module layout

import html

fn test_absolute_self_alignment_respects_containing_axes_and_subject_direction() {
	for writing_mode in ['horizontal-tb', 'vertical-rl', 'vertical-lr'] {
		for direction in ['ltr', 'rtl'] {
			for alignment, fraction in {'start':0.0, 'center':0.5, 'end':1.0,
				'baseline':0.0, 'last baseline':1.0, 'self-start':-1.0, 'self-end':-2.0} {
				mut document := html.parse_document('<!doctype html><style>body{margin:0}
					#container{position:relative;width:40px;height:40px;writing-mode:${writing_mode};direction:${direction}}
					#item{position:absolute;inset:0;writing-mode:horizontal-tb;direction:ltr;align-self:${alignment};justify-self:${alignment}}
					#item::before{content:"";display:block;width:20px;height:20px}
					</style><div id="container"><div id="item"></div></div>')
				run_document_layout(document, 200, 200) or { panic('layout') }
				item := document.get_element_by_id('item') or { panic('item') }
				rect := item.get_bounding_client_rect()
				low_x := if writing_mode == 'horizontal-tb' { direction == 'ltr' } else { writing_mode == 'vertical-lr' }
				low_y := writing_mode == 'horizontal-tb' || direction == 'ltr'
				x := if fraction < 0 { if fraction == -1 { 0.0 } else { 20.0 } } else { 20 * if low_x { fraction } else { 1 - fraction } }
				y := if fraction < 0 { if fraction == -1 { 0.0 } else { 20.0 } } else { 20 * if low_y { fraction } else { 1 - fraction } }
				assert rect.width == 20 && rect.height == 20, '${writing_mode} ${direction} ${alignment}: size ${rect.width} ${rect.height}'
				assert rect.x == x && rect.y == y, '${writing_mode} ${direction} ${alignment}: position ${rect.x} ${rect.y}, expected ${x} ${y}'
				document.finalize()
			}
		}
	}
}

fn test_absolute_alignment_default_overflow_uses_original_containing_block() {
	for height, expected in {20:45.0, 80:15.0, 95:5.0, 120:0.0} {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}
			#container{position:relative;width:100px;height:100px}
			#item{position:absolute;top:20px;bottom:10px;align-self:center}
			#inner{width:20px;height:${height}px}</style>
			<div id="container"><div id="item"><div id="inner"></div></div></div>')
		run_document_layout(document, 200, 200) or { panic('layout') }
		rect := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
		assert rect.y == expected && rect.height == height, 'height ${height}: ${rect.y}, ${rect.height}'
		document.finalize()
	}
}

fn test_absolute_anchor_center_uses_live_anchor_geometry_and_respects_insets() {
	for width, expected in {100:0.0, 60:35.0, 30:50.0} {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}
			#container{position:relative;width:100px;height:100px}
			#anchor{position:relative;left:40px;top:40px;width:50px;height:50px;anchor-name:--a}
			#item{position:absolute;position-anchor:--a;justify-self:anchor-center;top:anchor(bottom);width:${width}px;height:20px}
			</style><div id="container"><div id="anchor"></div><div id="item"></div></div>')
		run_document_layout(document, 200, 200) or { panic('layout') }
		rect := (document.get_element_by_id('item') or { panic('item') }).get_bounding_client_rect()
		assert rect.x == expected && rect.y == 90, '${width}: ${rect.x}, ${rect.y}'
		document.finalize()
	}
}
