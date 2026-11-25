module layout

import cpuraster
import math
import os
import platform

const serial_display_list_replay = os.getenv('VOX_SERIAL_DISPLAY_LIST_REPLAY') == '1'
const display_list_replay_worker_diagnostics = os.getenv('VOX_DISPLAY_LIST_REPLAY_WORKER_DIAGNOSTICS') == '1'
const display_list_replay_leaves_per_lane = 64

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
		if thread_id != 0 { unsafe { work.threads[index] = thread_id } }
	}
}

fn materialize_cached_visual_leaves(plan []CompatibilityCachedVisualReplayStep,
	contexts []CompatibilityFlattenedVisualContext, mut output []PaintCommand, deferred int) {
	mut threads := []u64{}
	if display_list_replay_worker_diagnostics {
		threads = []u64{len: plan.len}
	}
	work := CachedVisualLeafWork{
		plan: plan
		contexts: contexts
		output: unsafe { &PaintCommand(output.data) }
		threads: unsafe { if threads.len > 0 { &u64(threads.data) } else { &u64(nil) } }
	}
	requested_lanes := math.min(4, deferred / display_list_replay_leaves_per_lane)
	lanes := cpuraster.run_raster_ranges_with_caller(&work, plan.len, requested_lanes,
		materialize_cached_visual_leaf_range)
	if lanes == 0 {
		materialize_cached_visual_leaf_range(&work, 0, i32(plan.len))
	}
	if display_list_replay_worker_diagnostics {
		caller := platform.native_thread_identity()
		off_thread := threads.count(it != 0 && it != caller)
		eprintln('VOX_DISPLAY_LIST_LEAF_BATCH commands=${output.len} leaves=${deferred} lanes=${lanes} off_thread=${off_thread}')
	}
}
