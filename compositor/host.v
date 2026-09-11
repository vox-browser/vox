// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Compositor/CompositorHost.{h,cpp}. This recording host is the
// typed V side of the native compositor boundary; a platform adapter consumes
// the recorded calls and supplies async-scroll results.
module compositor

import painting

pub type VideoSinkHandle = u64

pub struct DisplayListResourceTransaction {
pub:
	commands []string
}

pub struct PaintingSurface {
pub:
	id u64
}

pub struct Canvas2DCommandStream {
mut:
	segments_ []string
}

pub fn (mut stream Canvas2DCommandStream) append(command string) {
	stream.segments_ << command
}

pub fn (stream Canvas2DCommandStream) is_empty() bool {
	return stream.segments_.len == 0
}

pub fn (mut stream Canvas2DCommandStream) take_segments() []string {
	segments := stream.segments_.clone()
	stream.segments_.clear()
	return segments
}

pub struct CompositorDisplayListUpdate {
pub:
	context_id           CompositorContextId
	display_list         CompositorDisplayList
	visual_context_tree  VisualContextTree
	resource_transaction DisplayListResourceTransaction
	scroll_state         CompositorScrollStateSnapshot
}

pub struct CompositorVisualContextUpdate {
pub:
	context_id           CompositorContextId
	visual_context_tree  VisualContextTree
	resource_transaction DisplayListResourceTransaction
}

pub struct CompositorViewportUpdate {
pub:
	context_id           CompositorContextId
	size                 painting.IntSize
	resizing_in_progress WindowResizingInProgress
}

@[heap]
pub struct CompositorHost {
mut:
	canvas_2d_stream_             Canvas2DCommandStream
	canvas_2d_batches_            [][]string
	call_log_                     []string
	context_ids_                  map[CompositorContextId]bool
	parent_contexts_              map[CompositorContextId]CompositorContextId
	hidden_contexts_              map[CompositorContextId]bool
	display_list_updates_         []CompositorDisplayListUpdate
	visual_context_updates_       []CompositorVisualContextUpdate
	video_sinks_                  map[VideoSinkHandle]bool
	scroll_states_                map[CompositorContextId]CompositorScrollStateSnapshot
	wheel_listener_generations_   map[CompositorContextId]u64
	next_async_scroll_result_     AsyncScrollEnqueueResult
	next_smooth_scroll_result_    AsyncScrollEnqueueResult
	pending_scroll_updates_       map[CompositorContextId]PendingAsyncScrollUpdates
	viewport_updates_             []CompositorViewportUpdate
	rendering_opportunity_result_ bool
	hurry_count_                  map[CompositorContextId]int
	presented_viewports_          map[CompositorContextId]painting.IntRect
	screenshot_requests_          []ScreenshotRequestId
	next_screenshot_request_id_   ScreenshotRequestId = 1
	next_transport_id_            u64 = 1
}

pub fn new_compositor_host() &CompositorHost {
	mut host := &CompositorHost{}
	// CompositorHost's C++ constructor eagerly creates the reusable stream.
	host.canvas_2d_stream_ = Canvas2DCommandStream{
		segments_: []string{}
	}
	return host
}

pub fn (mut host CompositorHost) create_context(context_id CompositorContextId) !&CompositorContextHandle {
	if context_id == 0 {
		return error('compositor context ID must be non-zero')
	}
	if host.context_ids_[context_id] {
		return error('compositor context already exists')
	}
	host.context_ids_[context_id] = true
	host.call_log_ << 'create_context:${context_id}'
	return &CompositorContextHandle{
		host_: host
		context_id_: context_id
	}
}

pub fn (mut host CompositorHost) canvas_2d_stream() &Canvas2DCommandStream {
	return &host.canvas_2d_stream_
}

pub fn (mut host CompositorHost) append_canvas_2d_command(command string) {
	host.canvas_2d_stream_.append(command)
}

pub fn (mut host CompositorHost) send_canvas_2d_stream() {
	segments := host.canvas_2d_stream_.take_segments()
	if segments.len == 0 {
		return
	}
	host.canvas_2d_batches_ << segments
	host.call_log_ << 'canvas_2d_stream'
}

pub fn (mut host CompositorHost) flush_canvas_2d_stream() {
	if host.canvas_2d_stream_.is_empty() {
		return
	}
	host.send_canvas_2d_stream()
}

pub fn (mut host CompositorHost) discard_canvas_2d_stream() {
	host.canvas_2d_stream_.take_segments()
}

pub fn (mut host CompositorHost) create_webgl_transport() u64 {
	id := host.next_transport_id_
	host.next_transport_id_++
	return id
}

pub fn (mut host CompositorHost) create_canvas_2d_transport() u64 {
	id := host.next_transport_id_
	host.next_transport_id_++
	return id
}

pub fn (mut host CompositorHost) destroy_context(context_id CompositorContextId) {
	host.context_ids_.delete(context_id)
	host.parent_contexts_.delete(context_id)
	host.hidden_contexts_.delete(context_id)
	host.scroll_states_.delete(context_id)
	host.wheel_listener_generations_.delete(context_id)
	host.pending_scroll_updates_.delete(context_id)
	host.call_log_ << 'destroy_context:${context_id}'
}

pub fn (mut host CompositorHost) set_parent_context(context_id CompositorContextId, parent_context_id ?CompositorContextId) {
	if parent := parent_context_id {
		host.parent_contexts_[context_id] = parent
	} else {
		host.parent_contexts_.delete(context_id)
	}
	host.call_log_ << 'set_parent_context:${context_id}'
}

pub fn (mut host CompositorHost) stop_presenting_to_client(context_id CompositorContextId) {
	host.hidden_contexts_[context_id] = true
	host.call_log_ << 'stop_presenting_to_client:${context_id}'
}

pub fn (mut host CompositorHost) update_display_list(context_id CompositorContextId, display_list CompositorDisplayList, visual_context_tree VisualContextTree, resource_transaction DisplayListResourceTransaction, scroll_state CompositorScrollStateSnapshot) {
	host.display_list_updates_ << CompositorDisplayListUpdate{
		context_id: context_id
		display_list: display_list
		visual_context_tree: visual_context_tree
		resource_transaction: resource_transaction
		scroll_state: scroll_state
	}
	host.call_log_ << 'update_display_list:${context_id}'
}

pub fn (mut host CompositorHost) update_visual_context_tree(context_id CompositorContextId, visual_context_tree VisualContextTree, resource_transaction DisplayListResourceTransaction) {
	host.visual_context_updates_ << CompositorVisualContextUpdate{
		context_id: context_id
		visual_context_tree: visual_context_tree
		resource_transaction: resource_transaction
	}
	host.call_log_ << 'update_visual_context_tree:${context_id}'
}

pub fn (mut host CompositorHost) add_video_sink(video_sink VideoSinkHandle) {
	host.video_sinks_[video_sink] = true
	host.call_log_ << 'add_video_sink:${video_sink}'
}

pub fn (mut host CompositorHost) remove_video_sink(video_sink VideoSinkHandle) {
	host.video_sinks_.delete(video_sink)
	host.call_log_ << 'remove_video_sink:${video_sink}'
}

pub fn (mut host CompositorHost) set_video_sink_ticking(video_sink VideoSinkHandle, should_tick bool) {
	if video_sink in host.video_sinks_ {
		host.video_sinks_[video_sink] = should_tick
	}
	host.call_log_ << 'set_video_sink_ticking:${video_sink}:${should_tick}'
}

pub fn (mut host CompositorHost) update_scroll_state(context_id CompositorContextId, scroll_state CompositorScrollStateSnapshot) {
	host.scroll_states_[context_id] = scroll_state
	host.call_log_ << 'update_scroll_state:${context_id}'
}

pub fn (mut host CompositorHost) invalidate_wheel_event_listener_state(context_id CompositorContextId, generation u64) {
	host.wheel_listener_generations_[context_id] = generation
	host.call_log_ << 'invalidate_wheel_event_listener_state:${context_id}:${generation}'
}

pub fn (mut host CompositorHost) set_next_async_scroll_result(result AsyncScrollEnqueueResult) {
	host.next_async_scroll_result_ = result
}

pub fn (mut host CompositorHost) async_scroll_by(context_id CompositorContextId, expected_document_id u64, position painting.Point, delta_in_device_pixels painting.Point, viewport_rect painting.IntRect, snap_handling SnapContainerHandling, operation_tracking AsyncScrollOperationTracking) AsyncScrollEnqueueResult {
	_ = expected_document_id
	_ = position
	_ = delta_in_device_pixels
	_ = viewport_rect
	_ = snap_handling
	_ = operation_tracking
	host.call_log_ << 'async_scroll_by:${context_id}'
	return host.next_async_scroll_result_
}

pub fn (mut host CompositorHost) set_next_smooth_scroll_result(result AsyncScrollEnqueueResult) {
	host.next_smooth_scroll_result_ = result
}

pub fn (mut host CompositorHost) smooth_scroll_to(context_id CompositorContextId, stable_node_id AsyncScrollNodeStableId, offset_in_device_pixels painting.Point, main_thread_offset_in_device_pixels painting.Point, viewport_rect painting.IntRect, device_pixels_per_css_pixel f64, animation_kind ScrollAnimationKind) AsyncScrollEnqueueResult {
	_ = stable_node_id
	_ = offset_in_device_pixels
	_ = main_thread_offset_in_device_pixels
	_ = viewport_rect
	_ = device_pixels_per_css_pixel
	_ = animation_kind
	host.call_log_ << 'smooth_scroll_to:${context_id}'
	return host.next_smooth_scroll_result_
}

pub fn (mut host CompositorHost) cancel_smooth_scroll(context_id CompositorContextId, stable_node_id AsyncScrollNodeStableId) {
	_ = stable_node_id
	host.call_log_ << 'cancel_smooth_scroll:${context_id}'
}

pub fn (mut host CompositorHost) set_pending_async_scroll_updates(context_id CompositorContextId, updates PendingAsyncScrollUpdates) {
	host.pending_scroll_updates_[context_id] = updates
}

pub fn (mut host CompositorHost) take_pending_async_scroll_updates(context_id CompositorContextId, freshness AsyncScrollUpdateFreshness) PendingAsyncScrollUpdates {
	_ = freshness
	updates := host.pending_scroll_updates_[context_id]
	host.pending_scroll_updates_.delete(context_id)
	host.call_log_ << 'take_pending_async_scroll_updates:${context_id}'
	return updates
}

pub fn (mut host CompositorHost) viewport_size_updated(context_id CompositorContextId, size painting.IntSize, resizing_in_progress WindowResizingInProgress) {
	host.viewport_updates_ << CompositorViewportUpdate{context_id, size, resizing_in_progress}
	host.call_log_ << 'viewport_size_updated:${context_id}'
}

pub fn (mut host CompositorHost) set_rendering_opportunity_result(result bool) {
	host.rendering_opportunity_result_ = result
}

pub fn (mut host CompositorHost) request_rendering_opportunity(context_id CompositorContextId, maximum_frames_per_second f64) bool {
	_ = maximum_frames_per_second
	host.call_log_ << 'request_rendering_opportunity:${context_id}'
	return host.rendering_opportunity_result_
}

pub fn (mut host CompositorHost) hurry_rendering_opportunity(context_id CompositorContextId) {
	host.hurry_count_[context_id]++
	host.call_log_ << 'hurry_rendering_opportunity:${context_id}'
}

pub fn (mut host CompositorHost) present_frame(context_id CompositorContextId, viewport_rect painting.IntRect) {
	host.presented_viewports_[context_id] = viewport_rect
	host.call_log_ << 'present_frame:${context_id}'
}

pub fn (mut host CompositorHost) request_screenshot(context_id CompositorContextId, target_surface PaintingSurface, callback fn ()) {
	_ = target_surface
	request_id := host.next_screenshot_request_id_
	host.next_screenshot_request_id_++
	host.screenshot_requests_ << request_id
	host.call_log_ << 'request_screenshot:${context_id}'
	callback()
}

pub fn (host CompositorHost) call_log() []string {
	return host.call_log_.clone()
}

pub fn (host CompositorHost) canvas_2d_batches() [][]string {
	return host.canvas_2d_batches_.clone()
}

pub fn (host CompositorHost) has_context(context_id CompositorContextId) bool {
	return host.context_ids_[context_id]
}

pub fn (host CompositorHost) display_list_updates() []CompositorDisplayListUpdate {
	return host.display_list_updates_.clone()
}

@[heap]
pub struct CompositorContextHandle {
	host_       &CompositorHost
	context_id_ CompositorContextId
mut:
	destroyed_ bool
}

pub fn (handle CompositorContextHandle) id() CompositorContextId {
	return handle.context_id_
}

fn (handle CompositorContextHandle) mutable_host() &CompositorHost {
	return handle.host_
}

pub fn (mut handle CompositorContextHandle) destroy() {
	if handle.destroyed_ {
		return
	}
	mut host := handle.mutable_host()
	host.destroy_context(handle.context_id_)
	handle.destroyed_ = true
}

pub fn (mut handle CompositorContextHandle) set_parent_context(parent_context_id ?CompositorContextId) {
	mut host := handle.mutable_host()
	host.set_parent_context(handle.context_id_, parent_context_id)
}

pub fn (mut handle CompositorContextHandle) stop_presenting_to_client() {
	mut host := handle.mutable_host()
	host.stop_presenting_to_client(handle.context_id_)
}

pub fn (mut handle CompositorContextHandle) update_display_list(display_list CompositorDisplayList, visual_context_tree VisualContextTree, resource_transaction DisplayListResourceTransaction, scroll_state CompositorScrollStateSnapshot) {
	mut host := handle.mutable_host()
	host.flush_canvas_2d_stream()
	host.update_display_list(handle.context_id_, display_list, visual_context_tree, resource_transaction, scroll_state)
}

pub fn (mut handle CompositorContextHandle) update_visual_context_tree(visual_context_tree VisualContextTree, resource_transaction DisplayListResourceTransaction) {
	mut host := handle.mutable_host()
	host.update_visual_context_tree(handle.context_id_, visual_context_tree, resource_transaction)
}

pub fn (mut handle CompositorContextHandle) add_video_sink(video_sink VideoSinkHandle) {
	mut host := handle.mutable_host()
	host.add_video_sink(video_sink)
}

pub fn (mut handle CompositorContextHandle) remove_video_sink(video_sink VideoSinkHandle) {
	mut host := handle.mutable_host()
	host.remove_video_sink(video_sink)
}

pub fn (mut handle CompositorContextHandle) set_video_sink_ticking(video_sink VideoSinkHandle, should_tick bool) {
	mut host := handle.mutable_host()
	host.set_video_sink_ticking(video_sink, should_tick)
}

pub fn (mut handle CompositorContextHandle) update_scroll_state(scroll_state CompositorScrollStateSnapshot) {
	mut host := handle.mutable_host()
	host.update_scroll_state(handle.context_id_, scroll_state)
}

pub fn (mut handle CompositorContextHandle) invalidate_wheel_event_listener_state(generation u64) {
	mut host := handle.mutable_host()
	host.invalidate_wheel_event_listener_state(handle.context_id_, generation)
}

pub fn (mut handle CompositorContextHandle) async_scroll_by(expected_document_id u64, position painting.Point, delta_in_device_pixels painting.Point, viewport_rect painting.IntRect, snap_handling SnapContainerHandling, operation_tracking AsyncScrollOperationTracking) AsyncScrollEnqueueResult {
	mut host := handle.mutable_host()
	return host.async_scroll_by(handle.context_id_, expected_document_id, position, delta_in_device_pixels, viewport_rect, snap_handling, operation_tracking)
}

pub fn (mut handle CompositorContextHandle) smooth_scroll_to(stable_node_id AsyncScrollNodeStableId, offset_in_device_pixels painting.Point, main_thread_offset_in_device_pixels painting.Point, viewport_rect painting.IntRect, device_pixels_per_css_pixel f64, animation_kind ScrollAnimationKind) AsyncScrollEnqueueResult {
	mut host := handle.mutable_host()
	return host.smooth_scroll_to(handle.context_id_, stable_node_id, offset_in_device_pixels, main_thread_offset_in_device_pixels, viewport_rect, device_pixels_per_css_pixel, animation_kind)
}

pub fn (mut handle CompositorContextHandle) cancel_smooth_scroll(stable_node_id AsyncScrollNodeStableId) {
	mut host := handle.mutable_host()
	host.cancel_smooth_scroll(handle.context_id_, stable_node_id)
}

pub fn (mut handle CompositorContextHandle) take_pending_async_scroll_updates(freshness AsyncScrollUpdateFreshness) PendingAsyncScrollUpdates {
	mut host := handle.mutable_host()
	return host.take_pending_async_scroll_updates(handle.context_id_, freshness)
}

pub fn (mut handle CompositorContextHandle) viewport_size_updated(size painting.IntSize, resizing_in_progress WindowResizingInProgress) {
	mut host := handle.mutable_host()
	host.viewport_size_updated(handle.context_id_, size, resizing_in_progress)
}

pub fn (mut handle CompositorContextHandle) request_rendering_opportunity(maximum_frames_per_second f64) bool {
	mut host := handle.mutable_host()
	return host.request_rendering_opportunity(handle.context_id_, maximum_frames_per_second)
}

pub fn (mut handle CompositorContextHandle) hurry_rendering_opportunity() {
	mut host := handle.mutable_host()
	host.hurry_rendering_opportunity(handle.context_id_)
}

pub fn (mut handle CompositorContextHandle) present_frame(viewport_rect painting.IntRect) {
	mut host := handle.mutable_host()
	host.flush_canvas_2d_stream()
	host.present_frame(handle.context_id_, viewport_rect)
}

pub fn (mut handle CompositorContextHandle) request_screenshot(target_surface PaintingSurface, callback fn ()) {
	mut host := handle.mutable_host()
	host.flush_canvas_2d_stream()
	host.request_screenshot(handle.context_id_, target_surface, callback)
}
