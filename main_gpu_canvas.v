module main

import layout
import browsersettings
import os

const gpu_scrollbar_batch_enabled = os.getenv('VOX_GPU_SCROLLBAR_BATCH') != ''

$if macos {
	fn C.native_gpu_canvas_begin() int
	fn C.native_gpu_canvas_begin_rects(rects &f32, count i32) int
	fn C.native_gpu_canvas_cpu_access()
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
	return flags
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
