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
	const portable_svg_gpu_image_limit = 8
	const portable_svg_gpu_pixel_limit = 1024 * 1024
	const portable_svg_gpu = &PortableSVGGpu{}

	// The legacy GG window owns one Sokol context per process. It also owns
	// this renderer when multiple tabs share the window.
	struct PortableSVGGpu {
	mut:
		tried    bool
		canvas   &canvas.GpuContext = unsafe { nil }
		pipeline render.Pipeline
		sampler  gfx.Sampler
		images   [portable_svg_gpu_image_limit]gfx.Image
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
		for index in 0 .. state.count {
			gfx.destroy_image(state.images[index])
		}
		state.count = 0
		state.pixels = 0
	}

	fn (mut state PortableSVGGpu) release(renderer &render.Context) {
		if state.canvas == unsafe { nil } {
			return
		}
		state.finish_frame()
		renderer.destroy_pipeline(state.pipeline)
		gfx.destroy_sampler(state.sampler)
		mut gpu := state.canvas
		gpu.free()
		state.canvas = unsafe { nil }
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
		mut gpu := state.canvas
		mut target := gpu.new_surface(width: bounds.width, height: bounds.height) or { return false }
		defer {
			target.free()
		}
		path := C.VoxGraphitePath{
			matrix:        [matrix[0], matrix[2], matrix[4], matrix[1], matrix[3], matrix[5], 0, 0, 1]!
			segments:      data.path_data.data
			segment_count: i32(data.path_data.len / layout.compatibility_clip_path_segment_stride)
			even_odd:      i32(data.fill_even_odd)
			red:           color.r
			green:         color.g
			blue:          color.b
			alpha:         color.a
		}
		ggshape.record_svg_path(mut target, &path) or { return false }
		image := target.take_document_image() or { return false }
		state.images[state.count] = image
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
		renderer.texture(image, state.sampler)
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
			eprintln('VOX_GG_SVG draw=${bounds.width}x${bounds.height}')
		}
		return true
	}
}
