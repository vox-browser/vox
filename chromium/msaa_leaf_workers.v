module main

import cpuraster
import layout
import os
import platform

const chromium_parallel_msaa_leaf_tail = os.getenv('VOX_PARALLEL_MSAA_LEAF_TAIL') == '1'
const chromium_parallel_msaa_leaves = os.getenv('VOX_PARALLEL_MSAA_LEAVES') == '1'
const chromium_msaa_min_leaf_tail = 96
const chromium_msaa_max_leaf_commands = 4096

struct ChromiumMSAALeafRange {
	start     int
	count     int
	checked   int
	thread_id u64
}

struct ChromiumMSAALeafWork {
mut:
	commands  []layout.PaintCommand
	results   []ChromiumMSAATrigger
	ranges    [4]ChromiumMSAALeafRange
	jobs      int
	lanes     int
	first     int
	ticket    voidptr
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
	count := work.commands.len - work.first
	thread_id := if chromium_msaa_tile_diagnostics { platform.native_thread_identity() } else { u64(0) }
	results := unsafe { &ChromiumMSAATrigger(work.results.data) }
	for job in int(first) .. int(end) {
		start := count * job / work.jobs
		stop := count * (job + 1) / work.jobs
		mut length := 0
		mut checked := 0
		for offset in start .. stop {
			index := work.first + offset
			command := unsafe { &work.commands[index] }
			if work.jobs > 1 && !chromium_msaa_worker_leaf(command) { continue }
			if chromium_msaa_tile_diagnostics { checked++ }
			if chromium_msaa_has_empty_clip(command) { continue }
			rect := chromium_msaa_trigger_rect(command) or { continue }
			unsafe {
				results[start + length] = ChromiumMSAATrigger{
					index, rect.y, rect.y + rect.height, rect.x, rect.x + rect.width
				}
			}
			length++
		}
		work.ranges[job] = ChromiumMSAALeafRange{start, length, checked, thread_id}
	}
}

// With one job the suffix is already known to contain only ordinary leaves.
// With multiple jobs each worker selects ordinary leaves within its own range.
fn (mut work ChromiumMSAALeafWork) start(commands []layout.PaintCommand, first int, jobs int) bool {
	count := commands.len - first
	if work.results.len < count {
		work.results = []ChromiumMSAATrigger{len: count}
	}
	work.commands = commands
	work.first = first
	work.jobs = jobs
	if jobs == 1 {
		work.ticket = cpuraster.start_background_raster_range(work, 1, chromium_msaa_leaf_range)
		work.lanes = 1
	} else {
		work.ticket, work.lanes = cpuraster.start_background_raster_ranges(work, jobs, jobs,
			chromium_msaa_leaf_range)
	}
	if work.ticket != unsafe { nil } { return true }
	work.commands = []
	return false
}

fn (mut work ChromiumMSAALeafWork) submit_tail(commands []layout.PaintCommand, first int) int {
	count := commands.len - first
	if count >= chromium_msaa_min_leaf_tail && count <= chromium_msaa_path_overlap_commands
		&& work.start(commands, first, 1) { return first }
	return commands.len
}

fn (mut work ChromiumMSAALeafWork) submit_all(commands []layout.PaintCommand) bool {
	if commands.len < 2 * chromium_msaa_min_leaf_tail || commands.len > chromium_msaa_max_leaf_commands {
		return false
	}
	jobs := commands.len / chromium_msaa_min_leaf_tail
	return work.start(commands, 0, if jobs > 4 { 4 } else { jobs })
}

// Each job compacted its triggers into the start of its own range. Merge
// those sorted runs backwards into the caller's ordered trigger list.
fn (work &ChromiumMSAALeafWork) merge(mut triggers []ChromiumMSAATrigger, count int) {
	if count == 0 { return }
	mut unread := triggers.len
	unsafe { triggers.grow_len(count) }
	mut next := triggers.len
	for job := work.jobs - 1; job >= 0; job-- {
		range := work.ranges[job]
		for index := range.start + range.count - 1; index >= range.start; index-- {
			result := work.results[index]
			for unread > 0 && triggers[unread - 1].command_index > result.command_index {
				unread--
				next--
				triggers[next] = triggers[unread]
			}
			next--
			triggers[next] = result
		}
	}
}

fn (mut work ChromiumMSAALeafWork) finish(mut triggers []ChromiumMSAATrigger) {
	if work.ticket == unsafe { nil } { return }
	ready := cpuraster.join_background_raster_range(work.ticket)
	mut count := 0
	for job in 0 .. work.jobs { count += work.ranges[job].count }
	work.merge(mut triggers, count)
	if chromium_msaa_tile_diagnostics {
		caller := platform.native_thread_identity()
		if work.jobs == 1 {
			off_thread := work.ranges[0].thread_id != caller
			eprintln('VOX_MSAA_LEAF_BATCH commands=${work.commands.len - work.first} triggers=${count} off_thread=${off_thread} ready_at_join=${ready}')
		} else {
			mut checked := 0
			mut off_thread := 0
			for job in 0 .. work.jobs {
				range := work.ranges[job]
				checked += range.checked
				if range.thread_id != caller { off_thread += range.checked }
			}
			eprintln('VOX_MSAA_ALL_LEAVES commands=${work.commands.len} checked=${checked} triggers=${count} lanes=${work.lanes} off_thread=${off_thread} ready_at_join=${ready}')
		}
	}
	work.ticket = unsafe { nil }
	work.commands = []
}
