// vtest build: macos
module ggshape

$if !macos {
	$compile_error('The gg.canvas browser adapters currently require macOS')
}

import gg.canvas

const test_width = 48

const test_height = 32

// base_shape()'s corners, two of them elliptical.
const base_radii = [canvas.Point{6, 6}, canvas.Point{4, 3}, canvas.Point{8, 8}, canvas.Point{2, 5}]!

// Circular corners: gg.canvas strokes elliptical ones with the tessellating
// path renderer, which is not ported yet.
const circular_radii = [canvas.Point{6, 6}, canvas.Point{4, 4}, canvas.Point{8, 8}, canvas.Point{2, 2}]!

fn backdrop() []u8 {
	mut pixels := []u8{len: test_width * test_height * 4}
	for y in 0 .. test_height {
		for x in 0 .. test_width {
			i := (y * test_width + x) * 4
			alpha := 128 + (x * 7 + y * 3) % 128
			pixels[i] = u8((x * 13) % (alpha + 1))
			pixels[i + 1] = u8((y * 29) % (alpha + 1))
			pixels[i + 2] = u8(((x + y) * 5) % (alpha + 1))
			pixels[i + 3] = u8(alpha)
		}
	}
	return pixels
}

fn base_shape() C.VoxGraphiteShape {
	mut shape := C.VoxGraphiteShape{}
	shape.matrix = [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
	shape.rect = [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 3, 8, 8, 2, 5]!
	shape.fill = 1
	shape.anti_alias = 1
	shape.red = 35
	shape.green = 167
	shape.blue = 79
	shape.alpha = 255
	return shape
}

// The draws gg.canvas makes for base_shape() with the given corner radii and
// changes, written directly against its API.
fn expected(mut ctx canvas.GpuContext, samples int, background []u8, radii [4]canvas.Point, underlay ?canvas.Paint, paint canvas.Paint) ![]u8 {
	mut s := ctx.new_surface(width: test_width, height: test_height, sample_count: samples)!
	defer {
		s.free()
	}
	if background.len > 0 {
		s.write_pixels(background.data, test_width * 4)!
	} else {
		s.clear(canvas.Color4f{})
	}
	if samples == 4 {
		s.draw_msaa_trigger()
	}
	s.set_matrix(canvas.Matrix.scale(2, 1))
	if p := underlay {
		s.draw_rrect(canvas.RRect.rect_radii(canvas.Rect.ltrb(1, 2, 17, 26), [
			canvas.Point{3, 3},
			canvas.Point{3, 3},
			canvas.Point{3, 3},
			canvas.Point{3, 3},
		]!), p)!
	}
	s.draw_rrect(canvas.RRect.rect_radii(canvas.Rect.ltrb(5.25, 4.5, 35.75, 24.75), radii),
		paint)!
	mut pixels := []u8{len: test_width * test_height * 4}
	s.read_pixels(pixels.data, test_width * 4)!
	return pixels
}

// reference_context returns a context for the expected pixels. ggshape's own
// context, created first, owns sokol.gfx and outlives every test.
fn reference_context() !&canvas.GpuContext {
	context()!
	return canvas.new_gpu_context()!
}

fn test_descriptors_draw_like_gg_canvas() {
	mut ctx := reference_context() or {
		eprintln('skipping: ${err}')
		return
	}
	defer {
		ctx.free()
	}
	mut shape := base_shape()
	shape.matrix[0] = 2
	green := canvas.Paint{
		color:      canvas.Color4f.from_rgba8(35, 167, 79, 255)
		anti_alias: true
	}
	// A filled rounded rect over a backdrop.
	mut pixels := backdrop()
	assert draw(pixels.data, test_width, test_height, test_width * 4, 1, &shape) == 1
	assert pixels == expected(mut ctx, 1, backdrop(), base_radii, none, green)!
	assert pixels != backdrop()
	// A stroke over an underlay, both with unrounded colors.
	shape.fill = 0
	shape.thickness = 1.5
	shape.rect = [f32(5.25), 4.5, 30.5, 20.25, 6, 6, 4, 4, 8, 8, 2, 2]!
	shape.has_float_color = 1
	shape.float_color = [f32(0.3), 0.5, 0.71, 0.9]!
	shape.has_underlay = 1
	shape.underlay_rect = [f32(1), 2, 16, 24, 3, 3, 3, 3, 3, 3, 3, 3]!
	shape.has_float_underlay_color = 1
	shape.underlay_float_color = [f32(0.9), 0.2, 0.1, 0.6]!
	pixels = backdrop()
	assert draw(pixels.data, test_width, test_height, test_width * 4, 1, &shape) == 1
	assert pixels == expected(mut ctx, 1, backdrop(), circular_radii, canvas.Paint{
		color:      canvas.Color4f{0.9, 0.2, 0.1, 0.6}
		anti_alias: true
	}, canvas.Paint{
		color:        canvas.Color4f{0.3, 0.5, 0.71, 0.9}
		anti_alias:   true
		style:        .stroke
		stroke_width: 1.5
	})!
	// A clip-out, in local coordinates, snapped to whole pixels.
	shape = base_shape()
	shape.matrix[0] = 2
	clip := [f32(8.4), 6, 12, 30]
	shape.clip_outs = unsafe { &f32(clip.data) }
	shape.clip_out_count = 1
	pixels = backdrop()
	assert draw(pixels.data, test_width, test_height, test_width * 4, 1, &shape) == 1
	mut clipped_surface := ctx.new_surface(width: test_width, height: test_height)!
	clipped_surface.write_pixels(backdrop().data, test_width * 4)!
	clipped_surface.set_matrix(canvas.Matrix.scale(2, 1))
	clipped_surface.clip_rect(canvas.Rect.ltrb(8.4, 6, 12, 30), .difference, false)!
	clipped_surface.draw_rrect(canvas.RRect.rect_radii(canvas.Rect.ltrb(5.25, 4.5, 35.75,
		24.75), base_radii), green)!
	mut clipped_pixels := []u8{len: test_width * test_height * 4}
	clipped_surface.read_pixels(clipped_pixels.data, test_width * 4)!
	clipped_surface.free()
	assert pixels == clipped_pixels
	assert pixels != expected(mut ctx, 1, backdrop(), base_radii, none, green)!
	// Two clip-outs crossing the shape: the second is a depth-only clip draw.
	gaps := [f32(8.4), 6, 12, 30, f32(14), 6, 15.5, 30]
	shape.clip_outs = unsafe { &f32(gaps.data) }
	shape.clip_out_count = 2
	pixels = backdrop()
	assert draw(pixels.data, test_width, test_height, test_width * 4, 1, &shape) == 1
	mut gaps_surface := ctx.new_surface(width: test_width, height: test_height)!
	gaps_surface.write_pixels(backdrop().data, test_width * 4)!
	gaps_surface.set_matrix(canvas.Matrix.scale(2, 1))
	gaps_surface.clip_rect(canvas.Rect.ltrb(8.4, 6, 12, 30), .difference, false)!
	gaps_surface.clip_rect(canvas.Rect.ltrb(14, 6, 15.5, 30), .difference, false)!
	gaps_surface.draw_rrect(canvas.RRect.rect_radii(canvas.Rect.ltrb(5.25, 4.5, 35.75, 24.75),
		base_radii), green)!
	gaps_surface.read_pixels(clipped_pixels.data, test_width * 4)!
	gaps_surface.free()
	assert pixels == clipped_pixels
	// Forced MSAA over transparency and over a backdrop.
	shape = base_shape()
	shape.matrix[0] = 2
	shape.force_msaa = 1
	pixels = []u8{len: test_width * test_height * 4}
	assert draw(pixels.data, test_width, test_height, test_width * 4, 0, &shape) == 1
	assert pixels == expected(mut ctx, 4, [], base_radii, none, green)!
	pixels = backdrop()
	assert draw(pixels.data, test_width, test_height, test_width * 4, 1, &shape) == 1
	assert pixels == expected(mut ctx, 4, backdrop(), base_radii, none, green)!
}

fn test_unsupported_descriptors_leave_pixels_untouched() {
	mut ctx := reference_context() or {
		eprintln('skipping: ${err}')
		return
	}
	defer {
		ctx.free()
	}
	// An unknown border mode.
	mut unknown := base_shape()
	unknown.fill = 99
	unknown.border_widths = [f32(2), 0, 0, 0]!
	for shape in [unknown] {
		mut pixels := backdrop()
		assert draw(pixels.data, test_width, test_height, test_width * 4, 1, &shape) == 0
		assert pixels == backdrop()
	}
	// Three-sided labels and sides next to other borders use path clips.
	mut label := base_shape()
	label.fill = 8
	label.border_widths = [f32(2), 2, 2, 0]!
	mut mitered := base_shape()
	mitered.fill = 3
	mitered.border_widths = [f32(1), 2, 0, 0]!
	for shape in [label, mitered] {
		mut pixels := backdrop()
		assert draw(pixels.data, test_width, test_height, test_width * 4, 1, &shape) == 1
		assert pixels != backdrop()
	}
	shape := base_shape()
	mut pixels := backdrop()
	assert draw(pixels.data, test_width, test_height, test_width * 4 - 4, 1, &shape) == 0
	assert pixels == backdrop()
}

// border_pixels draws one of Vox's border modes over the backdrop.
fn border_pixels(shape C.VoxGraphiteShape) []u8 {
	mut pixels := backdrop()
	assert draw(pixels.data, test_width, test_height, test_width * 4, 1, &shape) == 1
	return pixels
}

fn test_border_modes_draw_like_gg_canvas() {
	mut ctx := reference_context() or {
		eprintln('skipping: ${err}')
		return
	}
	defer {
		ctx.free()
	}
	green := canvas.Paint{
		color:      canvas.Color4f.from_rgba8(35, 167, 79, 255)
		anti_alias: true
	}
	outer := canvas.RRect.rect_radii(canvas.Rect.ltrb(5.25, 4.5, 35.75, 24.75), base_radii)
	mut s := ctx.new_surface(width: test_width, height: test_height)!
	mut want := []u8{len: test_width * test_height * 4}
	// Mode 6: a uniform elliptical ring around the center line.
	mut ring := base_shape()
	ring.fill = 6
	ring.border_widths = [f32(2), 2, 2, 2]!
	s.write_pixels(backdrop().data, test_width * 4)!
	s.draw_drrect(outer.outset(1, 1), outer.inset(1, 1), green)!
	s.read_pixels(want.data, test_width * 4)!
	assert border_pixels(ring) == want
	// Mode 2: an isolated top side, clipped to the border area and the
	// corners' extent.
	mut top := base_shape()
	top.fill = 2
	top.border_widths = [f32(2), 0, 0, 0]!
	s.write_pixels(backdrop().data, test_width * 4)!
	s.save()
	s.clip_rrect(outer, .intersect, true)!
	s.clip_rrect(canvas.RRect.rect_radii(canvas.Rect.ltrb(5.25, 6.5, 35.75, 24.75), [
		canvas.Point{6, 4},
		canvas.Point{4, 1},
		canvas.Point{8, 8},
		canvas.Point{2, 5},
	]!), .difference, true)!
	s.save()
	s.clip_rect(canvas.Rect.ltrb(5.25, 4.5, 35.75, 10.5), .intersect, true)!
	s.draw_rect(outer.rect, green)!
	s.restore()
	s.restore()
	s.read_pixels(want.data, test_width * 4)!
	assert border_pixels(top) == want
	assert want != backdrop()
	s.free()
}

fn test_path_descriptors_draw_like_gg_canvas() {
	mut ctx := reference_context() or {
		eprintln('skipping: ${err}')
		return
	}
	defer {
		ctx.free()
	}
	// A concave polygon closed and restarted at its move point, then an SVG
	// ellipse, under a uniform scale (keeping the clip circular and analytic)
	// and a rounded clip.
	segments := [f32(0), 4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, f32(1), 40, 6, 0, 0, 0, 0, 0, 0, 0, 0,
		0, f32(1), 20, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, f32(1), 30, 28, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		f32(5), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, f32(6), 2, 16, 14, 26, 0, 0, 0, 0, 0, 0, 0]
	mut path := C.VoxGraphitePath{
		segments: unsafe { &f32(segments.data) }
		stops:    unsafe { nil }
	}
	path.segment_count = 6
	path.matrix = [f32(1.25), 0, 1, 0, 1.25, 0.5, 0, 0, 1]!
	path.red = 35
	path.green = 167
	path.blue = 79
	path.alpha = 200
	path.has_clip = 1
	path.clip = [f32(2), 2, 40, 24, 5, 5, 5, 5, 5, 5, 5, 5]!
	mut pixels := backdrop()
	assert draw_path(pixels.data, test_width, test_height, test_width * 4, 1, &path) == 1
	mut b := canvas.PathBuilder{}
	b.move_to(4, 4)
	b.line_to(40, 6)
	b.line_to(20, 14)
	b.line_to(30, 28)
	b.close()
	b.move_to(4, 4)
	b.add_oval(canvas.Rect.ltrb(2, 16, 14, 26), .cw, 1)
	mut s := ctx.new_surface(width: test_width, height: test_height)!
	s.write_pixels(backdrop().data, test_width * 4)!
	s.save()
	s.set_matrix(canvas.Matrix.values([f32(1.25), 0, 1, 0, 1.25, 0.5, 0, 0, 1]!))
	r := canvas.Point{5, 5}
	s.clip_rrect(canvas.RRect.rect_radii(canvas.Rect.xywh(2, 2, 40, 24), [r, r, r, r]!),
		.intersect, true)!
	s.draw_path(b.detach(), canvas.Paint{
		color:      canvas.Color4f.from_rgba8(35, 167, 79, 200)
		anti_alias: true
	})!
	s.restore()
	mut want := []u8{len: test_width * test_height * 4}
	s.read_pixels(want.data, test_width * 4)!
	s.free()
	assert pixels == want
	assert want != backdrop()
	// Perspective non-scaling strokes keep the original backend.
	path.stroke = 1
	path.non_scaling_stroke = 1
	path.matrix[6] = 0.01
	pixels = backdrop()
	assert draw_path(pixels.data, test_width, test_height, test_width * 4, 1, &path) == 0
	assert pixels == backdrop()
}
