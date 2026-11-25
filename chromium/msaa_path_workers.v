module main

import cpuraster
import layout
import os
import painting
import platform

const chromium_serial_msaa_paths = os.getenv('VOX_SERIAL_MSAA_PATHS') == '1'
const chromium_msaa_paths_per_lane = 16
const chromium_msaa_max_path_jobs = 256

struct ChromiumMSAAPathJob {
	transform [6]f64
	origin    painting.IntPoint
	viewport  layout.LayoutRect
	slot      int
mut:
	path      &layout.PaintCommand = unsafe { nil }
	thread_id u64
}

struct ChromiumMSAAPathBatch {
	record_threads bool
	jobs           &ChromiumMSAAPathJob
	triggers       &ChromiumMSAATrigger
}

fn chromium_msaa_path_range(context voidptr, first i32, end i32) {
	batch := unsafe { &ChromiumMSAAPathBatch(context) }
	thread_id := if batch.record_threads { platform.native_thread_identity() } else { u64(0) }
	for index in int(first) .. int(end) {
		unsafe {
			mut job := &batch.jobs[index]
			command_index := batch.triggers[job.slot].command_index
			batch.triggers[job.slot] = chromium_svg_background_path_trigger(job.path,
				job.transform, job.origin, job.viewport, command_index) or {
				ChromiumMSAATrigger{command_index: -1}
			}
			job.path = nil
			job.thread_id = thread_id
		}
	}
}

fn (mut storage ChromiumMSAAStorage) collect_triggers(commands []layout.PaintCommand,
	viewport ?ChromiumMSAAViewport, batch_paths bool) {
	storage.triggers.clear()
	if !batch_paths || commands.len < 2 * chromium_msaa_paths_per_lane {
		append_chromium_msaa_triggers(commands, viewport, mut storage.triggers)
		return
	}
	for index in 0 .. commands.len {
		append_chromium_msaa_trigger(unsafe { &commands[index] }, index, viewport, true,
			mut storage.path_jobs, mut storage.triggers)
	}
	finish_chromium_msaa_path_jobs(mut storage.path_jobs, mut storage.triggers)
}

fn finish_chromium_msaa_path_jobs(mut jobs []ChromiumMSAAPathJob, mut triggers []ChromiumMSAATrigger) {
	count := jobs.len
	if count == 0 { return }
	first_slot := jobs[0].slot
	lanes := count / chromium_msaa_paths_per_lane
	batch := ChromiumMSAAPathBatch{
		record_threads: chromium_msaa_tile_diagnostics
		jobs: unsafe { &ChromiumMSAAPathJob(jobs.data) }
		triggers: unsafe { &ChromiumMSAATrigger(triggers.data) }
	}
	used_lanes := cpuraster.run_raster_ranges(&batch, count, lanes, chromium_msaa_path_range)
	if chromium_msaa_tile_diagnostics {
		caller := platform.native_thread_identity()
		mut off_thread := 0
		for job in jobs {
			if job.thread_id != caller { off_thread++ }
		}
		eprintln('VOX_MSAA_PATH_BATCH jobs=${count} lanes=${used_lanes} off_thread=${off_thread}')
	}
	// Remove rejected placeholders in place, preserving paint and tile order.
	mut next := first_slot
	for index in first_slot .. triggers.len {
		trigger := triggers[index]
		if trigger.command_index < 0 { continue }
		triggers[next] = trigger
		next++
	}
	triggers.trim(next)
	jobs.clear()
}
