module cpuraster

// A real blur resolves MakeFromImage's deferred sampling, source conversion,
// paint alpha and preceding color filters together into its input surface.
// Identity blurs preserve these effects until the first non-identity blur.
fn draw_resampled_image_blur(mut pixels []u8, width int, height int, pitch int, alpha_type int, transform [6]f32, image CanvasBitmap, src Rect, dst Rect, smoothing bool, alpha f32, mode BlendMode, clips []Path, step CanvasFilterStep) bool {
	ctm := canvas_affine(transform)
	if ctm.kx != 0 || ctm.ky != 0 || step.kind != .blur
		|| math_abs32(ctm.tx) > 1 << 20 || math_abs32(ctm.ty) > 1 << 20 { return false }
	local := rect_to_rect(src, dst) or { return false }
	total := sk_concat(m44_image_concat(ctm, local), affine_translate(src.left, src.top))
	// The native rescale shortcut retains raw pixels for nearly integer
	// translations. Those mappings still require deferred-transform support.
	if math_abs32(total.sx - 1) <= image_filter_round_epsilon
		&& math_abs32(total.sy - 1) <= image_filter_round_epsilon
		&& math_abs32(total.tx - floor_f32(total.tx + f32(.5))) <= image_filter_round_epsilon
		&& math_abs32(total.ty - floor_f32(total.ty + f32(.5))) <= image_filter_round_epsilon { return false }
	mut before := step.pre_color.clone()
	mut stages := step.blur_stages.clone()
	mut real_blur := false
	if stages.len == 0 {
		real_blur = blur_layer_sigma(math_abs32(step.sigma * ctm.sx)) != 0
			|| blur_layer_sigma(math_abs32(step.sigma * ctm.sy)) != 0
	} else {
		for i, stage in stages {
			before << stage.pre_color
			stages[i] = BlurFilterStage{...stage, pre_color: []MatrixColorFilter{}}
			if blur_layer_sigma(math_abs32(stage.sigma * ctm.sx)) != 0
				|| blur_layer_sigma(math_abs32(stage.sigma * ctm.sy)) != 0 {
				real_blur = true
				break
			}
		}
	}
	if !real_blur { return false }
	filter := new_color_filter(before)
	bitmap := CanvasBitmap{...image, pixels: image.pixels[int(src.top) * image.pitch + int(src.left) * 4..],
		width: int(src.right - src.left), height: int(src.bottom - src.top)}
	prepared := CanvasFilterStep{...step, blur_stages: stages, pre_color: []MatrixColorFilter{},
		source_image: true, source_padding: true, source_color_info: FilterImageInfo{}}
	return draw_filter_layer_tinted(mut pixels, width, height, pitch, alpha_type,
		transform, clips, dst, prepared, mode,
		fn [bitmap, image, src, ctm, total, smoothing, alpha, filter] (mut layer []u8, w int, h int, t [6]f32, inner_clips []Path) bool {
			// Build the original source mapping before translating the surface.
			// Rebuilding it from the shifted CTM changes float association.
			left := floor_f32(ctm.tx - t[4] + f32(.5))
			top := floor_f32(ctm.ty - t[5] + f32(.5))
			rc := canvas_raster_clip(w, h, inner_clips)
			bounds := rc.bounds()
			global := Rect{f32(bounds.left) + left, f32(bounds.top) + top,
				f32(bounds.right) + left, f32(bounds.bottom) + top}
			image_bounds := Rect{0, 0, f32(bitmap.width), f32(bitmap.height)}
			covered := filter_quad_contains_rect(total, image_bounds, global).all(it)
			// Shader tiling is only required at a subset edge that sampling
			// crosses and that is not an edge of the backing image.
			edges := filter_quad_contains_rect(total, Rect{.5, .5, image_bounds.right - f32(.5), image_bounds.bottom - f32(.5)},
				Rect{global.left + f32(.5), global.top + f32(.5), global.right - f32(.5), global.bottom - f32(.5)})
			strict := !(edges[0] || src.top == 0) || !(edges[1] || src.right == f32(image.width))
				|| !(edges[2] || src.bottom == f32(image.height)) || !(edges[3] || src.left == 0)
			backing := if strict { bitmap } else { image }
			local_matrix := if strict { total } else { sk_concat(total, affine_translate(-src.left, -src.top)) }
			mapped := sk_concat(affine_translate(-left, -top), local_matrix)
			tile := if covered { TileMode.clamp } else { .decal }
			shader := if smoothing { new_linear_mipmap_image_shader(backing, tile, tile, mapped, true) }
				else { new_image_shader(backing, tile, tile, false, mapped) }
			if mut blitter := canvas_draw_blitter_for_surface(mut layer, w * 4, 0xff000000,
				shader, alpha, .src, Rect{f32(bounds.left), f32(bounds.top), f32(bounds.right), f32(bounds.bottom)},
				filter, false) {
				fill_irect(bounds, &rc, mut blitter)
			}
			return true
		}, none)
}

// SkRectPriv::QuadContainsRectMask, with the same unnormalized edge
// equations and destination inset. Reversing a scale reverses the normals.
fn filter_quad_contains_rect(m SkAffine, a Rect, b Rect) []bool {
	if rect_is_empty(a) { return [false, false, false, false] }
	ax := [a.left, a.right, a.right, a.left]!
	ay := [a.top, a.top, a.bottom, a.bottom]!
	mut x := [4]f32{}
	mut y := [4]f32{}
	for i in 0 .. 4 {
		px, py := m.sx * ax[i], m.kx * ay[i]
		qx, qy := m.ky * ax[i], m.sy * ay[i]
		x[i] = (px + py) + m.tx
		y[i] = (qx + qy) + m.ty
	}
	mut la := [4]f32{}
	mut lb := [4]f32{}
	mut lc := [4]f32{}
	for i in 0 .. 4 {
		j := (i + 1) % 4
		la[i] = y[i] - y[j]
		lb[i] = x[j] - x[i]
		p, q := x[i] * y[j], y[i] * x[j]
		lc[i] = p - q
	}
	p, q := la[0] * lb[1], lb[0] * la[1]
	sign := if p - q < 0 { f32(-1) } else { f32(1) }
	e := image_filter_round_epsilon
	mut result := []bool{len: 4, init: true}
	for i in 0 .. 4 {
		for corner in [Point{b.left + e, b.top + e}, Point{b.right - e, b.top + e},
			Point{b.right - e, b.bottom - e}, Point{b.left + e, b.bottom - e}] {
			rx, ry := la[i] * corner.x, lb[i] * corner.y
			result[i] = result[i] && sign * ((rx + ry) + lc[i]) >= 0
		}
	}
	return result
}
