module main

$if vox_gg_svg ? {
	import cpuraster
	import gg
	import gg.canvas
	import gg.render
	import ggshape
	import layout
	import math
	import os
	import painting
	import platform
	import sokol.gfx

	const portable_svg_gpu_enabled = os.getenv('VOX_GG_SVG') == '1'
	const portable_svg_gpu_diagnostics = os.getenv('VOX_GG_SVG_DIAGNOSTICS') == '1'
	const portable_svg_gpu_cache_control = os.getenv('VOX_DISABLE_GG_SVG_CACHE')
	const disable_portable_svg_gpu_cache = portable_svg_gpu_cache_control == '1'
	const portable_svg_gpu_texture_slots = 16
	// Leave room in the shared Sokol image pool for the rest of the browser.
	const portable_svg_gpu_transient_slots = 64
	const portable_svg_gpu_pixel_limit = 1024 * 1024
	const portable_svg_gpu_cached_values = 128 * layout.compatibility_clip_path_segment_stride
	const portable_svg_gpu_dash_intervals = 32
	const portable_svg_gpu = &PortableSVGGpu{}

	struct PortableSVGStroke {
		width_bits u32
		miter_bits u32
		cap        i32
		join       i32
		non_scaling bool
		dash_count int
		dash_offset_bits u64
	}

	struct PortableSVGTextureKey {
		matrix   [6]f32
		width    int
		height   int
		color    gg.Color
		even_odd bool
		gradient bool
		stroke   PortableSVGStroke
	}

	struct PortableSVGTexture {
	mut:
		image    gfx.Image
		key      PortableSVGTextureKey
		local_bounds cpuraster.Rect
		// Own a bounded copy because document paint storage can retire or change
		// between frames. Zero values recorded means the texture is transient.
		values   [portable_svg_gpu_cached_values]f32
		dashes   [portable_svg_gpu_dash_intervals]f64
		gradient_key PortableSVGGradientKey
		gradient_stops [portable_svg_gpu_gradient_stops]PortableSVGGradientStop
		gradient_count int
		length   int
		used     bool
	idle     bool
	}

	fn (texture &PortableSVGTexture) matches(key &PortableSVGTextureKey, data &layout.PaintSVGPathData,
		geometry_matched bool) bool {
		if texture.key.width != key.width
			|| texture.key.height != key.height || texture.key.color != key.color
			|| texture.key.even_odd != key.even_odd || texture.key.gradient != key.gradient
			|| texture.key.stroke != key.stroke {
			return false
		}
		return unsafe {
			vmemcmp(&texture.key.matrix[0], &key.matrix[0], 6 * int(sizeof(f32))) == 0
		} && (geometry_matched || texture.matches_geometry(data.path_data)) && texture.matches_dashes(key, data)
	}

	fn (texture &PortableSVGTexture) crop_origin(key &PortableSVGTextureKey, data &layout.PaintSVGPathData) ?painting.IntPoint {
		if texture.key.gradient || texture.key.color != key.color || texture.key.even_odd != key.even_odd
			|| texture.key.stroke != key.stroke {
			return none
		}
		origin := portable_svg_covering_crop(texture.key.matrix,
			painting.IntSize{texture.key.width, texture.key.height}, key.matrix,
			painting.IntSize{key.width, key.height})?
		if !texture.matches_geometry(data.path_data) || !texture.matches_dashes(key, data) {
			return none
		}
		return origin
	}

	fn (texture &PortableSVGTexture) matches_dashes(key &PortableSVGTextureKey,
		data &layout.PaintSVGPathData) bool {
		return key.stroke.dash_count == 0 || unsafe {
			vmemcmp(&texture.dashes[0], data.stroke_dasharray.data,
				key.stroke.dash_count * int(sizeof(f64))) == 0
		}
	}

	fn (texture &PortableSVGTexture) matches_geometry(values []f32) bool {
		return texture.length == values.len && unsafe {
			vmemcmp(&texture.values[0], values.data, values.len * int(sizeof(f32))) == 0
		}
	}

	// A nonnegative slot identifies the bytes that supplied the bounds.
	fn portable_gpu_svg_local_bounds(values []f32) (cpuraster.Rect, int) {
		state := unsafe { portable_svg_gpu }
		if disable_portable_svg_gpu_cache || portable_svg_gpu_cache_control == 'bounds'
			|| state.canvas == unsafe { nil }
			|| values.len > portable_svg_gpu_cached_values {
			return cpuraster.Rect{}, -1
		}
		for index in 0 .. portable_svg_gpu_texture_slots {
			texture := &state.textures[index]
			if texture.matches_geometry(values) {
				return texture.local_bounds, index
			}
		}
		return cpuraster.Rect{}, -1
	}

	fn (mut texture PortableSVGTexture) release() {
		if texture.image.id != 0 {
			gfx.destroy_image(texture.image)
			texture.image = gfx.Image{}
		}
		texture.length = 0
		texture.used = false
		texture.idle = false
	}

	// The legacy GG window owns one Sokol context per process. It also owns
	// this renderer when multiple tabs share the window.
	struct PortableSVGGpu {
	mut:
		tried    bool
		canvas   &canvas.GpuContext = unsafe { nil }
		pipeline render.Pipeline
		sampler  gfx.Sampler
		textures [portable_svg_gpu_texture_slots]PortableSVGTexture
		transient_images [portable_svg_gpu_transient_slots]gfx.Image
		transient_count int
		// Pixel area of the distinct images referenced by this frame.
		pixels   int
	}

	@[inline]
	fn may_try_portable_svg_gpu() bool {
		if !portable_svg_gpu_enabled { return false }
		state := unsafe { portable_svg_gpu }
		return state.canvas != unsafe { nil } || !state.tried
	}

	fn (mut state PortableSVGGpu) initialize(ctx &gg.Context) {
		state.tried = true
		backend := $if windows && sokol_d3d11 ? { gfx.Backend.d3d11 } $else { gfx.Backend.glcore33 }
		if !gfx.is_valid() || gfx.query_backend() != backend {
			return
		}
		persistent := platform.enter_persistent()
		defer {
			platform.leave_persistent(persistent)
		}
		state.canvas = canvas.new_gpu_context() or {
			if portable_svg_gpu_diagnostics {
				eprintln('VOX_GG_SVG unavailable: ${err}')
			}
			return
		}
		mut desc := gfx.PipelineDesc{}
		desc.colors[0].blend = gfx.BlendState{
			enabled:        true
			src_factor_rgb: .one
			dst_factor_rgb: .one_minus_src_alpha
		}
		renderer := ctx.r
		$if windows && sokol_d3d11 ? {
			// Use the corrected browser projection for the resolved image quad.
			shader := gfx.query_pipeline_desc(ctx.pipeline.alpha.pips[3]).shader
			state.pipeline = renderer.make_pipeline_with_shader(desc, shader)
		} $else {
			state.pipeline = renderer.make_pipeline(desc)
		}
		state.sampler = gfx.make_sampler(&gfx.SamplerDesc{
			min_filter: .nearest
			mag_filter: .nearest
			wrap_u:     .clamp_to_edge
			wrap_v:     .clamp_to_edge
		})
		if gfx.query_pipeline_state(state.pipeline.pips[3]) != .valid
			|| gfx.query_sampler_state(state.sampler) != .valid {
			state.release(renderer)
		} else if portable_svg_gpu_diagnostics {
			eprintln('VOX_GG_SVG backend=${backend}')
		}
	}

	fn (mut state PortableSVGGpu) finish_frame() {
		if state.canvas == unsafe { nil } { return }
		// All commands that sampled a texture have been submitted at this point.
		mut spare_pixels := portable_svg_gpu_pixel_limit - state.pixels
		for index in 0 .. portable_svg_gpu_texture_slots {
			mut texture := &state.textures[index]
			if texture.used && texture.length != 0 {
				texture.idle = false
			} else if portable_svg_viewport_reuse && texture.length != 0 && texture.key.gradient
				&& texture.key.width * texture.key.height <= spare_pixels {
				// Keep exact viewport variants within the existing pixel budget.
				// Gradient pixels depend on the raster extent as well as dither phase.
				spare_pixels -= texture.key.width * texture.key.height
				texture.idle = true
			} else {
				texture.release()
			}
			texture.used = false
		}
		state.release_transient_images()
		state.pixels = 0
	}

	fn (mut state PortableSVGGpu) release_transient_images() {
		for index in 0 .. state.transient_count {
			gfx.destroy_image(state.transient_images[index])
		}
		state.transient_count = 0
	}

	fn (mut state PortableSVGGpu) release(renderer &render.Context) {
		if state.canvas == unsafe { nil } {
			return
		}
		for index in 0 .. portable_svg_gpu_texture_slots {
			state.textures[index].release()
		}
		state.release_transient_images()
		renderer.destroy_pipeline(state.pipeline)
		gfx.destroy_sampler(state.sampler)
		mut gpu := state.canvas
		gpu.free()
		state.canvas = unsafe { nil }
	}

	fn (mut state PortableSVGGpu) rasterize(data layout.PaintSVGPathData, key &PortableSVGTextureKey,
		gradient &PortableSVGGradientPaint) !gfx.Image {
		mut gpu := state.canvas
		mut target := gpu.new_surface(width: key.width, height: key.height)!
		defer {
			target.free()
		}
		matrix := key.matrix
		color := key.color
		mut path := C.VoxGraphitePath{
			matrix:        [matrix[0], matrix[2], matrix[4], matrix[1], matrix[3], matrix[5], 0, 0, 1]!
			segments:      data.path_data.data
			segment_count: i32(data.path_data.len / layout.compatibility_clip_path_segment_stride)
			even_odd:      i32(key.even_odd)
			red:           color.r
			green:         color.g
			blue:          color.b
			alpha:         color.a
			stroke:             i32(key.stroke.width_bits != 0)
			line_cap:           key.stroke.cap
			line_join:          key.stroke.join
			non_scaling_stroke: i32(key.stroke.non_scaling)
			stroke_width:       math.f32_from_bits(key.stroke.width_bits)
			miter_limit:        math.f32_from_bits(key.stroke.miter_bits)
		}
		stops := if gradient != unsafe { nil } {
			chromium_svg_gradient_stops(gradient.style)
		} else { []f32{} }
		if gradient != unsafe { nil } {
			path.gradient = gradient.key.kind
			path.tile_mode = gradient.key.tile_mode
			path.opacity = math.f32_from_bits(gradient.key.opacity_bits)
			path.gradient_points = gradient.key.points
			path.gradient_matrix = if key.stroke.non_scaling {
				portable_svg_non_scaling_gradient_matrix(matrix, gradient.key.matrix)
			} else {
				gradient.key.matrix
			}
			path.stops = stops.data
			path.stop_count = stops.len / 5
		}
		dash := if key.stroke.dash_count != 0 {
			?ggshape.SVGPathDash(ggshape.SVGPathDash{data.stroke_dasharray, data.stroke_dashoffset})
		} else {
			none
		}
		ggshape.record_svg_path(mut target, &path, dash)!
		return target.take_document_image()!
	}

	fn (mut app BrowserApp) draw_portable_gpu_svg_stroke(command &layout.PaintCommand,
		data layout.PaintSVGPathData, page_x f32, page_y f32) bool {
		if !may_try_portable_svg_gpu() || app.paint_effect_depth != 0 || app.paint_svg_mask_depth != 0
			|| (command.stroke_color == '' && data.svg_gradient_data == none) || command.stroke_width <= 0
			|| data.path_data.len < layout.compatibility_clip_path_segment_stride
			|| data.stroke_pattern != none {
			return false
		}
		dash_count := data.stroke_dasharray.len
		if dash_count > 0 && (dash_count > portable_svg_gpu_dash_intervals
			|| data.path_data.len > portable_svg_gpu_cached_values) {
			return false
		}
		width := f32(command.stroke_width)
		miter := f32(if data.stroke_miterlimit > 1 { data.stroke_miterlimit } else { 1.0 })
		if !(width > 0) || math.is_inf(f64(width), 0) || math.is_inf(f64(miter), 0) {
			return false
		}
		opacity := command.opacity * data.stroke_opacity
		mut color := gg.Color{}
		gradient := if command.stroke_color == '' {
			brush := portable_svg_path_gradient(command, true, opacity) or { return false }
			if math.f32_from_bits(brush.key.opacity_bits) == 0 || brush.style.color_stops.len == 0 {
				return true
			}
			&brush
		} else {
			color = app.paint_colors.color_with_retained(command.stroke_color, opacity,
				command.retained_svg_stroke_color())
			if color.a == 0 { return true }
			unsafe { nil }
		}
		cached_bounds, geometry_slot := portable_gpu_svg_local_bounds(data.path_data)
		local := if geometry_slot >= 0 { cached_bounds } else {
			portable_svg_gpu_path_bounds(data.path_data, false) or { return false }
		}
		transform := portable_device_transform(multiply_paint_transforms(command.transform,
			data.path_transform), page_x, page_y, f64(app.ctx.scale))
		bounds := portable_svg_stroke_bounds(&data, local, transform, app.portable_device_viewport(page_y), width, miter)
		if bounds.is_empty() { return true }
		stroke := PortableSVGStroke{
			width_bits: math.f32_bits(width)
			miter_bits: math.f32_bits(miter)
			cap:        i32(data.stroke_linecap)
			join:       i32(data.stroke_linejoin)
			non_scaling: data.non_scaling_stroke
			dash_count: dash_count
			dash_offset_bits: if dash_count > 0 { math.f64_bits(data.stroke_dashoffset) } else { u64(0) }
		}
		return draw_portable_gpu_svg_path(app.ctx, data, portable_svg_surface_matrix(transform, bounds),
			bounds, color, local, geometry_slot, stroke, gradient)
	}

	fn draw_portable_gpu_svg_path(ctx &gg.Context, data layout.PaintSVGPathData,
		matrix [6]f32, bounds painting.IntRect, color gg.Color, local_bounds cpuraster.Rect,
		geometry_slot int, stroke PortableSVGStroke, gradient &PortableSVGGradientPaint) bool {
		mut state := unsafe { portable_svg_gpu }
		renderer := ctx.r
		if renderer == unsafe { nil } || bounds.width > 1024 || bounds.height > 1024 {
			return false
		}
		remaining_pixels := portable_svg_gpu_pixel_limit - state.pixels
		draw_pixels := bounds.width * bounds.height
		if !state.tried {
			state.initialize(ctx)
		}
		if state.canvas == unsafe { nil } {
			return false
		}
		// The matrix is relative to the texture, so integer scroll offsets
		// can reuse it wherever the path appears in the new paint order.
		key := PortableSVGTextureKey{
			matrix:   matrix
			width:    bounds.width
			height:   bounds.height
			color:    color
			even_odd: data.fill_even_odd
			gradient: gradient != unsafe { nil }
			stroke:   stroke
		}
		cacheable := !disable_portable_svg_gpu_cache && data.path_data.len <= portable_svg_gpu_cached_values
			&& (!key.gradient || gradient.style.color_stops.len <= portable_svg_gpu_gradient_stops)
		if !cacheable && draw_pixels > remaining_pixels {
			return false
		}
		mut vacant := -1
		mut idle := -1
		mut matching := -1
		mut crop := ?painting.IntPoint(none)
		// The bounds lookup already compared the path bytes in this slot.
		if cacheable && geometry_slot >= 0 {
			texture := &state.textures[geometry_slot]
			if texture.matches(&key, &data, true) && (!key.gradient || texture.matches_gradient(gradient)) {
				matching = geometry_slot
			}
		}
		hint_hit := matching >= 0
		if !hint_hit {
			// Keep the previous frame's images available until all current draws
			// have had a chance to match them. Evict older, unused images if needed.
			for index in 0 .. portable_svg_gpu_texture_slots {
				texture := &state.textures[index]
				if texture.image.id == 0 {
					if vacant < 0 {
						vacant = index
					}
				} else if cacheable && index != geometry_slot && texture.matches(&key, &data, false)
					&& (!key.gradient || texture.matches_gradient(gradient)) {
					matching = index
					crop = none
					break
				} else if cacheable && portable_svg_viewport_reuse && !key.gradient && matching < 0
					&& (texture.used || texture.key.width * texture.key.height <= remaining_pixels) {
					if origin := texture.crop_origin(&key, &data) {
						matching = index
						crop = origin
					}
				}
				if portable_svg_viewport_reuse && idle < 0 && texture.idle && !texture.used {
					idle = index
				}
			}
		}
		reused := matching >= 0
		image_pixels := if reused {
			texture := &state.textures[matching]
			if texture.used { 0 } else { texture.key.width * texture.key.height }
		} else {
			draw_pixels
		}
		if image_pixels > remaining_pixels {
			return false
		}
		index := if reused { matching } else if vacant >= 0 { vacant } else { idle }
		if index < 0 && state.transient_count == portable_svg_gpu_transient_slots {
			return false
		}
		image := if reused {
			state.textures[index].image
		} else {
			if index >= 0 && state.textures[index].idle {
				state.textures[index].release()
			}
			resolved := state.rasterize(data, &key, gradient) or { return false }
			if index >= 0 {
				mut texture := &state.textures[index]
				texture.image = resolved
				if cacheable {
					texture.key = key
					texture.local_bounds = local_bounds
					unsafe {
						vmemcpy(&texture.values[0], data.path_data.data, data.path_data.len * int(sizeof(f32)))
						if stroke.dash_count != 0 {
							vmemcpy(&texture.dashes[0], data.stroke_dasharray.data, stroke.dash_count * int(sizeof(f64)))
						}
					}
					if key.gradient {
						texture.store_gradient(gradient)
					}
					texture.length = data.path_data.len
				}
			} else {
				// The queued quad still needs this image through frame submission.
				state.transient_images[state.transient_count] = resolved
				state.transient_count++
			}
			resolved
		}
		if index >= 0 {
			state.textures[index].used = true
		}
		state.pixels += image_pixels
		// GG presents the premultiplied Canvas texture in document order.
		// Canvas keeps the logical top row at texture coordinate zero.
		x := f32(bounds.x)
		y := f32(bounds.y)
		right := f32(bounds.x + bounds.width)
		bottom := f32(bounds.y + bounds.height)
		mut u0, mut v0, mut u1, mut v1 := f32(0), f32(0), f32(1), f32(1)
		if origin := crop {
			texture := &state.textures[index]
			u0 = f32(origin.x) / f32(texture.key.width)
			v0 = f32(origin.y) / f32(texture.key.height)
			u1 = f32(origin.x + bounds.width) / f32(texture.key.width)
			v1 = f32(origin.y + bounds.height) / f32(texture.key.height)
		}
		renderer.push_pipeline()
		renderer.load_pipeline(state.pipeline)
		renderer.enable_texture()
		renderer.texture(image, state.sampler)
		renderer.begin_quads()
		renderer.c4b(255, 255, 255, 255)
		renderer.v3f_t2f(x, y, 0, u0, v0)
		renderer.v3f_t2f(right, y, 0, u1, v0)
		renderer.v3f_t2f(right, bottom, 0, u1, v1)
		renderer.v3f_t2f(x, bottom, 0, u0, v1)
		renderer.end()
		renderer.disable_texture()
		renderer.pop_pipeline()
		if portable_svg_gpu_diagnostics {
			eprintln('VOX_GG_SVG draw=${bounds.width}x${bounds.height} cache=${if reused { "hit" } else { "miss" }} bounds=${if geometry_slot >= 0 { "hit" } else { "miss" }} crop=${if crop != none { "hit" } else { "none" }}${if hint_hit { " hint=hit" } else { "" }}${if index < 0 { " transient=1" } else { "" }} stroke=${int(stroke.width_bits != 0)}${if stroke.non_scaling { " non_scaling=1" } else { "" }}${if stroke.dash_count > 0 { " dash=${stroke.dash_count}" } else { "" }}${if key.gradient { " gradient=${gradient.key.kind}" } else { "" }}')
		}
		return true
	}
}
