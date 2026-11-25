module main

import cpuraster
import layout
import os
import painting
import platform

const chromium_serial_msaa_paths = os.getenv('VOX_SERIAL_MSAA_PATHS') == '1'
const chromium_sync_msaa_paths = os.getenv('VOX_SYNC_MSAA_PATHS') == '1'
const chromium_msaa_paths_per_lane = 16
const chromium_msaa_background_paths = 2 * chromium_msaa_paths_per_lane
const chromium_msaa_max_path_jobs = 256

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
	if work.count == chromium_msaa_max_path_jobs { work.finish(mut triggers) }
}

fn (mut storage ChromiumMSAAStorage) collect_triggers(commands []layout.PaintCommand,
	viewport ?ChromiumMSAAViewport, batch_paths bool) {
	storage.triggers.clear()
	if !batch_paths || commands.len < chromium_msaa_background_paths {
		append_chromium_msaa_triggers(commands, viewport, mut storage.triggers)
		return
	}
	for index in 0 .. commands.len {
		append_chromium_msaa_trigger(unsafe { &commands[index] }, index, viewport, true,
			mut storage.path_work, mut storage.triggers)
	}
	storage.path_work.finish(mut storage.triggers)
}

fn (mut work ChromiumMSAAPathWork) finish(mut triggers []ChromiumMSAATrigger) {
	count := work.count
	if count == 0 { return }
	remaining := count - work.running
	mut lanes := remaining / chromium_msaa_paths_per_lane
	if work.running > 0 && lanes > 3 { lanes = 3 }
	mut used_lanes := 0
	if remaining > 0 {
		used_lanes = cpuraster.run_raster_ranges(unsafe { &work.jobs[work.running] }, remaining,
			lanes, chromium_msaa_path_range)
	}
	ready := cpuraster.join_background_raster_range(work.ticket)
	if chromium_msaa_tile_diagnostics {
		caller := platform.native_thread_identity()
		mut off_thread := 0
		for index in 0 .. count {
			if work.jobs[index].thread_id != caller { off_thread++ }
		}
		eprintln('VOX_MSAA_PATH_BATCH jobs=${count} tail_lanes=${used_lanes} background=${work.running} off_thread=${off_thread} ready_at_join=${ready}')
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
