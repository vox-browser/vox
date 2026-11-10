// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Fetch/Fetching/Fetching.cpp: fetch_response_handover, response stream and EOF steps.
module fetch

import highresolutiontime
import mimesniff
import streams

@[heap]
struct FetchBodyAccumulator {
mut:
	bytes []u8
}

fn setup_response_report_timing(params &FetchParams, response &Response) {
	unsafe_end_time := highresolutiontime.unsafe_shared_current_time()
	mut controller := params.controller
	controller.set_report_timing_steps(fn [params, response, unsafe_end_time] (global ?FetchTimingReportDestination) {
		if !is_http_or_https_scheme(params.request.url().scheme()) { return }
		mut timing := params.timing_info
		timing.end_time = unsafe_end_time
		mut cache_state := response.fetch_response_cache_state()
		mut body_info := response.fetch_response_body_info()
		if !response.fetch_response_timing_allow_passed() {
			timing = create_opaque_timing_info(timing)
			cache_state = none
		}
		mut response_status := u16(0)
		if params.request.mode != .navigate || response.fetch_response_redirect_taint() == .same_origin {
			response_status = response.status
			if mime := extract_mime_type(response.header_list) {
				body_info.content_type = mimesniff.minimise_a_supported_mime_type(&mime)
			}
		}
		if initiator := params.request.initiator_type {
			if destination := global {
				destination.fetch_mark_resource_timing(timing, params.request.url().serialize(), initiator_type_to_string(initiator), cache_state, body_info, response_status)
			}
		}
	})
}

fn response_end_of_body(params &FetchParams, response &Response) {
	setup_response_report_timing(params, response)
	mut controller := params.controller
	queue_fetch_task_for_controller(mut controller, fn [params, response] () {
		mut request := params.request
		request.done = true
		if callback := params.algorithms.input.process_response_end_of_body {
			callback(response)
		}
		if params.request.initiator_type != none {
			if global := params.reporting_global {
				if params.task_destination_global_identity == global.fetch_timing_global_identity() {
					params.controller.report_timing_with_global(global)
				}
			}
		}
	})
}

fn queue_response_body_consumed(params &FetchParams, response &Response, result BodyBytes) {
	callback := params.algorithms.input.process_response_consume_body or { return }
	mut controller := params.controller
	queue_fetch_task_for_controller(mut controller, fn [callback, response, result] () {
		callback(response, result)
	})
}

pub fn fetch_response_handover(params &FetchParams, response &Response) {
	mut controller := params.controller
	if params.request.is_navigation_request() {
		controller.set_full_timing_info(params.timing_info)
	}
	// Step 4 precedes stream setup. The response task runs on the owning loop,
	// after the identity transform and its flush algorithm have been installed.
	if callback := params.algorithms.input.process_response {
		queue_fetch_task_for_controller(mut controller, fn [callback, response] () {
			callback(response)
		})
	}
	internal_response := if response.is_network_error() { response } else { response.unsafe_response() }
	if mut body := internal_response.body {
		mut transform := streams.TransformStream.construct_impl(streams.Transformer{
			transform: fn (chunk streams.Value) ![]streams.Value {
				return [chunk]
			}
			flush: fn [params, response] () ![]streams.Value {
				response_end_of_body(params, response)
				return []streams.Value{}
			}
		}, streams.QueuingStrategy{}, streams.QueuingStrategy{}) or { panic(err) }
		mut stream := body.stream()
		body.set_stream(stream.piped_through(mut transform, false, false, false, none))
	} else {
		response_end_of_body(params, response)
	}
	if params.algorithms.input.process_response_consume_body == none { return }
	if mut body := internal_response.body {
		// Fully reading a response is asynchronous: pending read promises retain
		// these callbacks until the producer supplies bytes, closes, or errors.
		accumulator := &FetchBodyAccumulator{}
		has_in_memory_body := body.source_kind == .bytes
		body.incrementally_read(fn [accumulator, has_in_memory_body] (chunk []u8) {
			// Drain the stream for its completion/error semantics, but do not
			// reconstruct bytes that the internal response already retains.
			if has_in_memory_body { return }
			mut result := unsafe { &FetchBodyAccumulator(accumulator) }
			result.bytes << chunk
		}, fn [params, response, internal_response, accumulator] () {
			bytes := if response_body := internal_response.body {
				if response_body.source_kind == .bytes {
					response_body.bytes()
				} else {
					accumulator.bytes.clone()
				}
			} else { accumulator.bytes.clone() }
			queue_response_body_consumed(params, response, BodyBytes{ kind: .bytes, bytes: bytes })
		}, fn [params, response] (_ string) {
			setup_response_report_timing(params, response)
			queue_response_body_consumed(params, response, BodyBytes{ kind: .failure })
		})
	} else {
		queue_response_body_consumed(params, response, BodyBytes{ kind: .empty })
	}
}
