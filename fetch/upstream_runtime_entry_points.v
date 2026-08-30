// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Inline Fetch infrastructure accessors plus the cache, timing, controller,
// and receiver algorithms whose platform resources are represented by V
// boundary types.
module fetch

import highresolutiontime

pub fn (algorithms &FetchAlgorithms) process_request_body_chunk_length() ?ProcessRequestBodyChunkLength {
	return algorithms.input.process_request_body_chunk_length
}

pub fn (algorithms &FetchAlgorithms) process_request_end_of_body() ?ProcessRequestEndOfBody {
	return algorithms.input.process_request_end_of_body
}

pub fn (algorithms &FetchAlgorithms) process_early_hints_response() ?ProcessResponse {
	return algorithms.input.process_early_hints_response
}

pub fn (algorithms &FetchAlgorithms) process_response() ?ProcessResponse {
	return algorithms.input.process_response
}

pub fn (algorithms &FetchAlgorithms) process_response_end_of_body() ?ProcessResponse {
	return algorithms.input.process_response_end_of_body
}

pub fn (algorithms &FetchAlgorithms) process_response_consume_body() ?ProcessResponseConsumeBody {
	return algorithms.input.process_response_consume_body
}

pub fn (mut controller FetchController) set_fetch_params(params &FetchParams) {
	controller.fetch_params_ = params
}

pub fn (mut controller FetchController) set_pending_request(request ?&Request) {
	controller.pending_request_ = request
}

@[heap]
pub struct FetchControllerHolder {
mut:
	controller_ ?&FetchController
}

pub fn FetchControllerHolder.create() &FetchControllerHolder {
	return &FetchControllerHolder{}
}

pub fn (holder &FetchControllerHolder) controller() ?&FetchController {
	return holder.controller_
}

pub fn (mut holder FetchControllerHolder) set_controller(controller &FetchController) {
	holder.controller_ = controller
}

pub fn (timing &FetchTimingInfo) fetch_timing_start_time() f64 {
	return timing.start_time
}

pub fn (mut timing FetchTimingInfo) set_start_time(value f64) {
	timing.start_time = value
}

pub fn (timing &FetchTimingInfo) fetch_timing_redirect_start_time() f64 {
	return timing.redirect_start_time
}

pub fn (mut timing FetchTimingInfo) set_redirect_start_time(value f64) {
	timing.redirect_start_time = value
}

pub fn (timing &FetchTimingInfo) fetch_timing_redirect_end_time() f64 {
	return timing.redirect_end_time
}

pub fn (mut timing FetchTimingInfo) set_redirect_end_time(value f64) {
	timing.redirect_end_time = value
}

pub fn (timing &FetchTimingInfo) fetch_timing_post_redirect_start_time() f64 {
	return timing.post_redirect_start_time
}

pub fn (mut timing FetchTimingInfo) set_post_redirect_start_time(value f64) {
	timing.post_redirect_start_time = value
}

pub fn (timing &FetchTimingInfo) fetch_timing_final_service_worker_start_time() f64 {
	return timing.final_service_worker_start_time
}

pub fn (mut timing FetchTimingInfo) set_final_service_worker_start_time(value f64) {
	timing.final_service_worker_start_time = value
}

pub fn (timing &FetchTimingInfo) fetch_timing_final_network_request_start_time() f64 {
	return timing.final_network_request_start_time
}

pub fn (mut timing FetchTimingInfo) set_final_network_request_start_time(value f64) {
	timing.final_network_request_start_time = value
}

pub fn (timing &FetchTimingInfo) fetch_timing_final_network_response_start_time() f64 {
	return timing.final_network_response_start_time
}

pub fn (mut timing FetchTimingInfo) set_final_network_response_start_time(value f64) {
	timing.final_network_response_start_time = value
}

pub fn (timing &FetchTimingInfo) fetch_timing_first_interim_network_response_start_time() f64 {
	return timing.first_interim_network_response_start_time
}

pub fn (mut timing FetchTimingInfo) set_first_interim_network_response_start_time(value f64) {
	timing.first_interim_network_response_start_time = value
}

pub fn (timing &FetchTimingInfo) fetch_timing_end_time() f64 {
	return timing.end_time
}

pub fn (mut timing FetchTimingInfo) set_end_time(value f64) {
	timing.end_time = value
}

pub fn (timing &FetchTimingInfo) fetch_timing_final_connection_timing_info() ?ConnectionTimingInfo {
	return timing.final_connection_timing_info
}

pub fn (mut timing FetchTimingInfo) set_final_connection_timing_info(info ConnectionTimingInfo) {
	timing.final_connection_timing_info = info
}

pub fn (timing &FetchTimingInfo) fetch_timing_server_timing_headers() []string {
	return timing.server_timing_headers.clone()
}

pub fn (mut timing FetchTimingInfo) set_server_timing_headers(headers []string) {
	timing.server_timing_headers = headers.clone()
}

pub fn (timing &FetchTimingInfo) fetch_timing_render_blocking() bool {
	return timing.render_blocking
}

pub fn (mut timing FetchTimingInfo) set_render_blocking(render_blocking bool) {
	timing.render_blocking = render_blocking
}

pub fn (mut timing FetchTimingInfo) update_final_timings(final RequestTimingInfo, cross_origin_isolated bool) {
	coarsened := fn [timing, cross_origin_isolated] (microseconds i64) f64 {
		milliseconds := timing.start_time + f64(microseconds) / 1000.0
		return highresolutiontime.coarsen_time(milliseconds, cross_origin_isolated)
	}
	timing.final_connection_timing_info = ConnectionTimingInfo{
		domain_lookup_start: coarsened(final.domain_lookup_start_microseconds)
		domain_lookup_end: coarsened(final.domain_lookup_end_microseconds)
		connect_start: coarsened(final.connect_start_microseconds)
		connect_end: coarsened(final.connect_end_microseconds)
		secure_connection_start: coarsened(final.secure_connect_start_microseconds)
		alpn_negotiated_protocol: final.http_version_alpn_identifier
	}
	timing.final_network_request_start_time = coarsened(final.request_start_microseconds)
	timing.final_network_response_start_time = coarsened(final.response_start_microseconds)
}

pub fn (params &FetchParams) fetch_params_request() &Request {
	return params.request
}

pub fn (mut params FetchParams) set_request(request &Request) {
	params.request = request
}

pub fn (params &FetchParams) fetch_params_controller() &FetchController {
	return params.controller
}

pub fn (params &FetchParams) fetch_params_timing_info() &FetchTimingInfo {
	return params.timing_info
}

pub fn (params &FetchParams) fetch_params_algorithms() &FetchAlgorithms {
	return params.algorithms
}

pub fn (mut params FetchParams) set_algorithms(algorithms &FetchAlgorithms) {
	params.algorithms = algorithms
}

pub fn (params &FetchParams) fetch_params_task_destination() string {
	return params.task_destination
}

pub fn (mut params FetchParams) set_task_destination(destination string) {
	params.task_destination = destination
}

pub fn (params &FetchParams) cross_origin_isolated_capability() bool {
	return params.cross_origin_isolated
}

pub fn (mut params FetchParams) set_cross_origin_isolated_capability(value bool) {
	params.cross_origin_isolated = value
}

pub fn (params &FetchParams) fetch_params_preloaded_response_candidate() PreloadedResponseCandidate {
	return PreloadedResponseCandidate{
		kind: params.preloaded_response_candidate
		response: params.preloaded_response
	}
}

pub fn (mut params FetchParams) set_preloaded_response_candidate(candidate PreloadedResponseCandidate) {
	params.preloaded_response_candidate = candidate.kind
	params.preloaded_response = candidate.response
}

pub fn (record &FetchRecord) fetch_record_request() &Request {
	return record.request
}

pub fn (mut record FetchRecord) set_request(request &Request) {
	record.request = request
}

pub fn (record &FetchRecord) fetch_record_fetch_controller() ?&FetchController {
	return record.fetch_controller
}

pub fn (mut record FetchRecord) set_fetch_controller(controller ?&FetchController) {
	record.fetch_controller = controller
}

pub fn (mut pending PendingResponse) run_callback() {
	response := pending.response_ or { return }
	callback := pending.callback_ or { return }
	pending.callback_ = none
	callback(response)
}

pub fn (flag &RefCountedFlag) ref_counted_flag_value() bool {
	return flag.value
}

pub fn (mut flag RefCountedFlag) set_value(value bool) {
	flag.value = value
}

pub fn (mut receiver FetchedDataReceiver) set_pending_promise(callback FetchedDataPendingPromise) {
	if receiver.pending_promise_ != none {
		return
	}
	receiver.pending_promise_ = callback
	if !receiver.buffer_is_eof() {
		receiver.pull_bytes_into_stream()
	} else if receiver.lifecycle_state_ == .ready_to_close {
		receiver.close_stream()
	}
}

pub fn (receiver &FetchedDataReceiver) buffer_is_eof() bool {
	return receiver.pulled_bytes_ == receiver.buffer_.len
}

pub fn (mut receiver FetchedDataReceiver) close_stream() {
	if !receiver.buffer_is_eof() {
		return
	}
	if callback := receiver.pending_promise_ {
		callback()
		receiver.pending_promise_ = none
	}
	receiver.lifecycle_state_ = .closed
}

fn fetch_cache_partition_key(request &Request) ?string {
	partition := determine_the_http_cache_partition(request) or { return none }
	return '${partition.top_level_origin}\n${request.method}\n${request.current_url().serialize()}'
}

pub fn determine_the_http_cache_partition(request &Request) ?NetworkPartitionKey {
	if origin := request.top_level_navigation_initiator_origin {
		return determine_the_network_partition_key(origin)
	}
	if origin := request.origin.origin {
		return determine_the_network_partition_key(origin)
	}
	return none
}

pub fn select_response_from_cache(request &Request) ?&Response {
	if !fetch_http_memory_cache_enabled {
		return none
	}
	key := fetch_cache_partition_key(request) or { return none }
	entry := fetch_http_memory_cache[key] or { return none }
	return entry.clone()
}

pub fn store_response_in_cache(request &Request, response &Response) {
	if !fetch_http_memory_cache_enabled || request.cache_mode == .no_store {
		return
	}
	key := fetch_cache_partition_key(request) or { return }
	fetch_http_memory_cache[key] = response.clone()
}

pub fn abort_fetch(mut request Request, response_object ?&ResponseObject, error_message string) {
	if request.body.kind == .body_object {
		request.body = RequestBody{}
	}
	if object := response_object {
		if mut body := object.body_ {
			body.error_stream(error_message)
		}
	}
}
