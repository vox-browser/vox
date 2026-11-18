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

	before := pixels.clone()
	path.linear_color_space = 1
	assert draw_path_with_context(mut ctx, pixels.data, width, height, pitch, 1, &path, false) == 0
	assert pixels == before
}
