// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Geolocation/Geolocation.{h,cpp,idl}. Document lifecycle,
// permissions, visibility, the clock and device acquisition enter through the
// explicit GeolocationHost state/callback boundary below.
module geolocation

const visibility_state_timeout_ms = EpochTimeStamp(5_000)

__global geolocation_next_watch_id int

pub struct PositionOptions {
pub:
	enable_high_accuracy bool
	timeout              u32 = 0xffff_ffff
	maximum_age          u32
}

pub type PositionCallback = fn (&GeolocationPosition)

pub type PositionErrorCallback = fn (&GeolocationPositionError)

pub type PositionProvider = fn (enable_high_accuracy bool) !CoordinatesData

pub fn invoke_position_callback(callback PositionCallback, position &GeolocationPosition) {
	callback(position)
}

pub fn invoke_position_error_callback(callback PositionErrorCallback, position_error &GeolocationPositionError) {
	callback(position_error)
}

pub struct EmulatedPositionData {
pub:
	coordinates ?&GeolocationCoordinates
	error       ?GeolocationPositionErrorCode
}

pub struct GeolocationHost {
pub mut:
	fully_active    bool = true
	secure_context  bool = true
	feature_allowed bool = true
	visible         bool = true
	now_ms          EpochTimeStamp
	emulated_data   ?CoordinatesData
	emulated_error  ?GeolocationPositionErrorCode
	provider        ?PositionProvider
}

struct GeolocationRequest {
	success             PositionCallback @[required]
	error               ?PositionErrorCallback
	options             PositionOptions
	watch_id            ?int
	visibility_deadline EpochTimeStamp
}

struct WatchPositionData {
mut:
	success                            PositionCallback @[required]
	error                              ?PositionErrorCallback
	options                            PositionOptions
	emulated_position_data_observer_id ?u64
}

enum GeolocationTaskKind {
	success
	error
}

struct GeolocationTask {
	kind     GeolocationTaskKind
	success  ?PositionCallback
	error    ?PositionErrorCallback
	position ?&GeolocationPosition
	code     GeolocationPositionErrorCode
}

@[heap]
pub struct Geolocation {
pub mut:
	host            GeolocationHost
	cached_position ?&GeolocationPosition
mut:
	watch_ids                          map[int]bool
	watch_data                         map[int]WatchPositionData
	pending_visible                    []GeolocationRequest
	pending_watch_position_request_ids map[int]u64
	tasks                              []GeolocationTask
	next_emulated_position_observer_id u64
}

pub fn Geolocation.create(host GeolocationHost) &Geolocation {
	return &Geolocation{
		host: host
		watch_ids: map[int]bool{}
		watch_data: map[int]WatchPositionData{}
		pending_watch_position_request_ids: map[int]u64{}
	}
}

pub fn Geolocation.construct_impl() &Geolocation {
	return Geolocation.create(GeolocationHost{})
}

// V's host record is the cycle-free counterpart of the Window retained by
// the current C++ object. It owns the associated-document and page inputs.
pub fn (geo &Geolocation) window() &GeolocationHost {
	return &geo.host
}

pub fn (mut geo Geolocation) get_current_position(success PositionCallback, error_callback ?PositionErrorCallback, options PositionOptions) {
	if !geo.host.fully_active {
		geo.call_back_with_error(error_callback, .position_unavailable)
		return
	}
	geo.request_a_position(GeolocationRequest{
		success: success
		error: error_callback
		options: options
	})
}

pub fn (mut geo Geolocation) watch_position(success PositionCallback, error_callback ?PositionErrorCallback, options PositionOptions) int {
	if !geo.host.fully_active {
		geo.call_back_with_error(error_callback, .position_unavailable)
		return 0
	}
	geolocation_next_watch_id++
	watch_id := geolocation_next_watch_id
	geo.watch_ids[watch_id] = true
	geo.watch_data[watch_id] = WatchPositionData{
		success: success
		error: error_callback
		options: options
	}
	geo.request_a_position(GeolocationRequest{
		success: success
		error: error_callback
		options: options
		watch_id: watch_id
	})
	return watch_id
}

pub fn (mut geo Geolocation) clear_watch(watch_id int) {
	geo.remove_watch_id(watch_id)
	geo.pending_watch_position_request_ids.delete(watch_id)
}

pub fn (mut geo Geolocation) remove_watch_id(watch_id int) {
	geo.watch_ids.delete(watch_id)
	geo.unregister_watch_position_observer(watch_id)
	geo.watch_data.delete(watch_id)
	mut remaining_visible_requests := []GeolocationRequest{cap: geo.pending_visible.len}
	for pending in geo.pending_visible {
		if pending_watch_id := pending.watch_id {
			if pending_watch_id == watch_id {
				continue
			}
		}
		remaining_visible_requests << pending
	}
	geo.pending_visible = remaining_visible_requests
}

// The embedding host represents the top-level traversable state used for
// emulation. Absence is not representable after construction, so the host is
// always the returned traversable boundary.
pub fn (geo &Geolocation) top_level_traversable() &GeolocationHost {
	return &geo.host
}

pub fn (mut geo Geolocation) unregister_watch_position_observer(watch_id int) {
	mut data := geo.watch_data[watch_id] or { return }
	data.emulated_position_data_observer_id = none
	geo.watch_data[watch_id] = data
}

fn (mut geo Geolocation) request_a_position(request GeolocationRequest) {
	if !geo.host.feature_allowed || !geo.host.secure_context {
		if watch_id := request.watch_id {
			geo.remove_watch_id(watch_id)
		}
		geo.call_back_with_error(request.error, .permission_denied)
		return
	}
	geo.run_in_parallel_when_document_is_visible(request)
}

fn (mut geo Geolocation) acquire_a_position(request GeolocationRequest) {
	if watch_id := request.watch_id {
		if watch_id !in geo.watch_ids {
			return
		}
	}
	emulated := geo.get_emulated_position_data()
	if code := emulated.error {
		geo.call_back_with_error(request.error, code)
		return
	}
	if coordinates := emulated.coordinates {
		geo.queue_success(request.success, GeolocationPosition.create(coordinates, geo.host.now_ms, request.options.enable_high_accuracy))
		geo.register_emulated_position_observer(request.watch_id)
		return
	}
	if cached := geo.cached_position {
		cache_time := if geo.host.now_ms > request.options.maximum_age {
			geo.host.now_ms - request.options.maximum_age
		} else {
			EpochTimeStamp(0)
		}
		if request.options.maximum_age > 0 && cached.timestamp() > cache_time
			&& cached.is_high_accuracy() == request.options.enable_high_accuracy {
			geo.queue_success(request.success, cached)
			geo.register_emulated_position_observer(request.watch_id)
			return
		}
	}
	geo.acquire_position_from_page(request)
}

fn (mut geo Geolocation) acquire_position_from_page(request GeolocationRequest) {
	if watch_id := request.watch_id {
		if watch_id !in geo.watch_ids {
			return
		}
	}
	mut data := CoordinatesData{}
	if provider := geo.host.provider {
		data = provider(request.options.enable_high_accuracy) or {
			geo.call_back_with_error(request.error, .position_unavailable)
			return
		}
	}
	position := GeolocationPosition.create(GeolocationCoordinates.create(data), geo.host.now_ms, request.options.enable_high_accuracy)
	geo.cached_position = position
	geo.queue_success(request.success, position)
	geo.register_emulated_position_observer(request.watch_id)
}

fn (mut geo Geolocation) register_emulated_position_observer(watch_id ?int) {
	id := watch_id or { return }
	mut data := geo.watch_data[id] or { return }
	if data.emulated_position_data_observer_id != none {
		return
	}
	geo.next_emulated_position_observer_id++
	data.emulated_position_data_observer_id = geo.next_emulated_position_observer_id
	geo.watch_data[id] = data
}

// https://w3c.github.io/geolocation/#dfn-get-emulated-position-data
pub fn (geo &Geolocation) get_emulated_position_data() EmulatedPositionData {
	if code := geo.host.emulated_error {
		return EmulatedPositionData{ error: code }
	}
	if data := geo.host.emulated_data {
		return EmulatedPositionData{
			coordinates: GeolocationCoordinates.create(data)
		}
	}
	return EmulatedPositionData{}
}

fn (mut geo Geolocation) run_in_parallel_when_document_is_visible(request GeolocationRequest) {
	if geo.host.visible {
		geo.acquire_a_position(request)
		return
	}
	geo.pending_visible << GeolocationRequest{
		success: request.success
		error: request.error
		options: request.options
		watch_id: request.watch_id
		visibility_deadline: geo.host.now_ms + visibility_state_timeout_ms
	}
}

fn (mut geo Geolocation) queue_success(callback PositionCallback, position &GeolocationPosition) {
	queue_success_callback(mut geo, callback, position)
}

pub fn queue_success_callback(mut geo Geolocation, callback PositionCallback, position &GeolocationPosition) {
	geo.tasks << GeolocationTask{
		kind: .success
		success: callback
		position: position
	}
}

fn (mut geo Geolocation) call_back_with_error(callback ?PositionErrorCallback, code GeolocationPositionErrorCode) {
	if callback == none {
		return
	}
	queue_error_callback(mut geo, callback, GeolocationPositionError.create(code))
}

pub fn queue_error_callback(mut geo Geolocation, callback PositionErrorCallback, position_error &GeolocationPositionError) {
	geo.tasks << GeolocationTask{
		kind: .error
		error: callback
		code: position_error.code()
	}
}

// Setting emulated position data is a significant position change. Re-enter
// the request algorithm for each active watch, preserving its callbacks and
// options exactly as the C++ traversable observer does.
pub fn (mut geo Geolocation) set_emulated_position_data(data ?CoordinatesData, position_error ?GeolocationPositionErrorCode) {
	geo.host.emulated_data = data
	geo.host.emulated_error = position_error
	watch_ids := geo.watch_ids.keys()
	for watch_id in watch_ids {
		watch := geo.watch_data[watch_id] or { continue }
		geo.request_a_position(GeolocationRequest{
			success: watch.success
			error: watch.error
			options: watch.options
			watch_id: watch_id
		})
	}
}

// Visibility changes are delivered by the host. Requests wait while hidden,
// matching run_in_parallel_when_document_is_visible().
pub fn (mut geo Geolocation) set_visible(visible bool) {
	geo.host.visible = visible
	if !visible {
		return
	}
	requests := geo.pending_visible.clone()
	geo.pending_visible.clear()
	for request in requests {
		if request.visibility_deadline > 0 && geo.host.now_ms >= request.visibility_deadline {
			continue
		}
		geo.acquire_a_position(request)
	}
}

// Hidden-document waits are abandoned after five seconds without invoking
// either callback, as in run_in_parallel_when_document_is_visible().
pub fn (mut geo Geolocation) expire_visibility_waits() {
	mut active := []GeolocationRequest{}
	for request in geo.pending_visible {
		if request.visibility_deadline == 0 || geo.host.now_ms < request.visibility_deadline {
			active << request
		}
	}
	geo.pending_visible = active
}

pub fn (mut geo Geolocation) run_next_task() bool {
	if geo.tasks.len == 0 {
		return false
	}
	task := geo.tasks[0]
	geo.tasks.delete(0)
	match task.kind {
		.success {
			callback := task.success or { return true }
			position := task.position or { return true }
			invoke_position_callback(callback, position)
		}
		.error {
			callback := task.error or { return true }
			invoke_position_error_callback(callback, GeolocationPositionError.create(task.code))
		}
	}
	return true
}

pub fn (mut geo Geolocation) drain_tasks() {
	for geo.run_next_task() {
	}
}

pub fn (geo &Geolocation) has_watch(watch_id int) bool {
	return watch_id in geo.watch_ids
}

pub fn (geo &Geolocation) has_emulated_position_observer(watch_id int) bool {
	data := geo.watch_data[watch_id] or { return false }
	return data.emulated_position_data_observer_id != none
}
