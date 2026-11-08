module layout

import html

fn test_position_area_selects_physical_tracks_and_stretches_to_the_selected_region() {
	for area, expected in {'top left':[0.0,0,100,150], 'top center':[100.0,0,150,150],
		'top right':[250.0,0,150,150], 'center left':[0.0,150,100,75], 'center':[100.0,150,150,75],
		'center right':[250.0,150,150,75], 'bottom left':[0.0,225,100,175],
		'bottom center':[100.0,225,150,175], 'bottom right':[250.0,225,150,175],
		'span-all':[0.0,0,400,400], 'span-bottom':[0.0,150,400,250]} {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}
			#container{position:relative;width:400px;height:400px}
			#anchor{position:absolute;left:100px;top:150px;width:150px;height:75px;anchor-name:--a}
			#subject{position:absolute;position-anchor:--a;position-area:${area};align-self:stretch;justify-self:stretch}
			</style><div id="container"><div id="anchor"></div><div id="subject"></div></div>')
		run_document_layout(document, 600, 600) or { panic('layout') }
		r := (document.get_element_by_id('subject') or { panic('subject') }).get_bounding_client_rect()
		assert [r.x,r.y,r.width,r.height] == expected, '${area}: ${r.x}, ${r.y}, ${r.width}, ${r.height}'
		document.finalize()
	}
}

fn test_position_area_default_alignment_moves_towards_anchor_after_insets() {
	for area, expected in {'span-all':[145.0,145], 'top left':[75.0,70], 'top center':[150.0,70],
		'top right':[225.0,70], 'center left':[75.0,140], 'center':[150.0,140],
		'bottom right':[225.0,210], 'top span-left':[175.0,70], 'span-bottom left':[75.0,110]} {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}
			#container{position:relative;width:300px;height:300px}
			#anchor{position:absolute;left:100px;top:100px;width:100px;height:100px;anchor-name:--a}
			#subject{position:absolute;position-anchor:--a;position-area:${area};width:10px;height:10px;inset:10px 15px 20px 25px}
			</style><div id="container"><div id="anchor"></div><div id="subject"></div></div>')
		run_document_layout(document, 600, 600) or { panic('layout') }
		r := (document.get_element_by_id('subject') or { panic('subject') }).get_bounding_client_rect()
		assert [r.x,r.y] == expected, '${area}: ${r.x}, ${r.y}'
		document.finalize()
	}
}
