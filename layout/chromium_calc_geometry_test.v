module layout

import html

fn calc_card_geometry(chromium bool) []f64 {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}.row{margin-left:48px;width:1184px;display:flex;gap:16px}.card{box-sizing:border-box;flex:0 0 calc((100% - 32px)/3);padding:23px;border:1px solid;height:80px}</style><div class="row"><div class="card" id="a"></div><div class="card" id="b"></div><div class="card" id="c"></div></div>')
	defer { document.finalize() }
	if chromium { document.set_font_rendering_policy(.chromium) }
	_ = layout_document_typed_in_viewport(document, 1280, 200)
	mut result := []f64{}
	for id in ['a', 'b', 'c'] {
		box := document.get_element_by_id(id) or { panic('missing card') }
		rect := box.get_bounding_client_rect()
		result << rect.x
		result << rect.width
	}
	return result
}

fn test_chromium_calculated_flex_basis_keeps_exact_card_boundaries() {
	assert calc_card_geometry(true) == [48.0, 384.0, 448.0, 384.0, 848.0, 384.0]
	assert calc_card_geometry(false) == [48.0, 383.984375, 447.984375, 383.984375, 847.96875,
		383.984375]
}

fn test_chromium_calculated_box_limits_use_the_same_final_float_conversion() {
	for style in ['width:calc((100% - 32px)/3)', 'width:0;min-width:calc((100% - 32px)/3)',
		'width:100%;max-width:calc((100% - 32px)/3)'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#host{width:1184px}#target{height:10px;${style}}</style><div id="host"><div id="target"></div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1280, 200)
		target := document.get_element_by_id('target') or { panic('missing target') }
		assert target.get_bounding_client_rect().width == 384.0, style
	}
}
