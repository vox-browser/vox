module layout

import css
import math

fn radial_geometry_value(text string) css.StyleValue {
	mut parser := css.Parser.with_context(css.ParsingParams{}, text)
	value := parser.parse_css_value(.background_image) or { panic('invalid gradient') }
	list := value.as_value_list() or { panic('missing gradient list') }
	return list.value_at(0, false)
}

fn test_circle_extent_reaches_corner_without_ellipse_expansion() {
	for extent, expected in {
		'closest-side': 25.0
		'farthest-side': 150.0
		'closest-corner': math.sqrt(50.0 * 50 + 25.0 * 25)
		'farthest-corner': math.sqrt(150.0 * 150 + 75.0 * 75)
	} {
		gradient := resolve_background_gradient(radial_geometry_value('radial-gradient(circle ${extent} at 25% 75%, red 10px, blue)'),
			200, 100, css.LengthResolutionContext.default(), css.ColorResolutionContext{}) or { panic('missing gradient') }
		assert math.abs(gradient.radius_x * 200 - expected) < 1e-10
		assert math.abs(gradient.radius_y * 100 - expected) < 1e-10
		assert math.abs(gradient.stops[0].offset - 10 / expected) < 1e-10
	}
	implicit := resolve_background_gradient(radial_geometry_value('radial-gradient(circle at 25% 75%, red, blue)'),
		200, 100, css.LengthResolutionContext.default(), css.ColorResolutionContext{}) or { panic('missing gradient') }
	assert math.abs(implicit.radius_x * 200 - math.sqrt(150.0 * 150 + 75.0 * 75)) < 1e-10
}

fn test_ellipse_extent_keeps_its_side_aspect_ratio() {
	gradient := resolve_background_gradient(radial_geometry_value('radial-gradient(ellipse farthest-corner at 25% 75%, red, blue)'),
		200, 100, css.LengthResolutionContext.default(), css.ColorResolutionContext{}) or { panic('missing gradient') }
	assert math.abs(gradient.radius_x * 200 - 150 * math.sqrt(2.0)) < 1e-10
	assert math.abs(gradient.radius_y * 100 - 75 * math.sqrt(2.0)) < 1e-10
}
