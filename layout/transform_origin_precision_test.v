module layout

import css
import html
import math

fn test_percentage_transform_origin_preserves_the_center_between_layout_units() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		#target{width:10.015625px;height:20.015625px;transform:rotate(90deg);transform-origin:50% 50%}
		</style><div id="target"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 200, 200)
	target := document.get_element_by_id('target') or { panic('target') }
	computed := css.computed_properties_for_element(target) or { panic('computed') }
	matrix := resolved_computed_transform_with_origin_precision(computed,
		3.125, 5.75, 10.015625, 20.015625, true)
	// Rotation must leave the exact center fixed, including its 1/128 pixel.
	cx, cy := 8.1328125, 15.7578125
	assert math.abs(matrix.m11 * cx + matrix.m12 * cy + matrix.m14 - cx) < 1e-12
	assert math.abs(matrix.m21 * cx + matrix.m22 * cy + matrix.m24 - cy) < 1e-12
	legacy := resolved_computed_transform_with_origin_precision(computed,
		3.125, 5.75, 10.015625, 20.015625, false)
	assert math.abs(math.abs(legacy.m11 * cx + legacy.m12 * cy + legacy.m14 - cx) - .015625) < 1e-12
	assert math.abs(legacy.m21 * cx + legacy.m22 * cy + legacy.m24 - cy) < 1e-12
}
