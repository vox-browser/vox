module ggshape

$if !macos {
	$compile_error('The gg.canvas browser adapters currently require macOS')
}

import gg.canvas

// draw_path implements vox_graphite_draw_path_pixels() for supported
// descriptors like the backend's draw_path_on_canvas(): it fills the path
// over BGRA8 premultiplied pixels (or transparency without a background) and
// returns 1, or returns 0 without touching the pixels. It runs only on the
// main thread.
pub fn draw_path(pixels &u8, width i32, height i32, pitch i32, has_background i32, path &C.VoxGraphitePath) i32 {
	result := draw_path_pixels(pixels, width, height, pitch, has_background, path, false)
	if diagnostics && path != unsafe { nil } {
		eprintln('VOX_GG path stroke=${path.stroke} non_scaling=${path.non_scaling_stroke} gradient=${path.gradient} even_odd=${path.even_odd} drawn=${result}')
	}
	return result
}

// A leaf in a multisampled picture retains that pass even when the path itself
// is an analytic oval or rectangle and would not request MSAA on its own.
pub fn draw_multisampled_path(pixels &u8, width i32, height i32, pitch i32,
	has_background i32, path &C.VoxGraphitePath) i32 {
	return draw_path_pixels(pixels, width, height, pitch, has_background, path, true)
}

fn draw_path_pixels(pixels &u8, width i32, height i32, pitch i32, has_background i32, path &C.VoxGraphitePath, multisampled bool) i32 {
	if !path_pixels_supported(pixels, width, height, pitch, path) || C.pthread_main_np() == 0 {
		return 0
	}
	mut ctx := context() or { return 0 }
	return draw_supported_path(mut ctx, pixels, width, height, pitch, has_background, path, multisampled)
}

// The flags of vox_graphite_draw_svg_image_pixels().
const svg_backdrop = 1
const svg_force_msaa = 2
// Scalar document batches clip their conservative viewport without edge AA.
const svg_hard_viewport = 4

// draw_svg_image implements vox_graphite_draw_svg_image_pixels() like the
// backend's draw_svg_image_pixels(): the descriptors drawn after the SVG
// image's parent matrix and clipped to its viewport (and drawn in a layer
// inside its rounded clip), over the pixels with VOX_GRAPHITE_SVG_BACKDROP
// (or transparency), in a pass that is multisampled with
// VOX_GRAPHITE_SVG_FORCE_MSAA. Descriptors gg.canvas cannot reproduce return
// 0 without touching the pixels. It runs only on the main thread.
pub fn draw_svg_image(pixels &u8, width i32, height i32, pitch i32, flags i32, paths &C.VoxGraphitePath, count i32, parent &f32, viewport &f32, rounded_clip &f32) i32 {
	result := draw_svg_image_pixels(pixels, width, height, pitch, flags, paths, count, parent,
		viewport, rounded_clip)
	if diagnostics {
		eprintln('VOX_GG svg paths=${count} rounded=${int(rounded_clip != unsafe { nil })} drawn=${result}')
	}
	return result
}

fn draw_svg_image_pixels(pixels &u8, width i32, height i32, pitch i32, flags i32, paths &C.VoxGraphitePath, count i32, parent &f32, viewport &f32, rounded_clip &f32) i32 {
	if pixels == unsafe { nil } || paths == unsafe { nil } || parent == unsafe { nil }
		|| viewport == unsafe { nil } || count <= 0
		|| count > 65536 || width <= 0 || height <= 0 || pitch < width * 4
		|| C.pthread_main_np() == 0 {
		return 0
	}
	for index in 0 .. int(count) {
		if !path_supported(unsafe { &paths[index] }) {
			return 0
		}
	}
	mut ctx := context() or { return 0 }
	mut target := ctx.new_surface(width: int(width), height: int(height)) or { return 0 }
	defer {
		target.free()
	}
	if flags & svg_backdrop != 0 {
		target.write_pixels(pixels, int(pitch)) or { return 0 }
	} else {
		target.clear(canvas.Color4f{})
	}
	record_svg_image(mut target, flags, paths, count, parent, viewport, rounded_clip) or { return 0 }
	target.read_pixels(pixels, int(pitch)) or { return 0 }
	return 1
}

// record_svg_image adds an SVG image's draws to a surface that already holds
// its backdrop: the pass's sample count, the parent matrix, the viewport and
// rounded clips, and each descriptor.
fn record_svg_image(mut target canvas.GpuSurface, flags i32, paths &C.VoxGraphitePath, count i32, parent &f32, viewport &f32, rounded_clip &f32) ! {
	if flags & svg_force_msaa != 0 {
		target.draw_msaa_trigger()
	}
	mut parent_values := [9]f32{}
	for i in 0 .. 9 {
		parent_values[i] = unsafe { parent[i] }
	}
	parent_matrix := canvas.Matrix.values(parent_values)
	target.set_matrix(parent_matrix)
	v := unsafe { [viewport[0], viewport[1], viewport[2], viewport[3]] }
	target.clip_rect(canvas.Rect.xywh(v[0], v[1], v[2], v[3]), .intersect, flags & svg_hard_viewport == 0)!
	layered := rounded_clip != unsafe { nil }
	if layered {
		mut values := [12]f32{}
		for i in 0 .. 12 {
			values[i] = unsafe { rounded_clip[i] }
		}
		target.clip_rrect(rounded_rect(values), .intersect, true)!
		target.save_layer(none)!
	}
	for index in 0 .. int(count) {
		draw_descriptor(mut target, unsafe { &paths[index] }, parent_matrix, none)!
	}
	if layered {
		target.restore()
	}
}
