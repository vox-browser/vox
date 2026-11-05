module layout

import html

fn test_chromium_ratio_blocks_convert_the_border_box_once_and_relay_content_height() {
	for style, expected in {
		'width:100%;aspect-ratio:16/9;border:1px solid': [f64(464), 261, 462, 259]
		'width:212px;aspect-ratio:16/9;border:1px solid': [f64(212), 119.25, 210, 117.25]
		'width:212px;aspect-ratio:2;border:3px solid;padding:5px': [f64(212), 106, 196, 90]
		'width:400px;max-width:212px;aspect-ratio:2;border:3px solid;padding:5px': [f64(212), 106, 196, 90]
		'width:100px;min-width:212px;aspect-ratio:2;border:3px solid;padding:5px': [f64(212), 106, 196, 90]
		'width:212px;height:70px;aspect-ratio:2;border:3px solid;padding:5px': [f64(212), 70, 196, 54]
		'width:212px;aspect-ratio:2;border:3px solid;padding:5px;max-height:80px': [f64(212), 80, 196, 64]
		'width:212px;aspect-ratio:2;border:3px solid;padding:5px;min-height:120px': [f64(212), 120, 196, 104]
	} {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}.frame{width:464px}.target{display:block;box-sizing:border-box;${style}}
			.child{height:100%;width:100%}
		</style><div class="frame"><a id="target" class="target"><div id="child" class="child"></div></a></div>')
		document.set_font_rendering_policy(.chromium)
		_ = run_document_layout(document, 1024, 768) or { panic('layout') }
		for index, id in ['target', 'child'] {
			element := document.get_element_by_id(id) or { panic(id) }
			r := element.get_bounding_client_rect()
			assert r.width == expected[index * 2], '${style}: ${id} width ${r.width}'
			assert r.height == expected[index * 2 + 1], '${style}: ${id} height ${r.height}'
		}
		document.finalize()
	}
}

fn test_chromium_ratio_blocks_keep_content_box_and_auto_ratio_transfers() {
	for style, expected in {
		'box-sizing:content-box;aspect-ratio:2': [f64(96), 56]
		'box-sizing:border-box;aspect-ratio:auto 2': [f64(80), 48]
	} {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}div{width:80px;border:3px solid;padding:5px;${style}}
		</style><div id="target"></div>')
		document.set_font_rendering_policy(.chromium)
		_ = run_document_layout(document, 320, 240) or { panic('layout') }
		r := document.get_element_by_id('target')?.get_bounding_client_rect()
		assert r.width == expected[0], style
		assert r.height == expected[1], style
		document.finalize()
	}
}

fn test_ladybird_ratio_blocks_preserve_the_translated_double_conversion() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}div{width:80px;aspect-ratio:2;box-sizing:border-box;border:3px solid;padding:5px}
	</style><div id="target"></div>')
	defer { document.finalize() }
	_ = run_document_layout(document, 320, 240) or { panic('layout') }
	r := document.get_element_by_id('target')?.get_bounding_client_rect()
	assert r.width == 74
	assert r.height == 45
}
