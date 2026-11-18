module cpuraster

fn general_test_shape() Path {
	mut b := PathBuilder{}
	b.move_to(20, 14)
	b.line_to(70, 18)
	b.line_to(58, 60)
	b.line_to(24, 52)
	b.close()
	return b.detach()
}

fn general_test_alpha(pixels []u8, width int, x int, y int) u8 {
	return pixels[(y * width + x) * 4 + 3]
}

fn general_test_max_difference(a []u8, b []u8) int {
	mut worst := 0
	for i in 0 .. a.len {
		d := int(a[i]) - int(b[i])
		if d > worst { worst = d }
		if -d > worst { worst = -d }
	}
	return worst
}

// On draws the exact ports cover, the device-space fallback follows the same
// graph: it must stay within a couple of levels of the exact Skia result.
fn test_general_blur_and_drop_shadow_track_exact_layers() {
	transform := [f32(1.25), 0, 0, 0.8, 6, 5]!
	for specs in [[CanvasFilterSpec{kind: 0, radius: 3}], [CanvasFilterSpec{kind: 1, radius: 2.5,
		offset_x: 6, offset_y: -4, color: 0xc0204080}]] {
		step := if specs[0].kind == 0 {
			CanvasFilterStep{kind: .blur, sigma: 3}
		} else {
			CanvasFilterStep{kind: .drop_shadow, sigma: 2.5, offset_x: 6, offset_y: -4, color: 0xc0204080}
		}
		mut exact := []u8{len: 96 * 80 * 4}
		assert fill_canvas_path(mut exact, 96, 80, 96 * 4, 2, general_test_shape(), transform,
			0xe0c04020, none, 1, .src_over, 0, [], new_canvas_filter([step]))
		mut general := []u8{len: 96 * 80 * 4}
		assert draw_general_canvas_path(mut general, 96, 80, 96 * 4, 2, general_test_shape(),
			transform, 0xe0c04020, none, 1, .src_over, none, 0, [], specs)
		assert exact.any(it != 0)
		difference := general_test_max_difference(exact, general)
		assert difference <= 3, 'general ${specs[0].kind} differs by ${difference}'
	}
}

fn test_general_tint_matches_scalar_coverage_and_preserves_tail() {
	width, height := 1031, 513
	length := width * height * 4 + 3
	color := u32(0xad277de1)
	for coverage in [f32(-1), 0, 0.541, 1.05] {
		mut reference := BlurImage{[]u8{len: 256 * 4, init: u8(index / 4)}, 256, 1}
		general_tint_with_coverage(mut reference, color, coverage)
		mut image := BlurImage{[]u8{len: length, init: u8(index / 4)}, width, height}
		general_tint_with_coverage(mut image, color, coverage)
		for i := 0; i < length - 3; i++ {
			assert image.pixels[i] == reference.pixels[i % reference.pixels.len]
		}
		for i in length - 3 .. length {
			assert image.pixels[i] == u8(i / 4)
		}
	}
}

fn test_general_crop_matches_pixel_centers_at_fractional_and_large_origins() {
	width, height := 1441, 927
	pixel_bytes := width * height * 4
	image := BlurImage{[]u8{len: pixel_bytes + 3, init: u8(index * 41 + index / 157)}, width, height}
	for origin in [IRect{-27, 61, 0, 0}, IRect{16777214, -16777222, 0, 0}] {
		x, y := f32(origin.left), f32(origin.top)
		for crop in [
			Rect{x + 5.5, y + 2.5, x + f32(width) - 7.5, y + f32(height) - 2.25},
			Rect{x - 1, y - 1, x + f32(width) + 8, y + f32(height) + 8},
			Rect{x + f32(width) + 8, y, x + f32(width) + 18, y + 100},
		] {
			mut expected := image.pixels.clone()
			for row in 0 .. height {
				cy := f32(origin.top + row) + f32(0.5)
				for column in 0 .. width {
					cx := f32(origin.left + column) + f32(0.5)
					if cy < crop.top || cy >= crop.bottom || cx < crop.left || cx >= crop.right {
						index := (row * width + column) * 4
						for channel in 0 .. 4 {
							expected[index + channel] = 0
						}
					}
				}
			}
			mut actual := general_crop(image, crop, origin)
			matches := actual.pixels == expected
			assert matches
			assert actual.width == width && actual.height == height
			original := image.pixels[0]
			actual.pixels[0] = original ^ 0xff
			assert image.pixels[0] == original
		}
	}
}

fn test_general_integer_offset_preserves_clipped_rows_and_transparent_edges() {
	width, height := 1401, 929
	image := BlurImage{[]u8{len: width * height * 4, init: u8(index * 67 + index / 279)}, width, height}
	dx, dy := -11, 13
	actual := general_offset(image, f32(dx), f32(dy))
	mut expected := []u8{len: image.pixels.len}
	for row in dy .. height {
		src := ((row - dy) * width - dx) * 4
		dst := row * width * 4
		bytes := (width + dx) * 4
		copy(mut expected[dst..dst + bytes], image.pixels[src..src + bytes])
	}
	matches := actual.pixels == expected
	assert matches
}

// A rotated layer, which the exact ports decline, blurs the rotated shape:
// coverage spreads past its edges, and the clip still bounds the result.
fn test_general_blur_under_rotation_spreads_and_clips() {
	transform := [f32(0.94), 0.34, -0.34, 0.94, 30, -4]!
	mut sharp := []u8{len: 120 * 100 * 4}
	assert fill_canvas_path(mut sharp, 120, 100, 120 * 4, 2, general_test_shape(), transform,
		0xff2050c0, none, 1, .src_over, 0, [], none)
	mut blurred := []u8{len: 120 * 100 * 4}
	clip := rect_path(Rect{0, 0, 60, 100})
	assert draw_general_canvas_path(mut blurred, 120, 100, 120 * 4, 2, general_test_shape(),
		transform, 0xff2050c0, none, 1, .src_over, none, 0, [clip], [CanvasFilterSpec{
		kind: 0
		radius: 4
	}])
	mut spread := 0
	for y in 0 .. 100 {
		for x in 0 .. 60 {
			if general_test_alpha(sharp, 120, x, y) == 0 && general_test_alpha(blurred, 120, x, y) > 0 {
				spread++
			}
		}
		for x in 61 .. 120 {
			assert general_test_alpha(blurred, 120, x, y) == 0
		}
	}
	assert spread > 50
}

fn general_test_square() BlurImage {
	mut image := BlurImage{[]u8{len: 40 * 40 * 4}, 40, 40}
	for y in 15 .. 25 {
		for x in 15 .. 25 {
			for c in 0 .. 4 {
				image.pixels[(y * 40 + x) * 4 + c] = 255
			}
		}
	}
	return image
}

fn general_test_coverage(image BlurImage) int {
	mut count := 0
	for i := 3; i < image.pixels.len; i += 4 {
		if image.pixels[i] != 0 { count++ }
	}
	return count
}

// feMorphology, feOffset, feMerge and the filter region evaluate in device
// space, with -1 standing for the incoming image.
fn test_general_svg_graph_nodes() {
	square := general_test_square()
	layer := IRect{0, 0, 40, 40}
	space := GeneralFilterSpace{width: 40, height: 40}
	dilated := general_svg_graph(square, SvgFilterGraph{
		nodes: [SvgFilterNode{kind: .dilate, inputs: [-1], x: 2, y: 2}]
		root: 0
		region: [f32(0), 0, 1, 1]!
	}, layer, space)
	assert general_test_coverage(dilated) == 14 * 14
	eroded := general_svg_graph(square, SvgFilterGraph{
		nodes: [SvgFilterNode{kind: .erode, inputs: [-1], x: 2, y: 2}]
		root: 0
		region: [f32(0), 0, 1, 1]!
	}, layer, space)
	assert general_test_coverage(eroded) == 6 * 6
	merged := general_svg_graph(square, SvgFilterGraph{
		nodes: [SvgFilterNode{kind: .offset, inputs: [-1], x: 12, y: 0},
			SvgFilterNode{kind: .merge, inputs: [-1, 0]}]
		root: 1
		region: [f32(0), 0, 1, 1]!
	}, layer, space)
	assert general_test_coverage(merged) == 2 * 10 * 10
	cropped := general_svg_graph(square, SvgFilterGraph{
		nodes: [SvgFilterNode{kind: .dilate, inputs: [-1], x: 2, y: 2}]
		root: 0
		region: [f32(20), 0, 20, 40]!
		object_bounds: false
	}, layer, space)
	assert general_test_coverage(cropped) == 7 * 14
	// A graph referring forward is invalid and passes its source through.
	invalid := general_svg_graph(square, SvgFilterGraph{
		nodes: [SvgFilterNode{kind: .blur, inputs: [1], x: 2, y: 2}]
		root: 0
	}, layer, space)
	assert invalid.pixels == square.pixels
}

// A color matrix that adds alpha changes transparent black, so the filter
// result covers the whole clip, as a decal layer around it does.
fn test_general_flooding_matrix_covers_the_clip() {
	mut matrix := [20]f32{}
	matrix[3] = 0
	matrix[18] = 1
	matrix[19] = 0.5
	mut pixels := []u8{len: 50 * 40 * 4}
	clip := rect_path(Rect{10, 10, 40, 30})
	assert draw_general_canvas_path(mut pixels, 50, 40, 50 * 4, 2, rect_path(Rect{20, 15, 25, 20}),
		[f32(1), 0, 0, 1, 0, 0]!, 0xff000000, none, 1, .src_over, none, 0, [clip], [CanvasFilterSpec{
		kind: 2
		matrix: matrix
		clamp: true
	}])
	assert general_test_alpha(pixels, 50, 12, 12) >= 127
	assert general_test_alpha(pixels, 50, 22, 17) == 255
	assert general_test_alpha(pixels, 50, 5, 5) == 0
	assert general_test_alpha(pixels, 50, 45, 35) == 0
}

// Chromium's opacity() is FEComponentTransfer's 8-bit alpha table.
fn test_general_chromium_opacity_uses_alpha_table() {
	image := general_test_square()
	mut matrix := [20]f32{}
	matrix[18] = .5
	result := apply_general_filter(image, CanvasFilterSpec{kind: 4, matrix: matrix}, IRect{0, 0, 40, 40},
		GeneralFilterSpace{chromium: true, width: 40, height: 40})
	index := (20 * 40 + 20) * 4
	assert result.pixels[index + 3] == 127
	assert result.pixels[index] == 127
}

// An inner hole that crosses the outer edge needs a boolean difference the
// exact port does not take; the fallback still casts the shadow inside the
// content clip.
fn test_general_inner_shadow_with_intersecting_hole() {
	pixels := rasterize_shadow(48, 48, ShadowCommand{
		kind: 1
		color: 0xff0000ff
		blur: 4
		transform: [f32(1), 0, 0, 1, 0, 0]!
		content: ShadowRect{rect: [f32(4), 4, 40, 40]!}
		outer: ShadowRect{rect: [f32(0), 0, 48, 48]!}
		inner: ShadowRect{rect: [f32(10), 10, 44, 30]!, radii: [f32(12), 12, 12, 12, 12, 12, 12, 12]!}
	}) or { panic(err) }
	assert general_test_alpha(pixels, 48, 2, 2) == 0
	assert general_test_alpha(pixels, 48, 6, 24) > 100
	assert general_test_alpha(pixels, 48, 30, 20) < general_test_alpha(pixels, 48, 6, 24)
	assert general_test_alpha(pixels, 48, 24, 38) > 0
}

// Surfaces wider than Skia's untiled limit draw tile by tile.
fn test_shadow_surfaces_past_the_untiled_limit_tile() {
	width := max_untiled_dimension + 300
	shape := ShadowRect{rect: [f32(8000), 4, 400, 8]!}
	pixels := rasterize_shadow(width, 16, ShadowCommand{
		kind: 0
		color: 0xff00ff00
		blur: 2
		transform: [f32(1), 0, 0, 1, 0, 0]!
		content: ShadowRect{}
		outer: shape
	}) or { panic(err) }
	for x in [8100, 8191, 8192, 8300] {
		assert general_test_alpha(pixels, width, x, 8) == 255
	}
	assert general_test_alpha(pixels, width, 100, 8) == 0
}
