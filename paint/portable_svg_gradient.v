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
		if !may_try_portable_svg_gpu() || app.paint_effect_depth != 0 || app.paint_svg_mask_depth != 0
			|| data.path_data.len < layout.compatibility_clip_path_segment_stride {
			return false
		}
		gradient := portable_svg_path_gradient(command, false, command.opacity * data.fill_opacity) or {
			return false
		}
		if math.f32_from_bits(gradient.key.opacity_bits) == 0 || gradient.style.color_stops.len == 0 {
			return true
		}
		cached_bounds, geometry_slot := portable_gpu_svg_local_bounds(data.path_data)
		local := if geometry_slot >= 0 { cached_bounds } else {
			portable_svg_gpu_path_bounds(data.path_data, data.fill_even_odd) or { return false }
		}
		transform := portable_device_transform(multiply_paint_transforms(command.transform,
			data.path_transform), page_x, page_y, f64(app.ctx.scale))
		bounds := portable_pixel_bounds(portable_svg_device_bounds(local, transform,
			app.portable_device_viewport(page_y)))
		if bounds.is_empty() { return true }
		return draw_portable_gpu_svg_path(app.ctx, data, portable_svg_surface_matrix(transform,
			bounds), bounds, gg.Color{}, local, geometry_slot, PortableSVGStroke{}, &gradient)
	}

	fn portable_svg_path_gradient(command &layout.PaintCommand, stroke bool,
		opacity f64) ?PortableSVGGradientPaint {
		mut style := painting.SVGGradientPaintStyle{}
		mut kind := 1
		mut points := [6]f32{}
		linear_style := if stroke { command.stroke_linear_gradient() } else { command.fill_linear_gradient() }
		if linear := linear_style {
			style = linear.gradient
			points = [f32(linear.start_point.x), f32(linear.start_point.y),
				f32(linear.end_point.x), f32(linear.end_point.y), 0, 0]!
		} else {
			radial_style := if stroke { command.stroke_radial_gradient() } else { command.fill_radial_gradient() }
			radial := radial_style or { return none }
			kind = 2
			style = radial.gradient
			points = [f32(radial.start_center.x), f32(radial.start_center.y),
				f32(radial.start_radius), f32(radial.end_center.x), f32(radial.end_center.y),
				f32(radial.end_radius)]!
			$if windows && sokol_d3d11 ? {
				if points[0] != points[3] || points[1] != points[4] {
					return none
				}
			}
		}
		if style.color_space != .srgb || !points.all(math.is_finite(f64(it))) { return none }
		affine := style.gradient_transform or { painting.Affine{} }
		matrix := [f32(affine.a), f32(affine.c), f32(affine.e), f32(affine.b), f32(affine.d),
			f32(affine.f), 0, 0, 1]!
		if !matrix.all(math.is_finite(f64(it))) { return none }
		return PortableSVGGradientPaint{
			key: PortableSVGGradientKey{
				kind:         kind
				tile_mode:    int(style.spread_method)
				opacity_bits: math.f32_bits(f32(clamp(opacity, 0.0, 1.0)))
				points:       points
				matrix:       matrix
			}
			style: style
		}
	}

	fn portable_svg_gpu_path_bounds(data []f32, even_odd bool) ?cpuraster.Rect {
		if data[0] == 6 && data.len == layout.compatibility_clip_path_segment_stride {
			// Chromium's packed path can represent a whole ellipse directly.
			if !data[1..5].all(math.is_finite(f64(it))) || data[3] <= data[1] || data[4] <= data[2] {
				return none
			}
			return cpuraster.Rect{data[1], data[2], data[3], data[4]}
		}
		return cpuraster.canvas_path(data, even_odd).bounds()
	}

	// Non-scaling strokes render geometry in texture coordinates. Map the
	// paint there too so its gradient still follows the original SVG path.
	fn portable_svg_non_scaling_gradient_matrix(surface [6]f32, local [9]f32) [9]f32 {
		m := portable_svg_surface_paint_transform(surface,
			[local[0], local[3], local[1], local[4], local[2], local[5]]!)
		return [m[0], m[2], m[4], m[1], m[3], m[5], 0, 0, 1]!
	}
}
