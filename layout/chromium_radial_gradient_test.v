module layout

import css
import math

fn chromium_radial_test_gradient(text string, width f64, height f64) LinearGradient {
	mut parser := css.Parser.with_context(css.ParsingParams{}, text)
	mut value := parser.parse_css_value(.background_image) or { panic('invalid gradient') }
	if list := value.as_value_list() { value = list.value_at(0, false) }
	return resolve_background_gradient(value, width, height,
		css.LengthResolutionContext.default(), css.ColorResolutionContext{}) or {
		panic('missing resolved gradient')
	}
}

fn test_radial_float_geometry_keeps_percentage_center_and_corner_radius() {
	gradient := chromium_radial_test_gradient('radial-gradient(ellipse at 60% 110%, #43699557, transparent 65%)', 1182, 438)
	geometry := gradient.css_radial_geometry or { panic('missing float geometry') }
	assert geometry.width == 1182 && geometry.height == 438
	assert geometry.center_x == f32(709.20001220703125)
	assert geometry.center_y == f32(481.800018310546875)
	assert geometry.radius_x == f32(1002.9603271484375)
	assert f32(1) / (geometry.radius_x / geometry.radius_y) == f32(.6793569326400757)
	// The regular normalized transport keeps its existing independent behavior.
	assert math.abs(gradient.center_x - .6) < 1e-12
	assert math.abs(gradient.center_y - 1.1) < 1e-12
}

fn test_radial_float_geometry_preserves_explicit_lengths_and_circle_extents() {
	explicit := chromium_radial_test_gradient('radial-gradient(ellipse 100px 50px at 25% 75%, red, blue)', 200, 100)
	assert explicit.css_radial_geometry? == CSSRadialGradientGeometry{200, 100, 50, 75, 100, 50}
	circle := chromium_radial_test_gradient('radial-gradient(circle closest-side at 25% 75%, red, blue)', 200, 100)
	assert circle.css_radial_geometry? == CSSRadialGradientGeometry{200, 100, 50, 75, 25, 25}
	zero := chromium_radial_test_gradient('radial-gradient(red, blue)', 0, 0)
	assert zero.css_radial_geometry == none
}

fn test_radial_float_corner_extent_uses_the_selected_corner() {
	rx, ry := chromium_radial_extent(.farthest_corner, 30, 40, 100, 80, true)
	assert rx == ry && rx == f32(80.6225738525390625)
	ax, ay := chromium_radial_extent(.closest_side, 30, 40, 100, 80, false)
	assert ax == 30 && ay == 40
	bx, by := chromium_radial_extent(.farthest_side, 30, 40, 100, 80, false)
	assert bx == 70 && by == 40
	ex, ey := chromium_radial_extent(.farthest_corner, 0, 0, 0, 0, false)
	assert ex == 0 && ey == 0
}
