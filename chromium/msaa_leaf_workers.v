module main

import cpuraster
import layout
import os
import platform

const chromium_parallel_msaa_leaf_tail = os.getenv('VOX_PARALLEL_MSAA_LEAF_TAIL') == '1'
const chromium_msaa_min_leaf_tail = 96

struct ChromiumMSAALeafWork {
mut:
	commands  []layout.PaintCommand
	results   []ChromiumMSAATrigger
	first     int
	ticket    voidptr
	thread_id u64
}

// These kinds only inspect retained command geometry, including replaced
// images' clip radii. SVG backgrounds and nested viewport replay can prepare
// resources, and SVG borders can log diagnostics, so they use the caller.
fn chromium_msaa_worker_leaf(command &layout.PaintCommand) bool {
	return command.kind in ['draw_text', 'fill_rect', 'fill_rounded_rect',
		'stroke_rounded_rect', 'paint_uniform_border', 'draw_replaced_image']
}

fn chromium_msaa_leaf_range(context voidptr, first i32, end i32) {
	mut work := unsafe { &ChromiumMSAALeafWork(context) }
	if chromium_msaa_tile_diagnostics { work.thread_id = platform.native_thread_identity() }
	results := unsafe { &ChromiumMSAATrigger(work.results.data) }
	for offset in int(first) .. int(end) {
		index := work.first + offset
		command := unsafe { &work.commands[index] }
		mut result := ChromiumMSAATrigger{command_index: -1}
		if !chromium_msaa_has_empty_clip(command) {
			if rect := chromium_msaa_trigger_rect(command) {
				result = ChromiumMSAATrigger{index, rect.y, rect.y + rect.height, rect.x, rect.x + rect.width}
			}
		}
		unsafe { results[offset] = result }
	}
}

// A single worker fills a fixed suffix while the caller discovers SVG jobs.
// Return the original end whenever the suffix stays on the caller.
fn (mut work ChromiumMSAALeafWork) submit(commands []layout.PaintCommand, first int) int {
	count := commands.len - first
	if count < chromium_msaa_min_leaf_tail || count > chromium_msaa_path_overlap_commands {
		return commands.len
	}
	if work.results.len == 0 {
		work.results = []ChromiumMSAATrigger{len: chromium_msaa_path_overlap_commands}
	}
	work.commands = commands
	work.first = first
	work.ticket = cpuraster.start_background_raster_range(work, i32(count), chromium_msaa_leaf_range)
	if work.ticket != unsafe { nil } { return first }
	work.commands = []
	return commands.len
}

fn (mut work ChromiumMSAALeafWork) finish(mut triggers []ChromiumMSAATrigger) {
	if work.ticket == unsafe { nil } { return }
	ready := cpuraster.join_background_raster_range(work.ticket)
	count := work.commands.len - work.first
	before := triggers.len
	for offset in 0 .. count {
		trigger := work.results[offset]
		if trigger.command_index >= 0 { triggers << trigger }
	}
	if chromium_msaa_tile_diagnostics {
		off_thread := work.thread_id != platform.native_thread_identity()
		eprintln('VOX_MSAA_LEAF_BATCH commands=${count} triggers=${triggers.len - before} off_thread=${off_thread} ready_at_join=${ready}')
	}
	work.ticket = unsafe { nil }
	work.commands = []
}
