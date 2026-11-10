// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Inline Fetch infrastructure accessors plus the cache, timing, controller,
// and receiver algorithms whose platform resources are represented by V
// boundary types.
module fetch

import cachepolicy
import dom
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
	controller.has_started_request_ = controller.has_started_request_ || request != none
}

// FetchController.cpp: retain the actual Requests::Request stop boundary.
pub fn (mut controller FetchController) set_pending_network_request(request ?RequestServerRequest) {
	controller.pending_network_request_ = request
}

pub fn (controller &FetchController) timing_info() ?&FetchTimingInfo {
	params := controller.fetch_params_ or { return none }
	return params.timing_info
}

pub fn (controller &FetchController) pending_preloaded_response() ?&PendingResponse {
	return controller.pending_preloaded_response_
}

pub fn (mut controller FetchController) set_pending_preloaded_response(response ?&PendingResponse) {
	controller.pending_preloaded_response_ = response
}

pub fn (controller &FetchController) requires_network() bool {
	return controller.requires_network_
}

pub fn (controller &FetchController) has_started_request() bool {
	return controller.has_started_request_
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
	// RequestServer's offsets belong to the final hop, after any redirects.
	final_request_start_time := timing.post_redirect_start_time
	coarsened := fn [final_request_start_time, cross_origin_isolated] (microseconds i64) f64 {
		milliseconds := final_request_start_time + f64(microseconds) / 1000.0
		return highresolutiontime.coarsen_time(milliseconds, cross_origin_isolated)
	}
	secure_connection_start := if final.secure_connect_start_microseconds != 0 {
		coarsened(final.secure_connect_start_microseconds)
	} else { f64(0) }
	timing.final_connection_timing_info = ConnectionTimingInfo{
		domain_lookup_start: coarsened(final.domain_lookup_start_microseconds)
		domain_lookup_end: coarsened(final.domain_lookup_end_microseconds)
		connect_start: coarsened(final.connect_start_microseconds)
		connect_end: coarsened(final.connect_end_microseconds)
		secure_connection_start: secure_connection_start
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

pub fn (params &FetchParams) has_response_body_transfer_lease() bool {
	return params.has_response_body_transfer_lease
}

pub fn (mut params FetchParams) set_has_response_body_transfer_lease(value bool) {
	params.has_response_body_transfer_lease = value
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
	if candidate.kind == .response {
		if response := candidate.response {
			mut controller := params.controller
			if mut pending := controller.pending_preloaded_response() {
				controller.set_pending_preloaded_response(none)
				pending.resolve(response)
			}
		}
	}
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
	pending_pointer := unsafe { &PendingResponse(pending) }
	deferred_invoke_for_request(pending_pointer.request, fn [pending_pointer, response, callback] () {
		callback(response)
		mut request := pending_pointer.request
		request.remove_pending_response(pending_pointer)
	})
}

pub fn (flag &RefCountedFlag) ref_counted_flag_value() bool {
	return flag.value
}

pub fn (mut flag RefCountedFlag) set_value(value bool) {
	flag.value = value
}

fn queue_networking_task(steps fn ()) {
	_ = queue_fetch_task(steps)
}

fn (mut receiver FetchedDataReceiver) append_to_cache_buffer(bytes []u8) {
	if cached_body := receiver.cache_body_ {
		receiver.cache_buffer_ << cached_body
		receiver.cache_body_ = none
	}
	receiver.cache_buffer_ << bytes
}

pub fn (mut receiver FetchedDataReceiver) set_cached_response_body(body []u8) {
	if !receiver.cache_enabled_ {
		return
	}
	receiver.cache_buffer_.clear()
	receiver.cache_body_ = body.clone()
	receiver.cache_body_replaces_network_buffer = true
}

fn (mut receiver FetchedDataReceiver) queue_delivery_task() {
	if receiver.delivery_task_queued_ {
		return
	}
	receiver.delivery_task_queued_ = true
	queue_networking_task(fn [mut receiver] () {
		receiver.deliver_pending_bytes()
	})
}

fn (mut receiver FetchedDataReceiver) deliver_pending_bytes() {
	receiver.delivery_task_queued_ = false
	bytes := receiver.pending_bytes_.clone()
	receiver.pending_bytes_.clear()
	if bytes.len > 0 {
		receiver.enqueue_into_stream(bytes)
	}
	if receiver.paused_network_delivery_ {
		receiver.paused_network_delivery_ = false
		if request := receiver.network_request_ {
			if set_paused := request.set_body_delivery_paused {
				set_paused(false)
			}
		}
	}
	if receiver.network_complete_ {
		queue_networking_task(fn [mut receiver] () {
			receiver.close_stream()
		})
	}
}

fn (mut receiver FetchedDataReceiver) enqueue_into_stream(bytes []u8) {
	if !receiver.stream_.is_readable() {
		return
	}
	mut stream := receiver.stream_
	mut controller := stream.byte_controller() or {
		if params := receiver.fetch_params_ {
			mut fetch_controller := params.controller
			fetch_controller.terminate()
		}
		return
	}
	streams.readable_byte_stream_controller_enqueue_native_bytes(mut controller, bytes.clone()) or {
		controller.error(err.msg())
		if params := receiver.fetch_params_ {
			mut fetch_controller := params.controller
			fetch_controller.terminate()
		}
	}
}

fn (mut receiver FetchedDataReceiver) close_stream() {
	if receiver.cache_enabled_ {
		if params := receiver.fetch_params_ {
			request := params.request
			if receiver.network_complete_ && receiver.stream_.is_readable() && !params.is_canceled()
				&& request.cache_mode != .no_store {
				if response := receiver.response_ {
					response_body := receiver.cache_body_ or { receiver.cache_buffer_.clone() }
					finalize_response_body_in_cache(request, response, response_body)
				}
			}
		}
	}
	receiver.retire_cache_storage()
	if !receiver.stream_.is_readable() {
		return
	}
	mut stream := receiver.stream_
	stream.close()
}

// A successful transfer may still have a queued stream-delivery task when its
// transport is released. Only incomplete transfers lose their pending entry.
pub fn (mut receiver FetchedDataReceiver) stop_caching_incomplete_response() {
	if !receiver.network_complete_ {
		receiver.retire_cache_storage()
	}
}

fn (mut receiver FetchedDataReceiver) retire_cache_storage() {
	if response := receiver.response_ {
		mut internal := unsafe { response.cache_storage_response() }
		internal.retire_cache_storage()
	}
	receiver.cache_enabled_ = false
	receiver.cache_body_ = none
	receiver.cache_buffer_.clear()
}

fn fetch_cache_partition_key(request &Request) ?string {
	partition := determine_the_http_cache_partition(request) or { return none }
	return fetch_memory_cache_key(partition, request.current_url(), request.method)
}

fn fetch_memory_cache_key(partition NetworkPartitionKey, input_url dom.URL, method string) string {
	mut url := input_url
	url.set_fragment(none)
	return '${partition.top_level_origin.serialize_for_ipc()}\n${method}\n${url.serialize()}'
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
	if request.cache_mode in [.no_store, .reload, .no_cache] || !http.is_cacheable_request(request.method, request.header_list) {
		return none
	}
	key := fetch_cache_partition_key(request) or { return none }
	entries := fetch_http_memory_cache_complete[key] or { return none }
	// RFC 9111: If several stored representations match, prefer the most
	// recently stored one. A later Vary field set can match an earlier one.
	for index := entries.len - 1; index >= 0; index-- {
		entry := entries[index]
		if http.create_vary_key(request.header_list, entry.response_headers) != entry.vary_key {
			continue
		}
		decision := cachepolicy.evaluate(request.cache_policy_request(), cachepolicy.Response{
			status: entry.status_code
			headers: cache_policy_headers(entry.response_headers)
			timing: cachepolicy.Timing{request_time: entry.request_time, response_time: entry.response_time}
		}, cachepolicy.ReuseOptions{}, time.now().unix_milli())
		if !decision.can_reuse() { continue }
		mut response := Response.create()
		response.url_list = [request.current_url()]
		response.method = request.method
		response.status = entry.status_code
		response.status_message = entry.reason_phrase
		response.header_list = cached_response_header_list(entry.response_headers, decision)
		response.set_javascript_bytecode_cache(entry.javascript_bytecode_cache)
		response.set_javascript_bytecode_cache_vary_key(entry.javascript_bytecode_cache_vary_key)
		response.set_javascript_bytecode_cache_memory_cache_request_headers(entry.request_headers)
		response.set_body_bytes(entry.response_body.clone())
		return response
	}
	return none
}

pub fn store_response_in_cache(request &Request, mut response Response) {
	if !fetch_http_memory_cache_enabled || request.cache_mode == .no_store {
		return
	}
	mut internal := response.cache_storage_response()
	if internal.cache_storage_retired_ || internal.cache_entry_token_ != 0 {
		return
	}
	if !http.is_cacheable_request(request.method, request.header_list) || !http.is_cacheable_response(internal.status, internal.header_list) {
		return
	}
	key := fetch_cache_partition_key(request) or { return }
	if fetch_http_memory_cache_next_response_token == u64(0xffffffffffffffff) {
		return
	}
	internal.cache_entry_token_ = fetch_http_memory_cache_next_response_token
	internal.cache_entry_key_ = key
	fetch_http_memory_cache_next_response_token++
	internal.set_javascript_bytecode_cache_memory_cache_request_headers(request.header_list)
	mut entries := fetch_http_memory_cache_pending[key] or { []FetchMemoryCacheEntry{} }
	entries << FetchMemoryCacheEntry{
		response_token: internal.cache_entry_token_
		vary_key: http.create_vary_key(request.header_list, internal.header_list)
		status_code: internal.status
		reason_phrase: internal.status_message
		request_headers: http.store_header_and_trailer_fields(request.header_list)
		response_headers: http.store_header_and_trailer_fields(internal.header_list)
		request_time: request.request_time
		response_time: time.now().unix_milli()
		javascript_bytecode_cache: internal.javascript_bytecode_cache()
		javascript_bytecode_cache_vary_key: internal.javascript_bytecode_cache_vary_key()
	}
	fetch_http_memory_cache_pending[key] = entries
}

pub fn finalize_response_in_cache(request &Request, response &Response) {
	internal := response.cache_storage_response()
	// Body.bytes() is empty for a live stream. Its receiver publishes the
	// accumulated bytes only after successful network completion.
	if internal.cache_body_pending_ {
		return
	}
	if body := internal.body {
		if body.body_source() == .readable_stream {
			return
		}
	}
	response_body := internal.fetch_response_body_bytes() or { []u8{} }
	finalize_response_body_in_cache(request, internal, response_body)
}

fn (response &Response) cache_storage_response() &Response {
	if internal := response.internal_response {
		return internal.cache_storage_response()
	}
	return response
}

fn (mut response Response) retire_cache_storage() {
	response.cache_storage_retired_ = true
	response.cache_body_pending_ = false
	if entry := response.take_pending_cache_entry() {
		_ = entry
	}
}

fn (mut response Response) take_pending_cache_entry() ?FetchMemoryCacheEntry {
	key := response.cache_entry_key_
	token := response.cache_entry_token_
	response.cache_entry_key_ = ''
	response.cache_entry_token_ = 0
	if token == 0 {
		return none
	}
	mut pending_entries := fetch_http_memory_cache_pending[key] or { return none }
	mut matched_index := -1
	for index, entry in pending_entries {
		if entry.response_token == token {
			matched_index = index
			break
		}
	}
	if matched_index < 0 {
		return none
	}
	entry := pending_entries[matched_index]
	pending_entries.delete(matched_index)
	if pending_entries.len == 0 {
		fetch_http_memory_cache_pending.delete(key)
	} else {
		fetch_http_memory_cache_pending[key] = pending_entries
	}
	return entry
}

fn finalize_response_body_in_cache(request &Request, response &Response, response_body []u8) {
	mut internal := unsafe { response.cache_storage_response() }
	key := internal.cache_entry_key_
	// Remove this producer's entry even when cancellation or policy changes
	// prevent publication. URL and Vary alone cannot identify concurrent work.
	mut entry := internal.take_pending_cache_entry() or { return }
	if !fetch_http_memory_cache_enabled || request.cache_mode == .no_store
		|| internal.cache_storage_retired_ {
		return
	}
	if !http.is_cacheable_request(request.method, request.header_list) || !http.is_cacheable_response(internal.status, internal.header_list) {
		return
	}
	entry.response_body = response_body.clone()
	mut complete_entries := fetch_http_memory_cache_complete[key] or {
		[]FetchMemoryCacheEntry{}
	}
	// A refreshed representation replaces its old variant. Appending it would
	// let a later default request keep selecting the pre-reload response and
	// retain every expired generation indefinitely.
	complete_entries = complete_entries.filter(it.vary_key != entry.vary_key)
	complete_entries << entry
	// Keep at most 16 recently completed variants per URL/partition. Entries
	// are in completion order; evict the oldest variant without touching
	// still-in-flight producers or their response tokens.
	for complete_entries.len > 16 {
		complete_entries.delete(0)
	}
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
