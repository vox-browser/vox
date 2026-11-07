module main

import painting

fn test_svg_filter_lengths_follow_the_user_space_transform() {
	blur := painting.GfxFilterNode{
		kind:       'blur'
		parameters: {
			'radius_x': 16.0
			'radius_y': 8.0
		}
	}
	scaled := native_svg_filter_parameters_in_user_space(blur, [0.1, 0, 0, 0.1, 5, 7]!)
	assert scaled[0] == f32(1.6) && scaled[1] == f32(0.8)
	assert native_svg_filter_parameters_in_user_space(blur, [f64(1), 0, 0, 1, 0, 0]!)[0] == 16
	offset := painting.GfxFilterNode{
		kind:       'offset'
		parameters: {
			'dx': 10.0
			'dy': 4.0
		}
	}
	// A quarter turn maps (10, 4) to (-4, 10).
	turned := native_svg_filter_parameters_in_user_space(offset, [f64(0), 1, -1, 0, 0, 0]!)
	assert turned[0] == -4 && turned[1] == 10
	flood := painting.GfxFilterNode{
		kind:       'flood'
		parameters: {
			'opacity': 0.5
		}
	}
	assert native_svg_filter_parameters_in_user_space(flood, [0.1, 0, 0, 0.1, 0, 0]!)[0] == 0.5
}
