// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Geolocation/Geolocation.{h,cpp,idl}. Document lifecycle,
// permissions, visibility, the clock and device acquisition enter through the
// explicit GeolocationHost state/callback boundary below.
module geolocation

const visibility_state_timeout_ms = EpochTimeStamp(5_000)

pub struct PositionOptions {
pub:
	enable_high_accuracy bool
	timeout              u32 = 0xffff_ffff
	maximum_age          u32
}

pub type PositionCallback = fn (&GeolocationPosition)

pub type PositionErrorCallback = fn (&GeolocationPositionError)

pub type PositionProvider = fn (enable_high_accuracy bool) !CoordinatesData

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
	next_watch_id   int
mut:
	watch_ids       map[int]bool
	pending_visible []GeolocationRequest
	tasks           []GeolocationTask
}

pub fn Geolocation.create(host GeolocationHost) &Geolocation {
	return &Geolocation{
		host:      host
		watch_ids: map[int]bool{}
	}
}

pub fn Geolocation.construct_impl() &Geolocation {
	return Geolocation.create(GeolocationHost{})
}

pub fn (mut geo Geolocation) get_current_position(success PositionCallback, error_callback ?PositionErrorCallback, options PositionOptions) {
	if !geo.host.fully_active {
		geo.call_back_with_error(error_callback, .position_unavailable)
		return
	}
	geo.request_a_position(GeolocationRequest{
		success: success
		error:   error_callback
		options: options
	})
}

pub fn (mut geo Geolocation) watch_position(success PositionCallback, error_callback ?PositionErrorCallback, options PositionOptions) int {
	if !geo.host.fully_active {
		geo.call_back_with_error(error_callback, .position_unavailable)
		return 0
	}
	geo.next_watch_id++
	watch_id := geo.next_watch_id
	geo.watch_ids[watch_id] = true
	geo.request_a_position(GeolocationRequest{
		success:  success
		error:    error_callback
		options:  options
		watch_id: watch_id
	})
	return watch_id
}

pub fn (mut geo Geolocation) clear_watch(watch_id int) {
	geo.watch_ids.delete(watch_id)
}

fn (mut geo Geolocation) request_a_position(request GeolocationRequest) {
	if !geo.host.feature_allowed || !geo.host.secure_context {
		if watch_id := request.watch_id {
			geo.watch_ids.delete(watch_id)
		}
		geo.call_back_with_error(request.error, .permission_denied)
		return
	}
	if !geo.host.visible {
		geo.pending_visible << GeolocationRequest{
			success:             request.success
			error:               request.error
			options:             request.options
			watch_id:            request.watch_id
			visibility_deadline: geo.host.now_ms + visibility_state_timeout_ms
		}
		return
	}
	geo.acquire_a_position(request)
}

fn (mut geo Geolocation) acquire_a_position(request GeolocationRequest) {
	if watch_id := request.watch_id {
		if watch_id !in geo.watch_ids {
			return
		}
	}
	if code := geo.host.emulated_error {
		geo.call_back_with_error(request.error, code)
		return
	}
	if data := geo.host.emulated_data {
		geo.queue_success(request.success, GeolocationPosition.create(GeolocationCoordinates.create(data),
			geo.host.now_ms, request.options.enable_high_accuracy))
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
	position := GeolocationPosition.create(GeolocationCoordinates.create(data), geo.host.now_ms,
		request.options.enable_high_accuracy)
	geo.cached_position = position
	geo.queue_success(request.success, position)
}

fn (mut geo Geolocation) queue_success(callback PositionCallback, position &GeolocationPosition) {
	geo.tasks << GeolocationTask{
		kind:     .success
		success:  callback
		position: position
	}
}

fn (mut geo Geolocation) call_back_with_error(callback ?PositionErrorCallback, code GeolocationPositionErrorCode) {
	if callback == none {
		return
	}
	geo.tasks << GeolocationTask{
		kind:  .error
		error: callback
		code:  code
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
			callback(position)
		}
		.error {
			callback := task.error or { return true }
			callback(GeolocationPositionError.create(task.code))
		}
	}
	return true
}

pub fn (mut geo Geolocation) drain_tasks() {
	for geo.run_next_task() {}
}

pub fn (geo &Geolocation) has_watch(watch_id int) bool {
	return watch_id in geo.watch_ids
}
