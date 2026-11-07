module main

import layout
import painting

fn test_radial_gradient_uses_circle_and_centered_ellipse_transform() {
	gradient := layout.LinearGradient{
		kind:                'radial'
		css_radial_geometry: layout.CSSRadialGradientGeometry{1182, 438, f32(709.20001220703125), f32(481.800018310546875), f32(1002.9603271484375), f32(681.36810302734375)}
	}
	radial := chromium_radial_gradient_geometry(gradient, painting.Rect{49, 364, 1182, 438})
	assert radial[..6] == [f32(709.20001220703125), f32(481.800018310546875), 0,
		f32(709.20001220703125), f32(481.800018310546875), f32(1002.9603271484375)]
	assert radial[6..] == [f32(1), 0, 0, f32(.6793569326400757), 49, f32(518.48583984375)]
}

fn test_radial_gradient_preserves_fallback_for_detached_or_differently_sized_tiles() {
	gradient := layout.LinearGradient{
		kind:     'radial'
		center_x: .6
		center_y: 1.1
		radius_x: .75
		radius_y: .5
	}
	tile := painting.Rect{10, 20, 200, 100}
	expected := [f32(0), 0, 0, 0, 0, 1, 150, 0, 0, 50, 130, 130]!
	assert chromium_radial_gradient_geometry(gradient, tile) == expected
	assert chromium_radial_gradient_geometry(layout.LinearGradient{
		...gradient
		css_radial_geometry: layout.CSSRadialGradientGeometry{100, 100, 60, 110, 75, 50}
	}, tile) == expected
}
