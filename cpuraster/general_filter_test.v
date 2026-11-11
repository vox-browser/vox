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
