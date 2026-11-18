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
	const portable_svg_gpu_viewport_reuse = os.getenv('VOX_GG_SVG_VIEWPORT_REUSE') == '1'
	const portable_svg_gpu_image_limit = 8
	const portable_svg_gpu_texture_slots = 2 * portable_svg_gpu_image_limit
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
	}

	fn (texture &PortableSVGTexture) matches(key &PortableSVGTextureKey, data &layout.PaintSVGPathData) bool {
		if texture.key.width != key.width
			|| texture.key.height != key.height || texture.key.color != key.color
			|| texture.key.even_odd != key.even_odd || texture.key.gradient != key.gradient
			|| texture.key.stroke != key.stroke {
			return false
		}
		return unsafe {
			vmemcmp(&texture.key.matrix[0], &key.matrix[0], 6 * int(sizeof(f32))) == 0
		} && texture.matches_path(key, data)
	}

	fn (texture &PortableSVGTexture) crop_origin(key &PortableSVGTextureKey, data &layout.PaintSVGPathData) ?painting.IntPoint {
		if texture.key.gradient || texture.key.width < key.width || texture.key.height < key.height
			|| (texture.key.width == key.width && texture.key.height == key.height)
			|| texture.key.color != key.color || texture.key.even_odd != key.even_odd
			|| texture.key.stroke != key.stroke {
			return none
		}
		if unsafe { vmemcmp(&texture.key.matrix[0], &key.matrix[0], 4 * int(sizeof(f32))) != 0 } {
			return none
		}
		// Local translations differ by the texel offset of the visible
		// rectangle. Require the same subpixel phase and complete coverage.
		x := f64(texture.key.matrix[4]) - f64(key.matrix[4])
		y := f64(texture.key.matrix[5]) - f64(key.matrix[5])
		if !(x >= 0 && x <= f64(texture.key.width - key.width)
			&& y >= 0 && y <= f64(texture.key.height - key.height)) {
			return none
		}
		origin := painting.IntPoint{int(x), int(y)}
		if x != f64(origin.x) || y != f64(origin.y) || !texture.matches_path(key, data) {
			return none
		}
		return origin
	}

	fn (texture &PortableSVGTexture) matches_path(key &PortableSVGTextureKey,
		data &layout.PaintSVGPathData) bool {
		return texture.matches_geometry(data.path_data) && (key.stroke.dash_count == 0 || unsafe {
			vmemcmp(&texture.dashes[0], data.stroke_dasharray.data,
				key.stroke.dash_count * int(sizeof(f64))) == 0
		})
	}

	fn (texture &PortableSVGTexture) matches_geometry(values []f32) bool {
		return texture.length == values.len && unsafe {
			vmemcmp(&texture.values[0], values.data, values.len * int(sizeof(f32))) == 0
		}
	}

	fn portable_gpu_svg_local_bounds(values []f32) ?cpuraster.Rect {
		state := unsafe { portable_svg_gpu }
		if disable_portable_svg_gpu_cache || portable_svg_gpu_cache_control == 'bounds'
			|| state.canvas == unsafe { nil } || state.count == portable_svg_gpu_image_limit
			|| values.len > portable_svg_gpu_cached_values {
			return none
		}
		for index in 0 .. portable_svg_gpu_texture_slots {
			texture := &state.textures[index]
			if texture.matches_geometry(values) {
				return texture.local_bounds
			}
		}
		return none
	}

	fn (mut texture PortableSVGTexture) release() {
		if texture.image.id != 0 {
			gfx.destroy_image(texture.image)
			texture.image = gfx.Image{}
		}
		texture.length = 0
		texture.used = false
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
		count    int
		pixels   int
	}

	fn (mut state PortableSVGGpu) initialize(renderer &render.Context) {
		state.tried = true
		if !gfx.is_valid() || gfx.query_backend() != .glcore33 {
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
		state.pipeline = renderer.make_pipeline(desc)
		state.sampler = gfx.make_sampler(&gfx.SamplerDesc{
			min_filter: .nearest
			mag_filter: .nearest
			wrap_u:     .clamp_to_edge
			wrap_v:     .clamp_to_edge
		})
		if gfx.query_pipeline_state(state.pipeline.pips[3]) != .valid
			|| gfx.query_sampler_state(state.sampler) != .valid {
			state.release(renderer)
		}
	}

	fn (mut state PortableSVGGpu) finish_frame() {
		// All commands that sampled a texture have been submitted at this point.
		for index in 0 .. portable_svg_gpu_texture_slots {
			mut texture := &state.textures[index]
			if !texture.used || texture.length == 0 {
				texture.release()
			}
			texture.used = false
		}
		state.count = 0
		state.pixels = 0
	}

	fn (mut state PortableSVGGpu) release(renderer &render.Context) {
		if state.canvas == unsafe { nil } {
			return
		}
		for index in 0 .. portable_svg_gpu_texture_slots {
			state.textures[index].release()
		}
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

	fn portable_svg_stroke_outset(data &layout.PaintSVGPathData, width f32, miter f32) f64 {
		cap := if data.stroke_linecap == 2 { math.sqrt2 } else { 1.0 }
		join := if data.stroke_linejoin == 0 { math.max(1.0, f64(miter)) } else { 1.0 }
		return f64(width) * 0.5 * math.max(cap, join)
	}

	fn (app &BrowserApp) portable_non_scaling_stroke_fringe(command &layout.PaintCommand) f32 {
		if !portable_svg_gpu_enabled || command.kind != 'draw_svg_path' || command.stroke_width <= 0 {
			return 0
		}
		data := command.svg_data
		if data == unsafe { nil } || !data.non_scaling_stroke
			|| (command.stroke_color == '' && data.svg_gradient_data == none) {
			return 0
		}
		// Layout's visual bounds are in transformed CSS pixels. The stroke's
		// outset stays in device pixels until converted for viewport culling.
		pad := portable_svg_stroke_outset(data, f32(command.stroke_width), f32(data.stroke_miterlimit))
		return f32((pad + 1) / f64(app.ctx.scale))
	}

	fn (mut app BrowserApp) draw_portable_gpu_svg_stroke(command &layout.PaintCommand,
		data layout.PaintSVGPathData, page_x f32, page_y f32) bool {
		if !portable_svg_gpu_enabled || app.paint_effect_depth != 0 || app.paint_svg_mask_depth != 0
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
		state := unsafe { portable_svg_gpu }
		if state.count == portable_svg_gpu_image_limit || (state.tried && state.canvas == unsafe { nil }) {
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
		cached := portable_gpu_svg_local_bounds(data.path_data)
		local := cached or {
			portable_svg_gpu_path_bounds(data.path_data, false) or { return false }
		}
		transform := portable_device_transform(multiply_paint_transforms(command.transform,
			data.path_transform), page_x, page_y, f64(app.ctx.scale))
		pad := portable_svg_stroke_outset(&data, width, miter)
		rect := painting.Rect{f64(local.left), f64(local.top),
			f64(local.right) - f64(local.left), f64(local.bottom) - f64(local.top)}
		// The recorder transforms non-scaling geometry before stroking in
		// device space. Bound caps and miters in that same space.
		outline := if data.non_scaling_stroke {
			transform.map_rect(rect).inflated(pad, pad, pad, pad)
		} else {
			transform.map_rect(rect.inflated(pad, pad, pad, pad))
		}
		ink := outline.inflated(1, 1, 1, 1)
		bounds := portable_pixel_bounds(ink.intersection(app.portable_device_viewport(page_y)))
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
		return draw_portable_gpu_svg_path(app.ctx.r, data, portable_svg_surface_matrix(transform, bounds),
			bounds, color, local, cached != none, stroke, gradient)
	}

	fn draw_portable_gpu_svg_path(renderer &render.Context, data layout.PaintSVGPathData,
		matrix [6]f32, bounds painting.IntRect, color gg.Color, local_bounds cpuraster.Rect,
		reused_bounds bool, stroke PortableSVGStroke, gradient &PortableSVGGradientPaint) bool {
		mut state := unsafe { portable_svg_gpu }
		// Bound GPU memory and the number of pending passes for this replay.
		if renderer == unsafe { nil } || state.count == portable_svg_gpu_image_limit
			|| bounds.width > 1024 || bounds.height > 1024 {
			return false
		}
		remaining_pixels := portable_svg_gpu_pixel_limit - state.pixels
		if bounds.width * bounds.height > remaining_pixels {
			return false
		}
		if !state.tried {
			state.initialize(renderer)
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
		// Keep the previous frame's images available until all current draws
		// have had a chance to match them. Each frame uses at most eight slots.
		mut vacant := -1
		mut matching := -1
		mut crop := ?painting.IntPoint(none)
		for index in 0 .. portable_svg_gpu_texture_slots {
			texture := &state.textures[index]
			if texture.image.id == 0 {
				if vacant < 0 {
					vacant = index
				}
			} else if cacheable && texture.matches(&key, &data)
				&& (!key.gradient || texture.matches_gradient(gradient)) {
				matching = index
				crop = none
				break
			} else if cacheable && portable_svg_gpu_viewport_reuse && !key.gradient && matching < 0
				&& texture.key.width * texture.key.height <= remaining_pixels {
				if origin := texture.crop_origin(&key, &data) {
					matching = index
					crop = origin
				}
			}
		}
		reused := matching >= 0
		index := if reused { matching } else { vacant }
		if index < 0 {
			return false
		}
		mut texture := &state.textures[index]
		if !reused {
			texture.image = state.rasterize(data, &key, gradient) or { return false }
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
		}
		texture.used = true
		state.count++
		// GG presents the texture in document order. Canvas uses top-down
		// OpenGL texture coordinates and outputs premultiplied RGBA.
		x := f32(bounds.x)
		y := f32(bounds.y)
		right := f32(bounds.x + bounds.width)
		bottom := f32(bounds.y + bounds.height)
		mut u0, mut v0, mut u1, mut v1 := f32(0), f32(0), f32(1), f32(1)
		if origin := crop {
			u0 = f32(origin.x) / f32(texture.key.width)
			v0 = f32(origin.y) / f32(texture.key.height)
			u1 = f32(origin.x + bounds.width) / f32(texture.key.width)
			v1 = f32(origin.y + bounds.height) / f32(texture.key.height)
			state.pixels += texture.key.width * texture.key.height
		} else {
			state.pixels += bounds.width * bounds.height
		}
		renderer.push_pipeline()
		renderer.load_pipeline(state.pipeline)
		renderer.enable_texture()
		renderer.texture(texture.image, state.sampler)
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
			eprintln('VOX_GG_SVG draw=${bounds.width}x${bounds.height} cache=${if reused { "hit" } else { "miss" }} bounds=${if reused_bounds { "hit" } else { "miss" }} crop=${if crop != none { "hit" } else { "none" }} stroke=${int(stroke.width_bits != 0)}${if stroke.non_scaling { " non_scaling=1" } else { "" }}${if stroke.dash_count > 0 { " dash=${stroke.dash_count}" } else { "" }}${if key.gradient { " gradient=${gradient.key.kind}" } else { "" }}')
		}
		return true
	}
}
