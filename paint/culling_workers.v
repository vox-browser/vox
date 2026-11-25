module main

import cpuraster
import layout
import math
import os
import platform
import processmetrics

const serial_paint_canvas_bounds = os.getenv('VOX_SERIAL_PAINT_CANVAS_BOUNDS') == '1'
const sync_paint_canvas_bounds = os.getenv('VOX_SYNC_PAINT_CANVAS_BOUNDS') == '1'
const paint_canvas_bounds_worker_diagnostics = os.getenv('VOX_PAINT_CANVAS_BOUNDS_WORKER_DIAGNOSTICS') == '1'
const paint_canvas_bounds_commands_per_lane = 96

enum PaintLeafCanvasBounds as u8 {
	unprepared
	retain
	outside
}

struct PaintCanvasBoundsWork {
	commands       []layout.PaintCommand
	bounds         &u8
	glyph_geometry &RetainedGlyphReplayGeometry = unsafe { nil }
	glyph_positions []f32
	threads        &u64
	page_y         f64
	width          f64
	height         f64
}

// The display list remains immutable while workers calculate the same
// geometry that the draw loop would use for independent leaves.
fn prepare_paint_canvas_bounds_range(context voidptr, first i32, end i32) {
	work := unsafe { &PaintCanvasBoundsWork(context) }
	thread_id := if work.threads != unsafe { nil } { platform.native_thread_identity() } else { u64(0) }
	// The proportional split follows the command ranges. Adjacent workers
	// share a boundary and use disjoint storage even when lengths are uneven.
	glyph_count := work.glyph_positions.len
	mut glyph_start := if glyph_count > 0 { int(first) * glyph_count / work.commands.len } else { 0 }
	glyph_end := if glyph_count > 0 { int(end) * glyph_count / work.commands.len } else { 0 }
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
		unsafe { work.bounds[index] = u8(result) }
		if work.glyph_geometry != unsafe { nil } && kind == 'draw_text' {
			mut geometry := unsafe { &work.glyph_geometry[index] }
			if glyph_count == 0 {
				geometry.prepare(command)
			} else if result != .outside {
				glyph_start = geometry.prepare_in_range(command, work.glyph_positions, glyph_start, glyph_end)
			}
		}
		if thread_id != 0 { unsafe { work.threads[index] = thread_id } }
	}
}

struct PaintCanvasBoundsBatch {
	work           &PaintCanvasBoundsWork = unsafe { nil }
	bounds         []u8
	glyph_geometry []RetainedGlyphReplayGeometry
	threads        []u64
	lanes          int
mut:
	ticket           voidptr
	background_lanes int
}

fn paint_canvas_bounds_lanes(count int) int {
	$if macos {
		if !serial_paint_canvas_bounds { return math.min(4, count / paint_canvas_bounds_commands_per_lane) }
	}
	return 0
}

fn new_paint_canvas_bounds_batch(commands []layout.PaintCommand, lanes int, page_y f64,
	width f64, height f64) PaintCanvasBoundsBatch {
	// Use a byte buffer at the native worker boundary.
	bounds := []u8{len: commands.len}
	glyph_stage := processmetrics.begin_thread_instruction_substage('retained_glyph_geometry_reservation')
	geometry, glyph_positions := reserve_retained_glyph_geometry(commands)
	glyph_stage.finish()
	mut threads := []u64{}
	if paint_canvas_bounds_worker_diagnostics || retained_glyph_geometry_diagnostics {
		threads = []u64{len: commands.len}
	}
	return PaintCanvasBoundsBatch{
		bounds: bounds
		glyph_geometry: geometry
		threads: threads
		lanes: lanes
		work: &PaintCanvasBoundsWork{
			commands: commands
			bounds: unsafe { &u8(bounds.data) }
			glyph_geometry: unsafe { if geometry.len > 0 { &RetainedGlyphReplayGeometry(geometry.data) } else { nil } }
			glyph_positions: glyph_positions
			threads: unsafe { if threads.len > 0 { &u64(threads.data) } else { &u64(nil) } }
			page_y: page_y
			width: width
			height: height
		}
	}
}

fn (app &BrowserApp) can_submit_canvas_bounds_during_setup() bool {
	// Scroll reuse needs a previous command-key frame. When one exists,
	// wait for the probe before allocating or submitting any bounds.
	return !sync_paint_canvas_bounds && !app.scroll_raster_keys.valid
}

fn (mut batch PaintCanvasBoundsBatch) submit() {
	stage := processmetrics.begin_thread_instruction_substage('paint_canvas_bounds_submission')
	defer { stage.finish() }
	ticket, lanes := cpuraster.start_background_raster_ranges(batch.work, batch.bounds.len,
		batch.lanes, prepare_paint_canvas_bounds_range)
	batch.ticket = ticket
	batch.background_lanes = lanes
}

fn (mut batch PaintCanvasBoundsBatch) finish(use_bounds bool) []u8 {
	if batch.ticket == unsafe { nil } && (!use_bounds || batch.lanes < 2) { return [] }
	stage := processmetrics.begin_thread_instruction_substage('paint_canvas_bounds_preparation')
	defer { stage.finish() }
	background := batch.ticket != unsafe { nil }
	mut used_lanes := batch.background_lanes
	mut ready := false
	if background {
		ready = cpuraster.join_background_raster_range(batch.ticket)
		batch.ticket = unsafe { nil }
	} else {
		used_lanes = cpuraster.run_raster_ranges_with_caller(batch.work, batch.bounds.len, batch.lanes,
			prepare_paint_canvas_bounds_range)
	}
	if used_lanes == 0 || !use_bounds { return [] }
	if paint_canvas_bounds_worker_diagnostics {
		caller := platform.native_thread_identity()
		off_thread := batch.threads.count(it != 0 && it != caller)
		prepared := batch.threads.count(it != 0)
		outside := batch.bounds.count(it == u8(PaintLeafCanvasBounds.outside))
		eprintln('VOX_PAINT_CANVAS_BOUNDS_BATCH commands=${batch.bounds.len} prepared=${prepared} lanes=${used_lanes} off_thread=${off_thread} outside=${outside} background=${background} ready_at_join=${ready}')
	}
	if retained_glyph_geometry_diagnostics && batch.glyph_geometry.len > 0 {
		caller := platform.native_thread_identity()
		mut prepared := 0
		mut off_thread := 0
		for index, geometry in batch.glyph_geometry {
			if geometry.positions.len == 0 { continue }
			prepared++
			if batch.threads[index] != caller { off_thread++ }
		}
		mode := if batch.work.glyph_positions.len > 0 { 'worker_ranges' } else { 'packed' }
		eprintln('VOX_RETAINED_GLYPH_GEOMETRY_BATCH prepared=${prepared} off_thread=${off_thread} mode=${mode}')
	}
	return batch.bounds
}
