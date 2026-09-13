// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// PageClient's retained model of remote child frames. This is the V side of
// the browser-process topology and compositor-context lookup boundary.
module page

import compositor

pub struct NavigationPopulationFailure {
pub:
	operation_id  u64
	navigation_id string
}

pub struct ChildFrameState {
pub:
	parent_id        u64
	frame_id         u64
	replicated_state string
pub mut:
	viewport              PixelRect
	compositor_context_id ?compositor.CompositorContextId
	crashed               bool
}

pub fn (mut client PageClient) navigation_population_failed(operation_id u64, navigation_id string) {
	client.navigation_population_failures_ << NavigationPopulationFailure{
		operation_id: operation_id
		navigation_id: navigation_id
	}
	client.record('navigation-population-failed', '${operation_id}:${navigation_id}')
}

pub fn (client &PageClient) navigation_population_failures() []NavigationPopulationFailure {
	return client.navigation_population_failures_.clone()
}

pub fn (mut client PageClient) page_did_create_child_frame(parent_id u64, frame_id u64, replicated_state string) {
	client.child_frames_[frame_id] = ChildFrameState{
		parent_id: parent_id
		frame_id: frame_id
		replicated_state: replicated_state
	}
	client.record('create-child-frame', '${parent_id}:${frame_id}:${replicated_state}')
}

pub fn (mut client PageClient) page_did_update_child_frame_viewport(frame_id u64, viewport PixelRect) {
	mut frame := client.child_frames_[frame_id] or { return }
	frame.viewport = viewport
	client.child_frames_[frame_id] = frame
	client.record('update-child-frame-viewport', '${frame_id}:${viewport.x},${viewport.y},${viewport.width},${viewport.height}')
}

pub fn (mut client PageClient) set_remote_child_frame_compositor_context_id(frame_id u64, context_id ?compositor.CompositorContextId) {
	mut frame := client.child_frames_[frame_id] or { return }
	frame.compositor_context_id = context_id
	client.child_frames_[frame_id] = frame
}

pub fn (client &PageClient) compositor_context_id_for_remote_child_frame(frame_id u64) ?compositor.CompositorContextId {
	frame := client.child_frames_[frame_id] or { return none }
	return frame.compositor_context_id
}

pub fn (client &PageClient) child_frame(frame_id u64) ?ChildFrameState {
	frame := client.child_frames_[frame_id] or { return none }
	return frame
}

pub fn (mut client PageClient) page_did_destroy_child_frame(frame_id u64) {
	if frame_id !in client.child_frames_ {
		return
	}
	client.child_frames_.delete(frame_id)
	client.record('destroy-child-frame', frame_id.str())
}

pub fn (mut client PageClient) crash_remote_frame_processes_for_testing() {
	for frame_id in client.child_frames_.keys() {
		mut frame := client.child_frames_[frame_id]
		frame.crashed = true
		client.child_frames_[frame_id] = frame
	}
	client.record('crash-remote-frame-processes', client.child_frames_.len.str())
}

pub fn (client &PageClient) dump_site_isolation_process_tree_for_testing() string {
	mut frame_ids := client.child_frames_.keys()
	frame_ids.sort()
	mut lines := []string{}
	for frame_id in frame_ids {
		frame := client.child_frames_[frame_id]
		context := if context_id := frame.compositor_context_id { context_id.str() } else { '-' }
		lines << '${frame.parent_id}->${frame.frame_id} context=${context} crashed=${frame.crashed} ${frame.replicated_state}'
	}
	return lines.join('\n')
}
