module main

import layout
import browsersettings
import os

const gpu_scrollbar_batch_enabled = os.getenv('VOX_DISABLE_GPU_SCROLLBAR_BATCH') == ''
// Same-binary control: zoomed frames read the canvas back for fractional
// rectangles and background images, as unzoomed frames do.
const disable_fractional_gpu_canvas = os.getenv('VOX_DISABLE_FRACTIONAL_GPU_CANVAS') != ''
const gpu_video_upload_keys_enabled = os.getenv('VOX_GPU_VIDEO_UPLOAD_KEYS') != ''
const gpu_text_layer_composites_enabled = os.getenv('VOX_GPU_TEXT_LAYER_COMPOSITES') != ''
	|| os.getenv('VOX_GPU_CANVAS_NESTED_LAYERS') != ''

$if macos {
	fn C.native_set_video_frame_resource(source u64, revision u64, generation u64)
	fn C.native_gpu_canvas_begin() int
	fn C.native_gpu_canvas_fractional_geometry(enabled i32)
	fn C.native_gpu_canvas_begin_rects(rects &f32, count i32) int
	fn C.native_gpu_canvas_cpu_access()
	fn C.native_gpu_canvas_can_defer_layers() int
	fn C.native_gpu_canvas_nested_layer_active() int
	fn C.native_gpu_canvas_end()
	fn C.native_gpu_canvas_command(kind &u8, kind_len int, flags int) int
}

fn gpu_canvas_overlay_begin(rects []f32) bool {
	$if macos {
		if !gpu_scrollbar_batch_enabled
			|| browsersettings.current().disable_gpu_canvas || rects.len == 0 { return false }
		return C.native_gpu_canvas_begin_rects(rects.data, i32(rects.len / 4)) != 0
	}
	return false
}

// Facts the native GPU canvas (on unless browsersettings disable_gpu_canvas)
// needs to decide whether a command's leaf draws on it. The decision itself
// lives in the native bridge, so its coverage can change without rebuilding
// the browser.
fn gpu_canvas_command_flags(command &layout.PaintCommand) int {
	mut flags := 0
	if command.outer_shadow { flags |= 1 }
	if command.is_caret { flags |= 2 }
	if command.scrollbar_axis != '' { flags |= 4 }
	if command.radius > 0 { flags |= 8 }
	if command.antialiased_rect { flags |= 16 }
	if command.clip_outs.len > 0 { flags |= 32 }
	matrix := normalized_paint_transform(command.transform)
	if matrix[1] != 0 || matrix[2] != 0 { flags |= 64 }
	if command.underlays_next { flags |= 128 }
	if command.disable_antialias { flags |= 256 }
	// Polygon outlines draw as CPU lines rather than through the native shape.
	if command.points.len >= 4 { flags |= 512 }
	if command.kind == 'draw_background_image' && !gpu_canvas_background_image_supported(command) {
		flags |= 1024
	}
	return flags
}

// SVG backgrounds render through their own CPU document replay, and a blend
// mode applies through the Quartz context; neither reaches the canvas leaf.
fn gpu_canvas_background_image_supported(command &layout.PaintCommand) bool {
	data := command.image_data
	if data == unsafe { nil } || data.background_svg_document != none
		|| data.background_static_svg_resource != none || data.background_blend_mode != .normal {
		return false
	}
	if layer := data.background_layer_data {
		if layer.layer.blend_mode != .normal { return false }
	}
	return true
}

// Whether this command's leaf draws on the active GPU canvas. Otherwise the
// native side has already read the GPU results back to the CPU canvas.
fn gpu_canvas_command_supported(command &layout.PaintCommand) bool {
	$if macos {
		return C.native_gpu_canvas_command(command.kind.str, command.kind.len,
			gpu_canvas_command_flags(command)) != 0
	}
	return false
}
