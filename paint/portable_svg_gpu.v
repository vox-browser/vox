module main

$if vox_gg_svg ? {
	import gg
	import gg.canvas
	import gg.render
	import ggshape
	import layout
	import os
	import painting
	import platform
	import sokol.gfx

	const portable_svg_gpu_enabled = os.getenv('VOX_GG_SVG') == '1'
	const portable_svg_gpu_diagnostics = os.getenv('VOX_GG_SVG_DIAGNOSTICS') == '1'
	const disable_portable_svg_gpu_cache = os.getenv('VOX_DISABLE_GG_SVG_CACHE') == '1'
	const portable_svg_gpu_image_limit = 8
	const portable_svg_gpu_pixel_limit = 1024 * 1024
	const portable_svg_gpu_cached_values = 128 * layout.compatibility_clip_path_segment_stride
	const portable_svg_gpu = &PortableSVGGpu{}

	struct PortableSVGTextureKey {
		matrix   [6]f32
		width    int
		height   int
		color    gg.Color
		even_odd bool
	}

	struct PortableSVGTexture {
	mut:
		image    gfx.Image
		key      PortableSVGTextureKey
		// Own a bounded copy because document paint storage can retire or change
		// between frames. Zero values recorded means the texture is transient.
		values   [portable_svg_gpu_cached_values]f32
		length   int
	}

	fn (texture &PortableSVGTexture) matches(key &PortableSVGTextureKey, values []f32) bool {
		if texture.length != values.len || texture.key.width != key.width
			|| texture.key.height != key.height || texture.key.color != key.color
			|| texture.key.even_odd != key.even_odd {
			return false
		}
		return unsafe {
			vmemcmp(&texture.key.matrix[0], &key.matrix[0], 6 * int(sizeof(f32))) == 0
				&& vmemcmp(&texture.values[0], values.data, values.len * int(sizeof(f32))) == 0
		}
	}

	fn (mut texture PortableSVGTexture) release() {
		if texture.image.id != 0 {
			gfx.destroy_image(texture.image)
			texture.image = gfx.Image{}
		}
		texture.length = 0
	}

	// The legacy GG window owns one Sokol context per process. It also owns
	// this renderer when multiple tabs share the window.
	struct PortableSVGGpu {
	mut:
		tried    bool
		canvas   &canvas.GpuContext = unsafe { nil }
		pipeline render.Pipeline
		sampler  gfx.Sampler
		textures [portable_svg_gpu_image_limit]PortableSVGTexture
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
		for index in 0 .. portable_svg_gpu_image_limit {
			if index >= state.count || state.textures[index].length == 0 {
				state.textures[index].release()
			}
		}
		state.count = 0
		state.pixels = 0
	}

	fn (mut state PortableSVGGpu) release(renderer &render.Context) {
		if state.canvas == unsafe { nil } {
			return
		}
		for index in 0 .. portable_svg_gpu_image_limit {
			state.textures[index].release()
		}
		renderer.destroy_pipeline(state.pipeline)
		gfx.destroy_sampler(state.sampler)
		mut gpu := state.canvas
		gpu.free()
		state.canvas = unsafe { nil }
	}

	fn (mut state PortableSVGGpu) rasterize(data layout.PaintSVGPathData, key &PortableSVGTextureKey) !gfx.Image {
		mut gpu := state.canvas
		mut target := gpu.new_surface(width: key.width, height: key.height)!
		defer {
			target.free()
		}
		matrix := key.matrix
		color := key.color
		path := C.VoxGraphitePath{
			matrix:        [matrix[0], matrix[2], matrix[4], matrix[1], matrix[3], matrix[5], 0, 0, 1]!
			segments:      data.path_data.data
			segment_count: i32(data.path_data.len / layout.compatibility_clip_path_segment_stride)
			even_odd:      i32(key.even_odd)
			red:           color.r
			green:         color.g
			blue:          color.b
			alpha:         color.a
		}
		ggshape.record_svg_path(mut target, &path)!
		return target.take_document_image()!
	}

	fn draw_portable_gpu_svg_fill(renderer &render.Context, data layout.PaintSVGPathData,
		matrix [6]f32, bounds painting.IntRect, color gg.Color) bool {
		mut state := unsafe { portable_svg_gpu }
		// Bound GPU memory and the number of pending passes for this replay.
		if renderer == unsafe { nil } || state.count == portable_svg_gpu_image_limit
			|| bounds.width > 1024 || bounds.height > 1024 {
			return false
		}
		area := bounds.width * bounds.height
		if area > portable_svg_gpu_pixel_limit - state.pixels {
			return false
		}
		if !state.tried {
			state.initialize(renderer)
		}
		if state.canvas == unsafe { nil } {
			return false
		}
		// A slot follows the order of successful GPU draws. Its matrix is
		// relative to the texture, so integer scroll offsets can reuse it.
		key := PortableSVGTextureKey{
			matrix:   matrix
			width:    bounds.width
			height:   bounds.height
			color:    color
			even_odd: data.fill_even_odd
		}
		mut texture := &state.textures[state.count]
		cacheable := !disable_portable_svg_gpu_cache && data.path_data.len <= portable_svg_gpu_cached_values
		reused := cacheable && texture.matches(&key, data.path_data)
		if !reused {
			texture.release()
			texture.image = state.rasterize(data, &key) or { return false }
			if cacheable {
				texture.key = key
				unsafe {
					vmemcpy(&texture.values[0], data.path_data.data, data.path_data.len * int(sizeof(f32)))
				}
				texture.length = data.path_data.len
			}
		}
		state.count++
		state.pixels += area
		// GG presents the texture in document order. Canvas uses top-down
		// OpenGL texture coordinates and outputs premultiplied RGBA.
		x := f32(bounds.x)
		y := f32(bounds.y)
		right := f32(bounds.x + bounds.width)
		bottom := f32(bounds.y + bounds.height)
		renderer.push_pipeline()
		renderer.load_pipeline(state.pipeline)
		renderer.enable_texture()
		renderer.texture(texture.image, state.sampler)
		renderer.begin_quads()
		renderer.c4b(255, 255, 255, 255)
		renderer.v3f_t2f(x, y, 0, 0, 0)
		renderer.v3f_t2f(right, y, 0, 1, 0)
		renderer.v3f_t2f(right, bottom, 0, 1, 1)
		renderer.v3f_t2f(x, bottom, 0, 0, 1)
		renderer.end()
		renderer.disable_texture()
		renderer.pop_pipeline()
		if portable_svg_gpu_diagnostics {
			eprintln('VOX_GG_SVG draw=${bounds.width}x${bounds.height} cache=${if reused { "hit" } else { "miss" }}')
		}
		return true
	}
}
