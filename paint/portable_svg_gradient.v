module main

$if vox_gg_svg ? {
	import cpuraster
	import gg
	import layout
	import math
	import painting

	const portable_svg_gpu_gradient_stops = 32

	struct PortableSVGGradientKey {
		kind         int
		tile_mode    int
		opacity_bits u32
		points       [6]f32
		matrix       [9]f32
	}

	struct PortableSVGGradientPaint {
		key   PortableSVGGradientKey
		style painting.SVGGradientPaintStyle
	}

	struct PortableSVGGradientStop {
		position_bits u32
		color         painting.Color
	}

	fn portable_svg_gradient_stop(stop painting.ColorStop) PortableSVGGradientStop {
		return PortableSVGGradientStop{math.f32_bits(f32(stop.position)), stop.color}
	}

	fn (first &PortableSVGGradientKey) matches(second &PortableSVGGradientKey) bool {
		if first.kind != second.kind || first.tile_mode != second.tile_mode
			|| first.opacity_bits != second.opacity_bits {
			return false
		}
		return unsafe {
			vmemcmp(&first.points[0], &second.points[0], 6 * int(sizeof(f32))) == 0
				&& vmemcmp(&first.matrix[0], &second.matrix[0], 9 * int(sizeof(f32))) == 0
		}
	}

	fn (texture &PortableSVGTexture) matches_gradient(gradient &PortableSVGGradientPaint) bool {
		stops := gradient.style.color_stops
		if stops.len != texture.gradient_count || !texture.gradient_key.matches(&gradient.key) {
			return false
		}
		for index, stop in stops {
			if texture.gradient_stops[index] != portable_svg_gradient_stop(stop) {
				return false
			}
		}
		return true
	}

	fn (mut texture PortableSVGTexture) store_gradient(gradient &PortableSVGGradientPaint) {
		texture.gradient_key = gradient.key
		texture.gradient_count = gradient.style.color_stops.len
		for index, stop in gradient.style.color_stops {
			texture.gradient_stops[index] = portable_svg_gradient_stop(stop)
		}
	}

	fn (mut app BrowserApp) draw_portable_gpu_svg_gradient_fill(command &layout.PaintCommand,
		data layout.PaintSVGPathData, page_x f32, page_y f32) bool {
		if !portable_svg_gpu_enabled || app.paint_effect_depth != 0 || app.paint_svg_mask_depth != 0
			|| data.path_data.len < layout.compatibility_clip_path_segment_stride {
			return false
		}
		state := unsafe { portable_svg_gpu }
		if state.count == portable_svg_gpu_image_limit || (state.tried && state.canvas == unsafe { nil }) {
			return false
		}
		mut style := painting.SVGGradientPaintStyle{}
		mut kind := 1
		mut points := [6]f32{}
		if linear := command.fill_linear_gradient() {
			style = linear.gradient
			points = [f32(linear.start_point.x), f32(linear.start_point.y),
				f32(linear.end_point.x), f32(linear.end_point.y), 0, 0]!
		} else if radial := command.fill_radial_gradient() {
			kind = 2
			style = radial.gradient
			points = [f32(radial.start_center.x), f32(radial.start_center.y),
				f32(radial.start_radius), f32(radial.end_center.x), f32(radial.end_center.y),
				f32(radial.end_radius)]!
		} else {
			return false
		}
		if style.color_space != .srgb || !points.all(math.is_finite(f64(it))) { return false }
		opacity := f32(clamp(command.opacity * data.fill_opacity, 0.0, 1.0))
		if opacity == 0 || style.color_stops.len == 0 { return true }

		cached := portable_gpu_svg_local_bounds(data.path_data)
		local := cached or {
			portable_svg_gradient_path_bounds(data.path_data, data.fill_even_odd) or { return false }
		}
		transform := portable_device_transform(multiply_paint_transforms(command.transform,
			data.path_transform), page_x, page_y, f64(app.ctx.scale))
		bounds := portable_pixel_bounds(portable_svg_device_bounds(local, transform,
			app.portable_device_viewport(page_y)))
		if bounds.is_empty() { return true }

		affine := style.gradient_transform or { painting.Affine{} }
		matrix := [f32(affine.a), f32(affine.c), f32(affine.e), f32(affine.b), f32(affine.d),
			f32(affine.f), 0, 0, 1]!
		if !matrix.all(math.is_finite(f64(it))) { return false }
		gradient := PortableSVGGradientPaint{
			key: PortableSVGGradientKey{
				kind:         kind
				tile_mode:    int(style.spread_method)
				opacity_bits: math.f32_bits(opacity)
				points:       points
				matrix:       matrix
			}
			style: style
		}
		return draw_portable_gpu_svg_path(app.ctx.r, data, portable_svg_surface_matrix(transform,
			bounds), bounds, gg.Color{}, local, cached != none, PortableSVGStroke{}, &gradient)
	}

	fn portable_svg_gradient_path_bounds(data []f32, even_odd bool) ?cpuraster.Rect {
		if data[0] == 6 && data.len == layout.compatibility_clip_path_segment_stride {
			// Chromium's packed path can represent a whole ellipse directly.
			if !data[1..5].all(math.is_finite(f64(it))) || data[3] <= data[1] || data[4] <= data[2] {
				return none
			}
			return cpuraster.Rect{data[1], data[2], data[3], data[4]}
		}
		return cpuraster.canvas_path(data, even_odd).bounds()
	}
}
