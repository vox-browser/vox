module layout

import cpuraster
import math
import os
import platform
import time

const serial_display_list_replay = os.getenv('VOX_SERIAL_DISPLAY_LIST_REPLAY') == '1'
const pipeline_display_list_replay = os.getenv('VOX_PIPELINE_DISPLAY_LIST_REPLAY') == '1'
const display_list_replay_worker_diagnostics = os.getenv('VOX_DISPLAY_LIST_REPLAY_WORKER_DIAGNOSTICS') == '1'
const display_list_replay_leaves_per_lane = 64
const display_list_replay_prefix_leaves = 2 * display_list_replay_leaves_per_lane

fn cached_visual_replay_can_defer_leaves(command_count int) bool {
	$if macos {
		return !serial_display_list_replay && command_count >= 2 * display_list_replay_leaves_per_lane
	}
	return false
}

fn (step &CompatibilityCachedVisualReplayStep) can_project_on_worker() bool {
	source := step.command
	// Local clips and masks allocate scene payloads, and canvas/scroll
	// commands can observe live document state. Local image and border
	// geometry uses the retained transform tree on the owner.
	return step.layer_list == unsafe { nil } && step.box.overlay == none
		&& source.recording_clip == none && source.canvas_paintable == none
		&& source.local_image_data == unsafe { nil } && source.local_border_data == unsafe { nil }
}

fn apply_cached_visual_leaf_state(mut command PaintCommand, box &BlockBox, opacity_scale f64,
	context &CompatibilityFlattenedVisualContext, transform [6]f64) {
	command.transform = transform
	command.fixed_to_viewport = box.fixed_to_viewport
	command.group_opacity = context.group_opacity
	if opacity_scale != 1.0 {
		command.opacity *= opacity_scale
	}
	command.visual_layer_list = unsafe { nil }
}

fn apply_cached_visual_context_clip(mut command PaintCommand, context &CompatibilityFlattenedVisualContext) {
	command.has_clip = context.has_clip
	command.clip_list = context.clip_list
	if context.has_clip {
		command.clip_x = context.clip.x
		command.clip_y = context.clip.y
		command.clip_width = context.clip.width
		command.clip_height = context.clip.height
	}
}

struct CachedVisualLeafWork {
	plan     []CompatibilityCachedVisualReplayStep
	contexts []CompatibilityFlattenedVisualContext
	output   &PaintCommand
	threads  &u64
	raster_bounds &RecordedRasterBound = unsafe { nil }
}

@[heap]
struct CachedVisualLeafPrefix {
	work    CachedVisualLeafWork
	threads []u64
mut:
	ticket       voidptr
	completed_ns u64
}

// Each plan entry writes only its preassigned destination. Input commands
// and context lists are retained by the caller until every range has joined.
fn materialize_cached_visual_leaf_range(context voidptr, first i32, end i32) {
	work := unsafe { &CachedVisualLeafWork(context) }
	thread_id := if work.threads != unsafe { nil } { platform.native_thread_identity() } else { u64(0) }
	for index in int(first) .. int(end) {
		step := unsafe { &work.plan[index] }
		if step.output_index < 0 { continue }
		mut command := unsafe { &work.output[step.output_index] }
		state := unsafe { &work.contexts[step.context_slot] }
		unsafe { *command = *step.command }
		apply_cached_visual_leaf_state(mut command, step.box, step.opacity_scale, state, state.transform)
		apply_cached_visual_context_clip(mut command, state)
		if work.raster_bounds != unsafe { nil } && command.visual_layer_data == none
			&& !chromium_raster_chunk_has_empty_clip(command) {
			unsafe {
				work.raster_bounds[step.output_index] = RecordedRasterBound{
					extent: chromium_raster_chunk_extent(step.box, command, step.box.paint_transform)
					ready: true
				}
			}
		}
		if thread_id != 0 { unsafe { work.threads[index] = thread_id } }
	}
}

fn materialize_cached_visual_leaf_prefix(context voidptr, first i32, end i32) {
	mut prefix := unsafe { &CachedVisualLeafPrefix(context) }
	materialize_cached_visual_leaf_range(&prefix.work, first, end)
	if display_list_replay_worker_diagnostics {
		prefix.completed_ns = time.sys_mono_now()
	}
}

fn submit_cached_visual_leaf_prefix(plan []CompatibilityCachedVisualReplayStep,
	contexts []CompatibilityFlattenedVisualContext, output []PaintCommand,
	bounds &RecordedRasterBounds) &CachedVisualLeafPrefix {
	// The prefix already has output indices. The caller writes only later
	// plan entries and output slots, all in buffers reserved before dispatch.
	mut threads := []u64{}
	if display_list_replay_worker_diagnostics { threads = []u64{len: plan.len} }
	mut prefix := &CachedVisualLeafPrefix{
		work: CachedVisualLeafWork{
			plan: plan
			contexts: contexts
			output: unsafe { &PaintCommand(output.data) }
			threads: unsafe { if threads.len > 0 { &u64(threads.data) } else { &u64(nil) } }
			raster_bounds: bounds.slot_data()
		}
		threads: threads
	}
	prefix.ticket = cpuraster.start_background_raster_range(prefix, i32(plan.len),
		materialize_cached_visual_leaf_prefix)
	if prefix.ticket == unsafe { nil } { return unsafe { nil } }
	return prefix
}

@[params]
struct CachedVisualLeafProjectionOptions {
	prefix &CachedVisualLeafPrefix = unsafe { nil }
	bounds RecordedRasterBounds
}

fn materialize_cached_visual_leaves(plan []CompatibilityCachedVisualReplayStep,
	contexts []CompatibilityFlattenedVisualContext, mut output []PaintCommand, deferred int,
	options CachedVisualLeafProjectionOptions) {
	prefix := options.prefix
	background := prefix != unsafe { nil }
	reservation_end := if background && display_list_replay_worker_diagnostics {
		time.sys_mono_now()
	} else { u64(0) }
	first := if background { prefix.work.plan.len } else { 0 }
	tail := unsafe { plan[first..] }
	mut threads := []u64{}
	if display_list_replay_worker_diagnostics {
		threads = []u64{len: tail.len}
	}
	work := CachedVisualLeafWork{
		plan: tail
		contexts: contexts
		output: unsafe { &PaintCommand(output.data) }
		threads: unsafe { if threads.len > 0 { &u64(threads.data) } else { &u64(nil) } }
		raster_bounds: options.bounds.slot_data()
	}
	prefix_lanes := int(background)
	prefix_leaves := prefix_lanes * display_list_replay_prefix_leaves
	requested_lanes := math.min(4 - prefix_lanes,
		(deferred - prefix_leaves) / display_list_replay_leaves_per_lane)
	lanes := cpuraster.run_raster_ranges_with_caller(&work, tail.len, requested_lanes,
		materialize_cached_visual_leaf_range)
	if lanes == 0 {
		materialize_cached_visual_leaf_range(&work, 0, i32(tail.len))
	}
	prefix_ready := if background { cpuraster.join_background_raster_range(prefix.ticket) } else { false }
	if display_list_replay_worker_diagnostics {
		caller := platform.native_thread_identity()
		prefix_workers := if background { prefix.threads.count(it != 0 && it != caller) } else { 0 }
		off_thread := prefix_workers + threads.count(it != 0 && it != caller)
		completed_during_reservation := background && prefix.completed_ns <= reservation_end
		eprintln('VOX_DISPLAY_LIST_LEAF_BATCH commands=${output.len} leaves=${deferred} lanes=${lanes + prefix_lanes} off_thread=${off_thread} early_leaves=${prefix_workers} early_ready_after_reservation=${completed_during_reservation} early_ready_at_join=${prefix_ready}')
	}
}
