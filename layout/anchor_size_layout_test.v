module layout

import html

fn test_anchor_size_uses_containing_and_subject_axes_and_nested_fallbacks() {
	for container_mode in ['horizontal-tb','vertical-rl'] {
		for subject_mode in ['horizontal-tb','vertical-rl'] {
			for dimension, expected in {'width':5.0, 'height':7.0,
				'inline':if container_mode == 'horizontal-tb' { 5.0 } else { 7.0 },
				'block':if container_mode == 'horizontal-tb' { 7.0 } else { 5.0 },
				'self-inline':if subject_mode == 'horizontal-tb' { 5.0 } else { 7.0 },
				'self-block':if subject_mode == 'horizontal-tb' { 7.0 } else { 5.0 }} {
				mut document := html.parse_document('<!doctype html><style>body{margin:0}
					#container{position:relative;width:100px;height:100px;writing-mode:${container_mode}}
					#anchor{width:5px;height:7px;anchor-name:--a}
					#target{position:absolute;writing-mode:${subject_mode};width:anchor-size(--a ${dimension});height:anchor-size(--missing height, anchor-size(--a width));margin-left:anchor-size(--a height);left:anchor-size(--a width)}
					</style><div id="container"><div id="anchor"></div><div id="target"></div></div>')
				run_document_layout(document,400,300) or { panic('layout') }
				r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
				assert r.width == expected && r.height == 5, '${container_mode} ${subject_mode} ${dimension}: ${r.width}, ${r.height}'
				document.finalize()
			}
		}
	}
}
