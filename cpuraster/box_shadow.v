module cpuraster

// Portable box shadow replay: premultiplied drawing, followed by the
// straight-RGBA readback expected by GG/Sokol's source-alpha transport.
pub fn rasterize_outer_shadow(width int, height int, outer RoundedRect, content RoundedRect, transform [6]f32, color u32, blur f32, clips []Path) ?[]u8 {
	if width <= 0 || height <= 0 || width > max_untiled_dimension || height > max_untiled_dimension { return none }
	mut pixels := []u8{len: width * height * 4}
	mut rc := canvas_raster_clip(width, height, clips)
	matrix := Matrix{transform[0], transform[1], transform[2], transform[3], transform[4], transform[5]}
	rc.subtract_path(content.clip_path(matrix))
	mut fast_bounds := outer.bounds
	if sigma := canvas_shadow_sigma(blur) {
		pad := f32(3) * sigma
		fast_bounds = Rect{fast_bounds.left - pad, fast_bounds.top - pad, fast_bounds.right + pad, fast_bounds.bottom + pad}
	}
	if canvas_quick_reject(fast_bounds, matrix, &rc) { return pixels }
	if !rc.is_empty && color >> 24 != 0 {
		mut blitter := canvas_blitter(mut pixels, width * 4, color, f32(color >> 24) * inv_255, .src_over) or { return none }
		// drawRRect delegates square corners to drawRect and ovals to drawOval.
		mut local := outer.path()
		if outer.radii[..].all(it == 0) { local = rect_path(outer.bounds) }
		else if outer.is_oval() {
			mut oval := PathBuilder{}
			oval.add_oval_dir(outer.bounds, true, 1)
			local = Path{...oval.detach(), convex_hint: .convex_cw}
		}
		device := local.transform(matrix)
		if sigma := canvas_shadow_sigma(blur) {
			mut plan := BlurPlan{kind: .unfiltered}
			if r := outer.axis_transform(matrix) {
				if patch := rrect_blur_patch(r, xformed_blur_sigma(sigma, matrix)) {
					plan = BlurPlan{kind: .nine, patch: patch, fill_center: true}
				} else { plan = plan_blur(device, device.convexity() != .concave, sigma, matrix, &rc, false) }
			} else { plan = plan_blur(device, device.convexity() != .concave, sigma, matrix, &rc, false) }
			if plan.kind == .declined { return none }
			if plan.kind == .unfiltered { anti_fill_path_clip(device, false, &rc, mut blitter) }
			else { plan.draw(&rc, blitter) }
		} else {
			mapped_bounds := map_rect_affine(outer.bounds, matrix)
			if outer.radii[..].all(it == 0) && rect_stays_rect(matrix_affine(matrix))
				&& !rect_exceeds(mapped_bounds, 32767) {
				anti_fill_rect(mapped_bounds, &rc, mut blitter)
			} else { anti_fill_path_clip(device, false, &rc, mut blitter) }
		}
	}
	mut straight := []u8{len: pixels.len}
	if !read_pixels(pixels, width, height, width * 4, 2, mut straight, width, height, width * 4, 0, 0) { return none }
	return straight
}

// SkRRect's legacy axis-aligned transform, including quarter turns and flips.
fn (r RoundedRect) axis_transform(m Matrix) ?RoundedRect {
	if !rect_stays_rect(matrix_affine(m)) { return none }
	bounds := map_rect_affine(r.bounds, m)
	if !rect_is_finite(bounds) || rect_is_empty(bounds) { return none }
	if r.is_oval() {
		rx := (bounds.right - bounds.left) * f32(0.5)
		ry := (bounds.bottom - bounds.top) * f32(0.5)
		return RoundedRect{bounds, [rx, ry, rx, ry, rx, ry, rx, ry]!}
	}
	mut radii := r.radii
	mut sx := m.a
	mut sy := m.d
	if m.b != 0 || m.c != 0 {
		clockwise := m.c < 0
		sy = m.b * if clockwise { f32(1) } else { f32(-1) }
		sx = m.c * if clockwise { f32(-1) } else { f32(1) }
		dir := if clockwise { 3 } else { 1 }
		for i in 0 .. 4 { source := (i + dir) % 4; radii[i * 2], radii[i * 2 + 1] = r.radii[source * 2 + 1], r.radii[source * 2] }
	}
	flip_x := sx < 0
	flip_y := sy < 0
	for i in 0 .. 4 { radii[i * 2] *= math_abs32(sx); radii[i * 2 + 1] *= math_abs32(sy) }
	if flip_x || flip_y {
		source := radii
		for i in 0 .. 4 {
			j := if flip_x && flip_y { (i + 2) % 4 } else if flip_x { i ^ 1 } else { 3 - i }
			radii[i * 2], radii[i * 2 + 1] = source[j * 2], source[j * 2 + 1]
		}
	}
	return rounded_rect(bounds, radii)
}

fn (r RoundedRect) is_oval() bool {
	rad := r.radii
	return rad[0] == rad[2] && rad[0] == rad[4] && rad[0] == rad[6]
		&& rad[1] == rad[3] && rad[1] == rad[5] && rad[1] == rad[7]
		&& rad[0] >= (r.bounds.right - r.bounds.left) * f32(0.5)
		&& rad[1] >= (r.bounds.bottom - r.bounds.top) * f32(0.5)
}

// SkBlurMaskFilterImpl::filterRRectToNine(): rasterize a smaller rrect at
// integer origin, blur it, then stretch its unchanged center pixel.
fn rrect_blur_patch(r RoundedRect, sigma f32) ?NinePatch {
	bounds := r.bounds
	if rect_exceeds(bounds, 32767) || r.radii[..].all(it == 0) { return none }
	rad := r.radii
	if rad[0] == rad[2] && rad[0] == rad[4] && rad[0] == rad[6]
		&& rad[1] == rad[3] && rad[1] == rad[5] && rad[1] == rad[7]
		&& rad[0] >= (bounds.right - bounds.left) * f32(0.5)
		&& rad[1] >= (bounds.bottom - bounds.top) * f32(0.5) { return none }
	filter := new_mask_blur_filter(sigma)
	if filter.has_no_blur() { return none }
	margin := filter.border()
	l := float_saturate2int(ceil_f32(fmax_std(rad[0], rad[6]))) + margin
	right := float_saturate2int(ceil_f32(fmax_std(rad[2], rad[4]))) + margin
	t := float_saturate2int(ceil_f32(fmax_std(rad[1], rad[3]))) + margin
	bottom := float_saturate2int(ceil_f32(fmax_std(rad[7], rad[5]))) + margin
	w := l + right + 1
	h := t + bottom + 1
	if f32(w) >= bounds.right - bounds.left || f32(h) >= bounds.bottom - bounds.top { return none }
	small := rounded_rect(Rect{0, 0, f32(w), f32(h)}, rad)
	mut mask := new_a8_mask(IRect{0, 0, w, h}, w)
	mut blitter := A8Blitter{width: w, height: h, row_bytes: w, src: 255, pixels: mask.image}
	if !anti_fill_region(small.path(), true, mask.bounds, mut blitter, false) { return none }
	blurred := filter.blur(&mask)?
	return NinePatch{
		mask: Mask{...blurred, bounds: IRect{0, 0, blurred.bounds.width(), blurred.bounds.height()}}
		outer: irect_outset(rect_round_out(bounds), margin, margin)
		center_x: margin + l
		center_y: margin + t
	}
}
