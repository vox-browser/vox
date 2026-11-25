module main

import cpuraster
import layout
import math
import os
import platform
import processmetrics

const serial_paint_canvas_bounds = os.getenv('VOX_SERIAL_PAINT_CANVAS_BOUNDS') == '1'
const paint_canvas_bounds_worker_diagnostics = os.getenv('VOX_PAINT_CANVAS_BOUNDS_WORKER_DIAGNOSTICS') == '1'
const paint_canvas_bounds_commands_per_lane = 96

enum PaintLeafCanvasBounds as u8 {
	unprepared
	retain
	outside
}

struct PaintCanvasBoundsWork {
	commands []layout.PaintCommand
	bounds   &PaintLeafCanvasBounds
	threads  &u64
	page_y   f64
	width    f64
	height   f64
}

// The display list remains immutable while workers calculate the same
// geometry that the draw loop would use for independent leaves.
fn prepare_paint_canvas_bounds_range(context voidptr, first i32, end i32) {
	work := unsafe { &PaintCanvasBoundsWork(context) }
	thread_id := if work.threads != unsafe { nil } { platform.native_thread_identity() } else { u64(0) }
	for index in int(first) .. int(end) {
		command := unsafe { &work.commands[index] }
		kind := command.kind
		// Replay handles group transitions in order and reads live video facts.
		if kind == 'draw_video' || kind.starts_with('begin_') || kind.starts_with('end_') {
			continue
		}
		result := if layout.paint_leaf_is_outside_canvas(command, 0, work.page_y, work.width, work.height) {
			PaintLeafCanvasBounds.outside
		} else {
			PaintLeafCanvasBounds.retain
		}
		unsafe { work.bounds[index] = result }
		if thread_id != 0 { unsafe { work.threads[index] = thread_id } }
	}
}

fn prepare_paint_canvas_bounds(commands []layout.PaintCommand, page_y f64, width f64,
	height f64) []PaintLeafCanvasBounds {
	$if macos {
		lanes := math.min(4, commands.len / paint_canvas_bounds_commands_per_lane)
		if serial_paint_canvas_bounds || lanes < 2 { return [] }
		stage := processmetrics.begin_thread_instruction_substage('paint_canvas_bounds_preparation')
		defer { stage.finish() }
		mut bounds := []PaintLeafCanvasBounds{len: commands.len}
		mut threads := []u64{}
		if paint_canvas_bounds_worker_diagnostics { threads = []u64{len: commands.len} }
		work := PaintCanvasBoundsWork{
			commands: commands
			bounds: unsafe { &PaintLeafCanvasBounds(bounds.data) }
			threads: unsafe { if threads.len > 0 { &u64(threads.data) } else { &u64(nil) } }
			page_y: page_y
			width: width
			height: height
		}
		used_lanes := cpuraster.run_raster_ranges_with_caller(&work, commands.len, lanes,
			prepare_paint_canvas_bounds_range)
		if used_lanes == 0 { return [] }
		if paint_canvas_bounds_worker_diagnostics {
			caller := platform.native_thread_identity()
			off_thread := threads.count(it != 0 && it != caller)
			prepared := threads.count(it != 0)
			outside := bounds.count(it == .outside)
			eprintln('VOX_PAINT_CANVAS_BOUNDS_BATCH commands=${commands.len} prepared=${prepared} lanes=${used_lanes} off_thread=${off_thread} outside=${outside}')
		}
		return bounds
	}
	return []
}
