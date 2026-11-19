// vtest build: macos || linux
module ggshape

import gg.canvas

fn test_shared_svg_path_pixels() {
	mut ctx := canvas.new_gpu_context() or { panic(err) }
	defer {
		ctx.free()
	}
	// Two closed contours with the same winding; even-odd leaves the inner
	// contour transparent. The path matrix translates both contours.
	segments := [
		f32(0), 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		1, 22, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		1, 22, 21, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		1, 2, 21, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		1, 16, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		1, 16, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		1, 8, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	]
	mut path := C.VoxGraphitePath{
		matrix:        [f32(1), 0, 4, 0, 1, 2, 0, 0, 1]!
		segments:      segments.data
		segment_count: i32(segments.len / 12)
		even_odd:      1
		red:           255
		alpha:         128
	}
	width := i32(32)
	height := i32(26)
	pitch := width * 4 + 8
	mut pixels := []u8{len: pitch * height, init: 42}
	assert draw_path_with_context(mut ctx, pixels.data, width, height, pitch, 0, &path, false) == 1
	for y in 0 .. height {
		for x in 0 .. width {
			i := y * pitch + x * 4
			inside := x >= 6 && x < 26 && y >= 5 && y < 23
			hole := x >= 12 && x < 20 && y >= 9 && y < 17
			expected := if inside && !hole { u8(128) } else { u8(0) }
			assert pixels[i..i + 4] == [u8(0), 0, expected, expected], '${x}, ${y}'
		}
		end := (y + 1) * pitch
		assert pixels[end - 8..end] == []u8{len: 8, init: 42}
	}
	for y in 0 .. height {
		for x in 0 .. width {
			i := y * pitch + x * 4
			pixels[i] = 255
			pixels[i + 1] = 0
			pixels[i + 2] = 0
			pixels[i + 3] = 255
		}
	}
	assert draw_path_with_context(mut ctx, pixels.data, width, height, pitch, 1, &path, true) == 1
	fill := 6 * pitch + 7 * 4
	hole := 12 * pitch + 14 * 4
	assert pixels[fill..fill + 4] == [u8(127), 0, 128, 255]
	assert pixels[hole..hole + 4] == [u8(255), 0, 0, 255]

	stops := [f32(1), 0, 0, 1, 0, 0, 1, 0, 1, 1]
	path.gradient = 1
	path.gradient_points = [f32(7), 3, 17, 3, 0, 0]!
	path.gradient_matrix = [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
	path.stop_count = 2
	path.stops = stops.data
	path.opacity = 1
	assert draw_path_with_context(mut ctx, pixels.data, width, height, pitch, 0, &path, false) == 1
	left := 6 * pitch + 8 * 4
	right := 6 * pitch + 23 * 4
	assert pixels[left..left + 4] == [u8(0), 0, 255, 255]
	assert pixels[right..right + 4] == [u8(0), 255, 0, 255]
	assert pixels[hole..hole + 4] == [u8(0), 0, 0, 0]

	// The path and gradient matrices place the common center at (10.5, 7.5).
	// Radii 3 and 11 leave a red inner disk, then interpolate towards green.
	path.gradient = 2
	path.gradient_points = [f32(4.5), 4.5, 3, 4.5, 4.5, 11]!
	path.gradient_matrix = [f32(1), 0, 2, 0, 1, 1, 0, 0, 1]!
	assert draw_path_with_context(mut ctx, pixels.data, width, height, pitch, 0, &path, false) == 1
	inner := 7 * pitch + 10 * 4
	middle := 7 * pitch + 17 * 4
	outer := 7 * pitch + 23 * 4
	assert pixels[inner..inner + 4] == [u8(0), 0, 255, 255]
	assert pixels[middle] == 0 && pixels[middle + 3] == 255
	assert pixels[middle + 1] in [u8(127), 128] && pixels[middle + 2] in [u8(127), 128]
	assert pixels[outer..outer + 4] == [u8(0), 255, 0, 255]
	assert pixels[hole..hole + 4] == [u8(0), 0, 0, 0]

	path.tile_mode = 1
	assert draw_path_with_context(mut ctx, pixels.data, width, height, pitch, 0, &path, false) == 1
	// Repeat at the center uses t = -3/8 modulo one = 5/8.
	assert pixels[inner] == 0 && pixels[inner + 3] == 255
	assert pixels[inner + 1] in [u8(159), 160] && pixels[inner + 2] in [u8(95), 96]
	// The same paint with five stops and half opacity exercises the 8-stop
	// alpha shader. Reflect at the center maps t = -3/8 to 3/8.
	reflect_stops := [f32(1), 0, 0, 1, 0, 0.75, 0.25, 0, 1, 0.25, 0.5, 0.5, 0, 1, 0.5,
		0.25, 0.75, 0, 1, 0.75, 0, 1, 0, 1, 1]
	path.tile_mode = 2
	path.stops = reflect_stops.data
	path.stop_count = 5
	path.opacity = 0.5
	assert draw_path_with_context(mut ctx, pixels.data, width, height, pitch, 0, &path, false) == 1
	assert pixels[inner] == 0 && pixels[inner + 3] in [u8(127), 128]
	assert pixels[inner + 1] in [u8(47), 48] && pixels[inner + 2] in [u8(79), 80]
	path.tile_mode = 0
	path.stops = stops.data
	path.stop_count = 2
	path.opacity = 1

	// With the outer center shifted four pixels right, the forward ramp
	// has length 12. A sample seven pixels from the focal center is at 1/3.
	path.gradient_points = [f32(4.5), 4.5, 3, 8.5, 4.5, 11]!
	assert draw_path_with_context(mut ctx, pixels.data, width, height, pitch, 0, &path, false) == 1
	assert pixels[inner..inner + 4] == [u8(0), 0, 255, 255]
	assert pixels[middle + 1] in [u8(84), 85, 86] && pixels[middle + 2] in [u8(169), 170, 171]
	// Four pixels perpendicular to the line of centers gives t ≈ 0.129.
	across := 11 * pitch + 10 * 4
	assert pixels[across + 1] in [u8(32), 33, 34] && pixels[across + 2] in [u8(221), 222, 223]

	// With the circles touching, the axis ramp spans 16 pixels. The
	// half-plane behind their common tangent has zero alpha.
	path.gradient_points = [f32(4.5), 4.5, 3, 12.5, 4.5, 11]!
	assert draw_path_with_context(mut ctx, pixels.data, width, height, pitch, 0, &path, false) == 1
	behind := 7 * pitch + 6 * 4
	assert pixels[behind..behind + 4] == [u8(0), 0, 0, 0]
	assert pixels[inner..inner + 4] == [u8(0), 0, 255, 255]
	assert pixels[middle + 1] in [u8(63), 64, 65] && pixels[middle + 2] in [u8(190), 191, 192]
	assert pixels[across + 1] in [u8(36), 37, 38] && pixels[across + 2] in [u8(217), 218, 219]
	path.stops = reflect_stops.data
	path.stop_count = 5
	path.opacity = 0.5
	assert draw_path_with_context(mut ctx, pixels.data, width, height, pitch, 0, &path, false) == 1
	assert pixels[behind..behind + 4] == [u8(0), 0, 0, 0]
	assert pixels[middle + 1] in [u8(31), 32, 33] && pixels[middle + 2] in [u8(95), 96]
	assert pixels[middle + 3] in [u8(127), 128]
	path.stops = stops.data
	path.stop_count = 2
	path.opacity = 1

	path.stroke = 1
	path.stroke_width = 2
	path.gradient_points = [f32(4.5), 4.5, 3, 4.5, 4.5, 11]!
	assert draw_path_with_context(mut ctx, pixels.data, width, height, pitch, 0, &path, false) == 1
	assert pixels[inner..inner + 4] == [u8(0), 0, 0, 0]
	stroke := 4 * pitch + 10 * 4
	assert pixels[stroke..stroke + 4] == [u8(0), 0, 255, 255]

	before := pixels.clone()
	path.tile_mode = 1
	// Crossing circles still use the fallback.
	path.gradient_points = [f32(4.5), 4.5, 3, 14.5, 4.5, 11]!
	assert draw_path_with_context(mut ctx, pixels.data, width, height, pitch, 1, &path, false) == 0
	assert pixels == before
	// This offset is inside the outer circle in f64 but rounds to a
	// tangent at the fragment shader's f32 precision.
	path.gradient_points = [f32(0), 0, 3, 8191.99951171875, 2.5, 8195]!
	assert draw_path_with_context(mut ctx, pixels.data, width, height, pitch, 1, &path, false) == 0
	assert pixels == before
	path.tile_mode = 0
	path.linear_color_space = 1
	assert draw_path_with_context(mut ctx, pixels.data, width, height, pitch, 1, &path, false) == 0
	assert pixels == before
}
