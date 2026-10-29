module platform

import os

fn test_downloaded_variable_face_coordinates_change_shaping_and_replay_identity() {
	bytes := os.read_bytes(os.join_path(os.dir(@FILE), '..', 'gfxfont', 'testdata', 'variable-font-example.woff2'))!
	path := prepare_font_data(bytes)?
	light := &Font{
		family:               'Variable fixture'
		source_path:          path
		point_size:           40
		requested_variations: [FontVariationAxis{ tag: 0x77676874, value: 100 }]
	}
	heavy := &Font{
		family:               'Variable fixture'
		source_path:          path
		point_size:           40
		requested_variations: [FontVariationAxis{ tag: 0x77676874, value: 900 }]
	}
	assert light.variations().len == 1
	assert heavy.variations().len == 1
	assert light.variations()[0].value < heavy.variations()[0].value
	assert shape_text(0, 0, 'Hamburgefontsiv', light, .common).width() != shape_text(0, 0, 'Hamburgefontsiv', heavy, .common).width()
	assert light.replay_face()?.replay_key() != heavy.replay_face()?.replay_key()
	assert light.replay_face()?.path == path
	assert heavy.font_path()? == path
}

fn test_static_sources_ignore_unsupported_variation_coordinates() {
	path := bundled_font_path('SerenitySans-Regular.ttf')?
	font := &Font{
		family:               'Static fixture'
		source_path:          path
		point_size:           20
		requested_variations: [FontVariationAxis{ tag: 0x77676874, value: 700 },
			FontVariationAxis{ tag: 0x54455354, value: 1 }]
	}
	assert font.variations().len == 0
	assert font.replay_face() == none
}
