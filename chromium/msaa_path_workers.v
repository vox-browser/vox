module main

import cpuraster
import layout
import os
import painting
import platform

const chromium_serial_msaa_paths = os.getenv('VOX_SERIAL_MSAA_PATHS') == '1'
const chromium_sync_msaa_paths = os.getenv('VOX_SYNC_MSAA_PATHS') == '1'
const chromium_serial_msaa_path_tail = os.getenv('VOX_SERIAL_MSAA_PATH_TAIL') == '1'
const chromium_late_msaa_path_tail = os.getenv('VOX_LATE_MSAA_PATH_TAIL') == '1'
const chromium_msaa_paths_per_lane = 16
const chromium_msaa_background_paths = 2 * chromium_msaa_paths_per_lane
const chromium_msaa_max_path_jobs = 256
const chromium_msaa_path_overlap_commands = 512

struct ChromiumMSAAPathJob {
	transform [6]f64
	origin    painting.IntPoint
	viewport  layout.LayoutRect
	slot      int
mut:
	path      &layout.PaintCommand = unsafe { nil }
	trigger   ChromiumMSAATrigger
	thread_id u64
}

struct ChromiumMSAAPathWork {
mut:
	jobs    []ChromiumMSAAPathJob
	count   int
	running int
	ticket  voidptr
}

fn chromium_msaa_path_range(context voidptr, first i32, end i32) {
	jobs := unsafe { &ChromiumMSAAPathJob(context) }
	thread_id := if chromium_msaa_tile_diagnostics { platform.native_thread_identity() } else { u64(0) }
	for index in int(first) .. int(end) {
		unsafe {
			mut job := &jobs[index]
			job.trigger = chromium_svg_background_path_trigger(job.path,
				job.transform, job.origin, job.viewport, job.trigger.command_index) or {
				ChromiumMSAATrigger{command_index: -1}
			}
			job.path = nil
			job.thread_id = thread_id
		}
	}
}

fn (mut work ChromiumMSAAPathWork) add(job ChromiumMSAAPathJob, mut triggers []ChromiumMSAATrigger) {
	if work.jobs.len == 0 {
		work.jobs = []ChromiumMSAAPathJob{len: chromium_msaa_max_path_jobs}
	}
	// The worker borrows a fixed prefix. Appending later commands writes only
	// to the unused suffix, and the trigger vector can still grow independently.
	unsafe { (&ChromiumMSAAPathJob(work.jobs.data))[work.count] = job }
	work.count++
	triggers << ChromiumMSAATrigger{}
	if work.count == chromium_msaa_background_paths && !chromium_sync_msaa_paths {
		work.ticket = cpuraster.start_background_raster_range(work.jobs.data, i32(work.count),
			chromium_msaa_path_range)
		if work.ticket != unsafe { nil } { work.running = work.count }
	}
	if work.count == chromium_msaa_max_path_jobs { work.finish(mut triggers, unsafe { nil }) }
}

// Only top-level, resource-owned SVG backgrounds can add path jobs.
// Find a trailing run of ordinary leaves in the same bounded scan.
fn chromium_msaa_collection_ranges(commands []layout.PaintCommand,
	viewport ?ChromiumMSAAViewport, batch_leaves bool) (int, int) {
	first := if commands.len > chromium_msaa_path_overlap_commands {
		commands.len - chromium_msaa_path_overlap_commands
	} else { 0 }
	mut leaf_start := commands.len
	for index := commands.len - 1; index >= first; index-- {
		command := unsafe { &commands[index] }
		if batch_leaves && leaf_start == index + 1 && chromium_msaa_worker_leaf(command) {
			leaf_start = index
		}
		if command.image_data == unsafe { nil } || command.kind != 'draw_background_image'
			|| command.image_data.background_static_svg_resource == none { continue }
		if visible := viewport {
			if !chromium_svg_background_intersects_raster_viewport(command, visible) { continue }
		}
		return index + 1, leaf_start
	}
	return first, commands.len
}

fn (mut storage ChromiumMSAAStorage) queue_triggers(commands []layout.PaintCommand,
	viewport ?ChromiumMSAAViewport, batch_paths bool) voidptr {
	storage.triggers.clear()
	if !batch_paths || commands.len < chromium_msaa_background_paths {
		append_chromium_msaa_triggers(commands, viewport, mut storage.triggers)
		return unsafe { nil }
	}
	mut path_end := commands.len
	mut leaf_start := commands.len
	$if macos {
		if !chromium_late_msaa_path_tail && !chromium_serial_msaa_path_tail && !chromium_sync_msaa_paths {
			path_end, leaf_start = chromium_msaa_collection_ranges(commands, viewport,
				chromium_parallel_msaa_leaf_tail)
		}
	}
	serial_end := storage.leaf_work.submit(commands, leaf_start)
	for index in 0 .. path_end {
		append_chromium_msaa_trigger(unsafe { &commands[index] }, index, viewport, true,
			mut storage.path_work, mut storage.triggers)
	}
	tail := storage.path_work.submit_tail()
	if chromium_msaa_tile_diagnostics && tail != unsafe { nil } {
		eprintln('VOX_MSAA_PATH_TAIL_SUBMIT commands_remaining=${serial_end - path_end}')
	}
	// Later commands can append synchronous triggers while the workers fill
	// their job slots. The trigger vector is published in order at the join.
	for index in path_end .. serial_end {
		append_chromium_msaa_trigger(unsafe { &commands[index] }, index, viewport, false,
			mut storage.path_work, mut storage.triggers)
	}
	return tail
}

fn (mut storage ChromiumMSAAStorage) finish_triggers(tail voidptr) {
	storage.path_work.finish(mut storage.triggers, tail)
	storage.leaf_work.finish(mut storage.triggers)
}

fn (work &ChromiumMSAAPathWork) tail_lanes() int {
	lanes := (work.count - work.running) / chromium_msaa_paths_per_lane
	return if work.running > 0 && lanes > 3 { 3 } else { lanes }
}

// The last paths can run during trigger collection and raster-parent setup. The
// retained source scenes and both job ranges live through the finish call.
fn (work &ChromiumMSAAPathWork) submit_tail() voidptr {
	lanes := work.tail_lanes()
	if lanes < 1 || chromium_serial_msaa_path_tail || chromium_sync_msaa_paths {
		return unsafe { nil }
	}
	remaining := work.count - work.running
	jobs := unsafe { &work.jobs[work.running] }
	if lanes == 1 {
		return cpuraster.start_background_raster_range(jobs, i32(remaining), chromium_msaa_path_range)
	}
	ticket, _ := cpuraster.start_background_raster_ranges(jobs, remaining, lanes,
		chromium_msaa_path_range)
	return ticket
}

fn (mut work ChromiumMSAAPathWork) finish(mut triggers []ChromiumMSAATrigger, tail voidptr) {
	count := work.count
	if count == 0 { return }
	remaining := count - work.running
	mut used_lanes := 0
	if remaining > 0 && tail == unsafe { nil } {
		used_lanes = cpuraster.run_raster_ranges(unsafe { &work.jobs[work.running] }, remaining,
			work.tail_lanes(), chromium_msaa_path_range)
	}
	ready := cpuraster.join_background_raster_range(work.ticket)
	tail_ready := cpuraster.join_background_raster_range(tail)
	if chromium_msaa_tile_diagnostics {
		caller := platform.native_thread_identity()
		mut off_thread := 0
		for index in 0 .. count {
			if work.jobs[index].thread_id != caller { off_thread++ }
		}
		background_tail := if tail == unsafe { nil } { 0 } else { remaining }
		eprintln('VOX_MSAA_PATH_BATCH jobs=${count} tail_lanes=${used_lanes} background=${work.running} off_thread=${off_thread} ready_at_join=${ready} background_tail=${background_tail} tail_ready_at_join=${tail_ready}')
	}
	// Publish after the join. Merge in place so no placeholder or rejected
	// path can change the order of triggers produced by either thread.
	mut next := work.jobs[0].slot
	for index in 0 .. count {
		job := &work.jobs[index]
		triggers[job.slot] = job.trigger
	}
	for index in next .. triggers.len {
		trigger := triggers[index]
		if trigger.command_index < 0 { continue }
		triggers[next] = trigger
		next++
	}
	triggers.trim(next)
	work.count = 0
	work.running = 0
	work.ticket = unsafe { nil }
}
