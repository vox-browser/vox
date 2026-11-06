module layout

import html

fn test_chromium_positioned_ratio_boxes_transfer_border_box_size_to_percentage_children() {
	for position in ['absolute', 'fixed'] {
		for style, expected in {
			'width:464px;aspect-ratio:16/9;border:1px solid': [f64(464), 261, 462, 259]
			'width:212px;aspect-ratio:16/9;border:1px solid': [f64(212), 119.25, 210, 117.25]
			'width:212px;aspect-ratio:2;border:3px solid;padding:5px': [f64(212), 106, 196, 90]
			'width:400px;max-width:212px;aspect-ratio:2;border:3px solid;padding:5px': [f64(212), 106, 196, 90]
			'width:100px;min-width:212px;aspect-ratio:2;border:3px solid;padding:5px': [f64(212), 106, 196, 90]
			'width:212px;height:70px;aspect-ratio:2;border:3px solid;padding:5px': [f64(212), 70, 196, 54]
			'width:212px;aspect-ratio:2;border:3px solid;padding:5px;max-height:80px': [f64(212), 80, 196, 64]
			'width:212px;aspect-ratio:2;border:3px solid;padding:5px;min-height:120px': [f64(212), 120, 196, 104]
		} {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}
				#target{position:${position};left:24px;top:88px;box-sizing:border-box;${style}}
				#child{width:100%;height:100%}
			</style><div id="target"><div id="child"></div></div>')
			document.set_font_rendering_policy(.chromium)
			_ = run_document_layout(document, 1024, 768) or { panic('layout') }
			for index, id in ['target', 'child'] {
				r := document.get_element_by_id(id)?.get_bounding_client_rect()
				assert r.width == expected[index * 2], '${position} ${style} ${id}: width ${r.width}'
				assert r.height == expected[index * 2 + 1], '${position} ${style} ${id}: height ${r.height}'
			}
			document.finalize()
		}
	}
}

fn test_positioned_ratio_boxes_preserve_content_box_auto_ratio_and_ladybird_policy() {
	for position in ['absolute', 'fixed'] {
		for style, expected in {
			'box-sizing:content-box;aspect-ratio:2': [f64(96), 56]
			'box-sizing:border-box;aspect-ratio:auto 2': [f64(80), 48]
		} {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}
				#target{position:${position};width:80px;border:3px solid;padding:5px;${style}}
			</style><div id="target"></div>')
			document.set_font_rendering_policy(.chromium)
			_ = run_document_layout(document, 320, 240) or { panic('layout') }
			r := document.get_element_by_id('target')?.get_bounding_client_rect()
			assert r.width == expected[0], '${position} ${style}'
			assert r.height == expected[1], '${position} ${style}'
			document.finalize()
		}
		mut document := html.parse_document('<!doctype html><style>body{margin:0}
			#target{position:${position};width:80px;box-sizing:border-box;aspect-ratio:2;border:3px solid;padding:5px}
		</style><div id="target"></div>')
		_ = run_document_layout(document, 320, 240) or { panic('layout') }
		r := document.get_element_by_id('target')?.get_bounding_client_rect()
		assert r.width == 80, position
		assert r.height == 48, position
		document.finalize()
	}
}
