module layout

import html

fn test_absolute_stretch_transfers_ratios_before_intrinsic_and_replaced_sizing() {
	for mode in ['horizontal-tb','vertical-rl'] {
		for kind in ['descendant','ratio','canvas'] {
			for axes in ['none','width','height','both'] {
				width := if axes in ['width','both'] { 40 } else if axes == 'height' { 50 } else if kind == 'canvas' { 10 } else { 20 }
				height := if axes in ['height','both'] { 50 } else { width }
				inline_stretch := if mode == 'horizontal-tb' { axes in ['width','both'] } else { axes in ['height','both'] }
				block_stretch := if mode == 'horizontal-tb' { axes in ['height','both'] } else { axes in ['width','both'] }
				tag := if kind == 'canvas' { 'canvas' } else { 'div' }
				mut document := html.parse_document('<!doctype html><style>body{margin:0}
					#container{position:relative;width:60px;height:60px;writing-mode:${mode}}
					#target{position:absolute;inset:5px 10px;justify-self:${if inline_stretch { "stretch" } else { "start" }};align-self:${if block_stretch { "stretch" } else { "start" }};${if kind == "ratio" { "aspect-ratio:1;min-width:20px;min-height:20px" } else { "" }}}
					${if kind == "descendant" { "#target::before{content:'';display:block;aspect-ratio:1;min-width:20px;min-height:20px;width:100%;height:100%}" } else { "" }}
					</style><div id="container"><${tag} id="target" width="10" height="10"></${tag}></div>')
				defer { document.finalize() }
				run_document_layout(document,200,200) or { panic('layout') }
				r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
				assert r.width == width && r.height == height, '${mode} ${kind} ${axes}: ${r.width}x${r.height}, expected ${width}x${height}'
			}
		}
	}
}
