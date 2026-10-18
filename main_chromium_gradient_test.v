module main

import css
import layout

fn test_chromium_linear_gradient_keeps_original_alpha_and_hard_stops() {
	gradient := layout.LinearGradient{
		y2: 1
		stops: [layout.GradientStop{css.Color{0,0,0,0}, 0},
			layout.GradientStop{css.Color{0,0,0,153}, .5},
			layout.GradientStop{css.Color{0,0,0,255}, .5},
			layout.GradientStop{css.Color{0,0,0,255}, 1}]
	}
	data := chromium_linear_gradient_stop_data(gradient, .5) or { panic('eligible gradient') }
	assert data.len == 20
	assert data[8] == f32(.3)
	assert data[13] == f32(.5)
	assert data[9] == data[14] && data[9] == f32(.5)
	assert gradient.stops.len == 4
}

fn test_chromium_linear_gradient_falls_back_for_other_interpolation_semantics() {
	gradient := layout.LinearGradient{stops: [layout.GradientStop{css.Color{255,0,0,64}, 0},
		layout.GradientStop{css.Color{0,0,255,255}, 1}]}
	assert chromium_linear_gradient_stop_data(gradient, 1) == none
	opaque := layout.LinearGradient{colors: [css.Color{255,0,0,255}, css.Color{0,0,255,255}]}
	assert (chromium_linear_gradient_stop_data(opaque, 1) or { panic('opaque sRGB') }).len == 10
	assert chromium_linear_gradient_stop_data(layout.LinearGradient{...opaque, radial: true}, 1) == none
	assert chromium_linear_gradient_stop_data(layout.LinearGradient{...opaque, kind: 'conic'}, 1) == none
	assert chromium_linear_gradient_stop_data(layout.LinearGradient{...opaque,
		interpolation_method: css.ColorInterpolationMethod(css.RectangularColorSpace.oklab)}, 1) == none
	out_of_range := layout.LinearGradient{stops: [layout.GradientStop{css.Color{0,0,0,0}, -.5},
		layout.GradientStop{css.Color{0,0,0,255}, 1}]}
	assert chromium_linear_gradient_stop_data(out_of_range, 1) == none
}

fn test_chromium_linear_gradient_discards_invisible_rgb_before_constant_color_interpolation() {
 gradient := layout.LinearGradient{stops: [layout.GradientStop{css.Color{102,102,102,0}, .7203},
  layout.GradientStop{css.Color{0,0,0,255}, .9108}]}
 data := chromium_linear_gradient_stop_data(gradient, 1) or { panic('transparent RGB is not premultiplied color') }
 assert data == [f32(0),0,0,0,.7203,0,0,0,1,.9108]
 assert gradient.stops[0].color.r == 102
 // A second visible color still requires general premultiplied interpolation.
 varying := layout.LinearGradient{stops: [layout.GradientStop{css.Color{102,102,102,0},0},
  layout.GradientStop{css.Color{255,0,0,128},.5},layout.GradientStop{css.Color{0,0,0,255},1}]}
 assert chromium_linear_gradient_stop_data(varying, 1) == none
}
