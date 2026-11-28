module main

import painting

fn test_png_capture_scale_preserves_the_elliptical_avatar_clip() {
	destination := painting.IntRect{92, 653, 18, 40}
	clip := [f32(92), 653, 18, 40, 9, 20, 9, 20, 9, 20, 9, 20]!
	geometry := sampled_png_paint_geometry(destination, clip, [f64(0.5), 0, 0, 0.5, 3, -7]!) or {
		panic('uniform capture scale declined')
	}
	assert geometry.x == 49 && geometry.y == 319.5
	assert geometry.width == 9 && geometry.height == 20
	assert geometry.clip == [f32(49), 319.5, 9, 20, 4.5, 10, 4.5, 10, 4.5, 10, 4.5, 10]!
	identity := sampled_png_paint_geometry(destination, clip, [f64(1), 0, 0, 1, 0, 0]!) or {
		panic('existing identity image declined')
	}
	assert identity.clip == clip
	assert identity.width == 18 && identity.height == 40
}

fn test_png_capture_scale_keeps_other_transform_sampling_on_existing_replay() {
	destination := painting.IntRect{92, 653, 18, 40}
	clip := [f32(92), 653, 18, 40, 9, 20, 9, 20, 9, 20, 9, 20]!
	for matrix in [[f64(0), 0, 0, 0, 0, 0]!, [f64(-1), 0, 0, -1, 0, 0]!, [f64(0.5), 0, 0, 1, 0,
		0]!, [f64(0), 1, -1, 0, 0, 0]!] {
		assert sampled_png_paint_geometry(destination, clip, matrix) == none
	}
}
