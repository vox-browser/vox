// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Inline Fetch infrastructure accessors plus the cache, timing, controller,
// and receiver algorithms whose platform resources are represented by V
// boundary types.
module fetch

import highresolutiontime
import http
import streams
import time

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
	queue_fetch_task(fn [pending, response, callback] () {
		callback(response)
		mut request := pending.request
		request.remove_pending_response(pending)
	})
}

pub fn (flag &RefCountedFlag) ref_counted_flag_value() bool {
	return flag.value
}

pub fn (mut flag RefCountedFlag) set_value(value bool) {
	flag.value = value
}

pub fn (mut receiver FetchedDataReceiver) set_pending_promise(callback FetchedDataPendingPromise) {
	assert receiver.pending_promise_ == none
	assert !receiver.has_unfulfilled_promise_
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
	assert !receiver.has_unfulfilled_promise_
	assert receiver.buffer_is_eof()
	callback := receiver.pending_promise_ or {
		panic('FetchedDataReceiver.close_stream called without a pending promise')
	}
	callback()
	receiver.pending_promise_ = none
	receiver.lifecycle_state_ = .closed
	mut stream := receiver.stream_
	stream.close()
	if response := receiver.response_ {
		finalize_response_in_cache(receiver.fetch_params_.request, response)
	}
}

fn fetch_cache_partition_key(request &Request) ?string {
	partition := determine_the_http_cache_partition(request) or { return none }
	mut url := request.current_url()
	url.set_fragment(none)
	return '${partition.top_level_origin.serialize_for_ipc()}\n${request.method}\n${url.serialize()}'
}

pub fn determine_the_http_cache_partition(request &Request) ?NetworkPartitionKey {
	if reserved_client := request.reserved_client {
		origin := reserved_client.fetch_request_environment_top_level_origin() or {
			creation_url := reserved_client.fetch_request_environment_top_level_creation_url() or {
				return none
			}
			creation_url.origin()
		}
		return determine_the_network_partition_key(origin)
	}
	if client := request.client {
		origin := client.fetch_request_client_top_level_origin() or {
			creation_url := client.fetch_request_client_top_level_creation_url() or { return none }
			creation_url.origin()
		}
		return determine_the_network_partition_key(origin)
	}
	return none
}

pub fn select_response_from_cache(request &Request) ?&Response {
	if !fetch_http_memory_cache_enabled {
		return none
	}
	if request.cache_mode in [.reload, .no_cache] || !http.is_cacheable_request(request.method, request.header_list) {
		return none
	}
	key := fetch_cache_partition_key(request) or { return none }
	entries := fetch_http_memory_cache_complete[key] or { return none }
	for entry in entries {
		if http.create_vary_key(request.header_list, entry.response_headers) != entry.vary_key {
			continue
		}
		freshness_lifetime := http.calculate_freshness_lifetime(entry.status_code, entry.response_headers)
		current_age := http.calculate_age(entry.response_headers, entry.request_time, entry.response_time)
		lifetime_status := http.cache_lifetime_status(request.header_list, entry.response_headers, freshness_lifetime, current_age)
		if lifetime_status != .fresh && request.cache_mode !in [.force_cache, .only_if_cached] {
			fetch_http_memory_cache_complete.delete(key)
			return none
		}
		mut response := Response.create()
		response.url_list = [request.current_url()]
		response.method = request.method
		response.status = entry.status_code
		response.status_message = entry.reason_phrase
		response.header_list = http.store_header_and_trailer_fields(entry.response_headers)
		response.set_body_bytes(entry.response_body.clone())
		return response
	}
	return none
}

pub fn store_response_in_cache(request &Request, response &Response) {
	if !fetch_http_memory_cache_enabled || request.cache_mode == .no_store {
		return
	}
	if !http.is_cacheable_request(request.method, request.header_list) || !http.is_cacheable_response(response.status, response.header_list) {
		return
	}
	key := fetch_cache_partition_key(request) or { return }
	mut entries := fetch_http_memory_cache_pending[key] or { []FetchMemoryCacheEntry{} }
	entries << FetchMemoryCacheEntry{
		vary_key: http.create_vary_key(request.header_list, response.header_list)
		status_code: response.status
		reason_phrase: response.status_message
		request_headers: http.store_header_and_trailer_fields(request.header_list)
		response_headers: http.store_header_and_trailer_fields(response.header_list)
		request_time: request.request_time
		response_time: time.now().unix_milli()
	}
	fetch_http_memory_cache_pending[key] = entries
}

pub fn finalize_response_in_cache(request &Request, response &Response) {
	if !fetch_http_memory_cache_enabled || request.cache_mode == .no_store {
		return
	}
	if !http.is_cacheable_request(request.method, request.header_list) || !http.is_cacheable_response(response.status, response.header_list) {
		return
	}
	key := fetch_cache_partition_key(request) or { return }
	mut pending_entries := fetch_http_memory_cache_pending[key] or { return }
	vary_key := http.create_vary_key(request.header_list, response.header_list)
	mut matched_index := -1
	for index, entry in pending_entries {
		if entry.vary_key == vary_key {
			matched_index = index
			break
		}
	}
	if matched_index < 0 {
		return
	}
	mut entry := pending_entries[matched_index]
	entry.response_body = response.fetch_response_body_bytes() or { []u8{} }
	pending_entries.delete(matched_index)
	if pending_entries.len == 0 {
		fetch_http_memory_cache_pending.delete(key)
	} else {
		fetch_http_memory_cache_pending[key] = pending_entries
	}
	mut complete_entries := fetch_http_memory_cache_complete[key] or {
		[]FetchMemoryCacheEntry{}
	}
	complete_entries << entry
	fetch_http_memory_cache_complete[key] = complete_entries
}

pub fn abort_fetch(mut request Request, response_object ?&ResponseObject, error_message string) {
	if mut body := request.body.body_object {
		mut stream := body.stream()
		if stream.state() == .readable {
			streams.readable_stream_cancel(mut stream, streams.string_value(error_message))
		}
	}
	if object := response_object {
		if mut body := object.response_.fetch_response_body() {
			body.error_stream(error_message)
		}
	}
}
