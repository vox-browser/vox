// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Page's browser-process bridge for the Geolocation spec's
// "try to acquire position data from the underlying system" step.
module page

import geolocation
import platform

pub type GeolocationPositionResult = geolocation.CoordinatesData
	| geolocation.GeolocationPositionErrorCode

pub type GeolocationPositionCallback = fn (GeolocationPositionResult)

pub enum GeolocationRequestType {
	one_shot
	watch
}

pub fn (mut p Page) request_geolocation_position(callback GeolocationPositionCallback, type_ GeolocationRequestType) u64 {
	request_id := p.next_geolocation_request_id
	p.next_geolocation_request_id++
	// The Page outlives the requesting document's arena.
	persistent := platform.enter_persistent()
	p.pending_geolocation_requests[request_id] = PendingGeolocationRequest{
		callback: callback
		type_: type_
	}
	platform.leave_persistent(persistent)

	if type_ == .watch {
		p.client_.page_did_start_geolocation_position_watch(request_id)
		return request_id
	}

	if p.active_geolocation_request_id == none {
		p.active_geolocation_request_id = request_id
		p.client_.page_did_request_geolocation_position(request_id)
	}
	return request_id
}

pub fn (mut p Page) request_one_shot_geolocation_position(callback GeolocationPositionCallback) u64 {
	return p.request_geolocation_position(callback, .one_shot)
}

pub fn (mut p Page) cancel_geolocation_position_request(request_id u64) {
	request := p.pending_geolocation_requests[request_id] or { return }
	p.pending_geolocation_requests.delete(request_id)

	if request.type_ == .watch {
		p.client_.page_did_stop_geolocation_position_watch(request_id)
		return
	}

	active_request_id := p.active_geolocation_request_id or { return }
	if active_request_id != request_id {
		return
	}

	p.client_.page_did_cancel_geolocation_position_request(request_id)
	p.active_geolocation_request_id = none
	for candidate_id, candidate in p.pending_geolocation_requests {
		if candidate.type_ == .one_shot {
			p.active_geolocation_request_id = candidate_id
			p.client_.page_did_request_geolocation_position(candidate_id)
			return
		}
	}
}

pub fn (mut p Page) receive_geolocation_position(request_id u64, result GeolocationPositionResult) {
	request := p.pending_geolocation_requests[request_id] or { return }
	if request.type_ == .watch {
		if result is geolocation.GeolocationPositionErrorCode
			&& result == geolocation.GeolocationPositionErrorCode.permission_denied {
			p.pending_geolocation_requests.delete(request_id)
		}
		request.callback(result)
		return
	}

	active_request_id := p.active_geolocation_request_id or { return }
	if active_request_id != request_id {
		return
	}
	p.active_geolocation_request_id = none

	mut callbacks := []GeolocationPositionCallback{}
	mut completed_request_ids := []u64{}
	for completed_request_id, completed_request in p.pending_geolocation_requests {
		if completed_request.type_ != .one_shot {
			continue
		}
		callbacks << completed_request.callback
		completed_request_ids << completed_request_id
	}
	for completed_request_id in completed_request_ids {
		p.pending_geolocation_requests.delete(completed_request_id)
	}
	for callback in callbacks {
		callback(result)
	}
}

pub fn (p &Page) pending_geolocation_request_count() int {
	return p.pending_geolocation_requests.len
}

pub fn (p &Page) active_geolocation_request() ?u64 {
	return p.active_geolocation_request_id
}
