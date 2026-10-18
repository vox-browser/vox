module main

import css
import layout
import painting
import html

fn test_chromium_linear_gradient_keeps_original_alpha_and_hard_stops() {
	gradient := layout.LinearGradient{
		y2:    1
		stops: [layout.GradientStop{css.Color{0, 0, 0, 0}, 0},
			layout.GradientStop{css.Color{0, 0, 0, 153}, .5},
			layout.GradientStop{css.Color{0, 0, 0, 255}, .5},
			layout.GradientStop{css.Color{0, 0, 0, 255}, 1}]
	}
	data := chromium_linear_gradient_stop_data(gradient, .5) or { panic('eligible gradient') }
	assert data.len == 20
	assert data[8] == f32(.3)
	assert data[13] == f32(.5)
	assert data[9] == data[14] && data[9] == f32(.5)
	assert gradient.stops.len == 4
}

fn test_chromium_linear_gradient_falls_back_for_other_interpolation_semantics() {
	gradient := layout.LinearGradient{
		stops: [layout.GradientStop{css.Color{255, 0, 0, 64}, 0},
			layout.GradientStop{css.Color{0, 0, 255, 255}, 1}]
	}
	assert chromium_linear_gradient_stop_data(gradient, 1) == none
	opaque := layout.LinearGradient{
		colors: [css.Color{255, 0, 0, 255}, css.Color{0, 0, 255, 255}]
	}
	assert (chromium_linear_gradient_stop_data(opaque, 1) or { panic('opaque sRGB') }).len == 10
	assert chromium_linear_gradient_stop_data(layout.LinearGradient{ ...opaque, radial: true }, 1) == none
	assert chromium_linear_gradient_stop_data(layout.LinearGradient{ ...opaque, kind: 'conic' }, 1) == none
	assert chromium_linear_gradient_stop_data(layout.LinearGradient{
		...opaque
		interpolation_method: css.ColorInterpolationMethod(css.RectangularColorSpace.oklab)
	}, 1) == none
	out_of_range := layout.LinearGradient{
		stops: [layout.GradientStop{css.Color{0, 0, 0, 0}, -.5},
			layout.GradientStop{css.Color{0, 0, 0, 255}, 1}]
	}
	assert chromium_linear_gradient_stop_data(out_of_range, 1) == none
}

fn test_chromium_linear_gradient_discards_invisible_rgb_before_constant_color_interpolation() {
	gradient := layout.LinearGradient{
		stops: [layout.GradientStop{css.Color{102, 102, 102, 0}, .7203},
			layout.GradientStop{css.Color{0, 0, 0, 255}, .9108}]
	}
	data := chromium_linear_gradient_stop_data(gradient, 1) or {
		panic('transparent RGB is not premultiplied color')
	}
	assert data == [f32(0), 0, 0, 0, .7203, 0, 0, 0, 1, .9108]
	assert gradient.stops[0].color.r == 102
	// A second visible color still requires general premultiplied interpolation.
	varying := layout.LinearGradient{
		stops: [layout.GradientStop{css.Color{102, 102, 102, 0}, 0},
			layout.GradientStop{css.Color{255, 0, 0, 128}, .5},
			layout.GradientStop{css.Color{0, 0, 0, 255}, 1}]
	}
	assert chromium_linear_gradient_stop_data(varying, 1) == none
}

fn test_chromium_linear_gradient_uses_float_angle_points_in_local_tile_coordinates() {
	tile := painting.Rect{20, 20, 269, 151}
	// Float reference values from Blink EndPointsFromAngle, compiled for arm64
	// with contraction disabled, matching its C++ arithmetic.
	angled := chromium_linear_gradient_points(layout.LinearGradient{ css_angle_degrees: 222 }, tile)
	assert angled == [f32(232.263672), -33.0775528, 36.7363281, 184.077545]!
	for angle, expected in {
		0:   [f32(0), 151, 0, 0]!
		90:  [f32(0), 0, 269, 0]!
		180: [f32(0), 0, 0, 151]!
		270: [f32(269), 0, 0, 0]!
	} {
		assert chromium_linear_gradient_points(layout.LinearGradient{ css_angle_degrees: f64(angle) },
			tile) == expected
	}
	assert chromium_linear_gradient_points(layout.LinearGradient{ css_angle_degrees: -138 }, tile) == angled
	assert chromium_linear_gradient_points(layout.LinearGradient{ css_angle_degrees: 582 }, tile) == angled
	// Detached commands without a source angle keep their existing endpoints.
	assert chromium_linear_gradient_points(layout.LinearGradient{ x1: .25, y1: .5, x2: .75, y2: 1 }, painting.Rect{10, 20, 100, 80}) == [
		f32(35),
		60,
		85,
		100,
	]!
}

fn test_retained_css_linear_gradient_carries_the_source_angle() {
	mut document :=
		html.parse_document('<!doctype html><style>body{margin:0}div{width:269px;height:151px;background:linear-gradient(222deg,#6660 72.03%,black 91.08%)}</style><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := root.paint_commands().filter(it.kind == 'fill_gradient')
	assert commands.len == 1
	gradient := commands[0].gradient or { panic('missing retained gradient') }
	assert gradient.css_angle_degrees? == 222
}
