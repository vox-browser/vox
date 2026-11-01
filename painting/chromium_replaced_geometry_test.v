module painting

import css

fn chromium_replaced_rect(box Rect, natural Size, fit css.ObjectFit, chromium bool) ?Rect {
	return get_replaced_box_painting_rect(box, natural, fit, css.Position{},
		css.LengthResolutionContext{ ...css.LengthResolutionContext.default(), use_chromium_geometry: chromium })
}

fn test_chromium_object_fit_compares_the_quantized_height_before_switching_axes() {
	box := Rect{72.5625, 5.296875, 125.6875, 69.984375}
	actual := chromium_replaced_rect(box, Size{501, 279}, .contain, true) or { panic('missing rectangle') }
	assert actual == box
	legacy := chromium_replaced_rect(box, Size{501, 279}, .contain, false) or { panic('missing default rectangle') }
	assert legacy.width == 125.671875
	assert legacy.height == 69.984375
}

fn test_chromium_object_fit_uses_truncating_fixed_point_products() {
	contained := chromium_replaced_rect(Rect{0, 0, 100, 100}, Size{3, 7}, .contain, true) or { panic('contain') }
	assert contained.width == 42.84375
	assert contained.height == 100
	covered := chromium_replaced_rect(Rect{0, 0, 100, 100}, Size{3, 7}, .cover, true) or { panic('cover') }
	assert covered.width == 100
	assert covered.height == 233.328125
	legacy := chromium_replaced_rect(Rect{0, 0, 100, 100}, Size{3, 7}, .contain, false) or { panic('default') }
	assert legacy.width == 42.859375
}

fn test_chromium_scale_down_keeps_the_intrinsic_size_when_it_is_smaller() {
	intrinsic := chromium_replaced_rect(Rect{0, 0, 100, 100}, Size{3, 7}, .scale_down, true) or { panic('intrinsic') }
	assert intrinsic.width == 3 && intrinsic.height == 7
	scaled := chromium_replaced_rect(Rect{0, 0, 2, 2}, Size{3, 7}, .scale_down, true) or { panic('scaled') }
	assert scaled.width == 0.84375 && scaled.height == 2
}

fn test_chromium_object_fit_saturates_large_products_and_rejects_subunit_intrinsics() {
	maximum := css.CSSPixels.max().to_double()
	fit := chromium_replaced_rect(Rect{0, 0, maximum, 1}, Size{0.015625, maximum}, .cover, true) or { panic('large ratio') }
	assert fit.width == maximum && fit.height == maximum
	assert chromium_replaced_rect(Rect{0, 0, 10, 10}, Size{0.001, 2}, .contain, true) == none
}
