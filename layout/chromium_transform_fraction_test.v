module layout

import css
import html
import math

fn transform_fraction_matrix(style string, origin string, left f64, top f64,
	chromium bool) css.FloatMatrix4x4 {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{position:absolute;left:${left}px;top:${top}px;width:230.390625px;height:133.6875px;font-size:20px;transform-origin:${origin};${style}}</style><div id="target"></div>')
	defer { document.finalize() }
	if chromium { document.set_font_rendering_policy(.chromium) }
	target := document.get_element_by_id('target') or { panic('missing target') }
	root := layout_document_typed_in_viewport(document, 1280, 800)
	box := root.find_box(i64(target.as_node().unique_id())) or { panic('missing box') }
	return box.own_paint_transform_4x4
}

fn test_chromium_percentage_transform_keeps_the_brave_image_translation() {
	style := 'transform:translate(11%,-84.85%)'
	matrix := transform_fraction_matrix(style, '50% 50%', 1001.609375, 363.03125, true)
	assert math.abs(matrix.m14 - 25.34296875) < 1e-10
	assert math.abs(matrix.m24 + 113.43384375) < 1e-10
	// Native float placement after adding the snapped image origin matches
	// Brave's scale-1 paint record, including its final float rounding.
	assert f32(f32(matrix.m14) + f32(1002)) == f32(1027.343017578125)
	assert f32(f32(matrix.m24) + f32(363)) == f32(249.566162109375)
	legacy := transform_fraction_matrix(style, '50% 50%', 1001.609375, 363.03125, false)
	assert legacy.m14 == f32(25.34375)
	assert legacy.m24 == f32(-113.4375)
}

fn test_chromium_transform_and_individual_translate_keep_fractional_percentages() {
	for style in ['transform:translate(11%,-84.85%)', 'translate:11% -84.85%'] {
		matrix := transform_fraction_matrix(style, '0 0', 0, 0, true)
		assert math.abs(matrix.m14 - 25.34296875) < 1e-10
		assert math.abs(matrix.m24 + 113.43384375) < 1e-10
	}
}

fn test_chromium_transform_lengths_and_calculations_do_not_snap_to_layout_units() {
	calculated := transform_fraction_matrix('transform:translate(calc(11% + .003px),calc(-84.85% - .002px))', '0 0', 0, 0, true)
	assert math.abs(calculated.m14 - 25.34596875) < 1e-10
	assert math.abs(calculated.m24 + 113.43584375) < 1e-10
	absolute := transform_fraction_matrix('transform:translate(.003px,-.002px)', '0 0', 0, 0, true)
	assert math.abs(absolute.m14 - .003) < 1e-10
	assert math.abs(absolute.m24 + .002) < 1e-10
	relative := transform_fraction_matrix('transform:translate(.001em,.002rem)', '0 0', 0, 0, true)
	assert math.abs(relative.m14 - .02) < 1e-10
	assert math.abs(relative.m24 - .032) < 1e-10
}
