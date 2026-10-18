// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// PageClient defaults and the deterministic V embedder state used for input,
// identity allocation, and rendering-opportunity coordination.
module page

import compositor
import math

pub fn (client &PageClient) id() u64 {
	return client.id_
}

pub fn (client &PageClient) is_connection_open() bool {
	return client.connection_open_
}

pub fn (client &PageClient) has_focus() bool {
	return client.has_focus_
}

pub fn (mut client PageClient) set_has_focus(has_focus bool) {
	client.has_focus_ = has_focus
}

pub fn (client &PageClient) has_active_devtools_client() bool {
	return client.active_devtools_client_
}

pub fn (client &PageClient) maximum_frames_per_second() f64 {
	return client.maximum_frames_per_second_
}

pub fn (mut client PageClient) set_maximum_frames_per_second(value f64) {
	if value <= 0 || math.is_nan(value) || math.is_inf(value, 0) {
		return
	}
	client.maximum_frames_per_second_ = value
}

pub fn (mut client PageClient) did_handle_input_event(page_id u64, event InputEvent) {
	if !client.record_events_ {
		return
	}
	kind := match event {
		DragEvent { 'drag:${event.type_}' }
		KeyEvent { 'key:${event.type_}' }
		MouseEvent { 'mouse:${event.type_}' }
		PinchEvent { 'pinch' }
	}
	client.record('did-handle-input-event', '${page_id}:${kind}')
}

pub fn (client &PageClient) allocate_compositor_context_id(registration compositor.PagePresentationRegistration) !compositor.CompositorContextId {
	if registration != .yes {
		return error('a PageClient compositor context requires page presentation registration')
	}
	return compositor.compositor_context_id_for_page(client.id_)
}

pub fn (mut client PageClient) allocate_cross_process_id() u64 {
	id := client.next_cross_process_id_
	client.next_cross_process_id_++
	return id
}

pub fn (mut client PageClient) set_pending_root_navigable_id(id ?u64) {
	client.pending_root_navigable_id_ = id
}

pub fn (mut client PageClient) allocate_navigable_id() u64 {
	if id := client.pending_root_navigable_id_ {
		client.pending_root_navigable_id_ = none
		return id
	}
	return client.allocate_cross_process_id()
}

pub fn (mut client PageClient) rendering_opportunity(frame_time_nanoseconds i64, frame_interval_milliseconds f64) {
	client.last_rendering_frame_time_ns_ = frame_time_nanoseconds
	client.last_rendering_frame_interval_ms_ = frame_interval_milliseconds
	client.rendering_opportunity_granted_ = true
	if client.record_events_ {
		client.record('rendering-opportunity', '${frame_time_nanoseconds}:${frame_interval_milliseconds}')
	}
}

pub fn (mut client PageClient) will_begin_rendering_update() {
	client.rendering_opportunity_for_update_ = client.rendering_opportunity_granted_
	client.rendering_opportunity_granted_ = false
	client.rendering_update_requested_ = false
	client.record('will-begin-rendering-update', '')
}

pub fn (client &PageClient) has_rendering_opportunity() bool {
	return client.rendering_opportunity_granted_ || client.rendering_opportunity_for_update_
}

pub fn (mut client PageClient) did_finish_rendering_update() {
	client.rendering_opportunity_for_update_ = false
	client.record('did-finish-rendering-update', '')
}

pub fn (mut client PageClient) set_manual_rendering_opportunities(enabled bool) {
	if client.manual_rendering_opportunities_ == enabled {
		return
	}
	client.manual_rendering_opportunities_ = enabled
	if enabled {
		if client.rendering_opportunity_granted_ {
			client.rendering_update_requested_ = true
		}
		client.rendering_opportunity_granted_ = false
	}
	client.record('manual-rendering-opportunities', enabled.str())
}

pub fn (mut client PageClient) inject_rendering_opportunity(frame_time_milliseconds f64) {
	if !client.manual_rendering_opportunities_ || !client.rendering_update_requested_
		|| client.rendering_opportunity_granted_ {
		return
	}
	client.rendering_opportunity(i64(frame_time_milliseconds * 1_000_000),
		1000.0 / client.maximum_frames_per_second_)
}

pub fn (client &PageClient) last_rendering_frame_time_nanoseconds() i64 {
	return client.last_rendering_frame_time_ns_
}

pub fn (client &PageClient) last_rendering_frame_interval_milliseconds() f64 {
	return client.last_rendering_frame_interval_ms_
}
