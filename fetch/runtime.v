// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Fetching/* and the Fetch infrastructure controller/params,
// timing, task, network-partition, and fetch-record units. Platform network,
// cache, cookie, and event-loop delivery enter through FetchHost.
@[has_globals]
module fetch

import dom
import http
import securecontexts

__global (
	fetch_http_memory_cache_enabled = true
	fetch_next_task_id              = u64(1)
	fetch_http_memory_cache         = map[string]&Response{}
)

pub enum BodyBytesKind {
	empty
	failure
	bytes
}

pub struct BodyBytes {
pub:
	kind  BodyBytesKind
	bytes []u8
}

pub type ProcessRequestBodyChunkLength = fn (u64)

pub type ProcessRequestEndOfBody = fn ()

pub type ProcessResponse = fn (&Response)

pub type ProcessResponseConsumeBody = fn (&Response, BodyBytes)

pub struct FetchAlgorithmsInput {
pub:
	process_request_body_chunk_length ?ProcessRequestBodyChunkLength
	process_request_end_of_body       ?ProcessRequestEndOfBody
	process_early_hints_response      ?ProcessResponse
	process_response                  ?ProcessResponse
	process_response_end_of_body      ?ProcessResponse
	process_response_consume_body     ?ProcessResponseConsumeBody
}

@[heap]
pub struct FetchAlgorithms {
pub:
	input FetchAlgorithmsInput
}

pub fn FetchAlgorithms.create(input FetchAlgorithmsInput) &FetchAlgorithms {
	return &FetchAlgorithms{
		input: input
	}
}

pub enum FetchControllerState {
	ongoing
	terminated
	aborted
	stopped
}

pub type ReportTimingSteps = fn (&FetchTimingInfo)

pub type ManualRedirectSteps = fn ()

@[heap]
pub struct FetchController {
mut:
	state_                      FetchControllerState
	full_timing_info_           ?&FetchTimingInfo
	report_timing_steps_        ?ReportTimingSteps
	next_manual_redirect_steps_ ?ManualRedirectSteps
	serialized_abort_reason_    ?string
	pending_request_stopped_    bool
	ongoing_fetch_tasks_        map[u64]u64
	next_fetch_task_id_         u64
	inner_controller_           ?&FetchController
	fetch_params_               ?&FetchParams
	pending_request_            ?&Request
}

pub fn FetchController.create() &FetchController {
	return &FetchController{}
}

pub fn (controller &FetchController) state() FetchControllerState {
	return controller.state_
}

pub fn (mut controller FetchController) set_full_timing_info(info &FetchTimingInfo) {
	controller.full_timing_info_ = info
}

pub fn (mut controller FetchController) set_report_timing_steps(callback ReportTimingSteps) {
	controller.report_timing_steps_ = callback
}

pub fn (mut controller FetchController) set_next_manual_redirect_steps(callback ManualRedirectSteps) {
	controller.next_manual_redirect_steps_ = callback
}

pub fn (controller &FetchController) report_timing() {
	if callback := controller.report_timing_steps_ {
		if info := controller.full_timing_info_ { callback(info) }
	}
}

pub fn (controller &FetchController) process_next_manual_redirect() {
	if callback := controller.next_manual_redirect_steps_ { callback() }
}

pub fn (controller &FetchController) extract_full_timing_info() &FetchTimingInfo {
	return controller.full_timing_info_ or { &FetchTimingInfo{} }
}

pub fn (mut controller FetchController) abort(reason ?string) {
	if controller.state_ != .ongoing { return }
	controller.state_ = .aborted
	controller.serialized_abort_reason_ = reason or { 'AbortError' }
	controller.stop_request()
	if mut inner := controller.inner_controller_ { inner.abort(reason) }
}

pub fn (controller &FetchController) deserialize_a_serialized_abort_reason() string {
	return controller.serialized_abort_reason_ or { 'AbortError' }
}

pub fn (mut controller FetchController) terminate() {
	if controller.state_ == .ongoing { controller.state_ = .terminated }
}

pub fn (mut controller FetchController) stop_fetch() {
	if controller.state_ == .ongoing { controller.state_ = .stopped }
	controller.ongoing_fetch_tasks_.clear()
	controller.stop_request()
}

pub fn (mut controller FetchController) stop_request() {
	controller.pending_request_stopped_ = true
}

pub fn (mut controller FetchController) set_inner_fetch_controller(inner &FetchController) {
	controller.inner_controller_ = inner
}

pub fn (mut controller FetchController) next_fetch_task_id() u64 {
	id := controller.next_fetch_task_id_
	controller.next_fetch_task_id_++
	return id
}

pub fn (mut controller FetchController) fetch_task_queued(fetch_task_id u64, event_id u64) {
	controller.ongoing_fetch_tasks_[fetch_task_id] = event_id
}

pub fn (mut controller FetchController) fetch_task_complete(fetch_task_id u64) {
	controller.ongoing_fetch_tasks_.delete(fetch_task_id)
}

pub fn (controller &FetchController) ongoing_task_count() int {
	return controller.ongoing_fetch_tasks_.len
}

pub struct ConnectionTimingInfo {
pub mut:
	domain_lookup_start     f64
	domain_lookup_end       f64
	connect_start           f64
	connect_end             f64
	secure_connection_start f64
	alpn_negotiated_protocol string
}

// Typed projection of Requests::RequestTimingInfo. Network implementations
// fill these microsecond offsets before handing them to FetchTimingInfo.
pub struct RequestTimingInfo {
pub:
	domain_lookup_start_microseconds i64
	domain_lookup_end_microseconds   i64
	connect_start_microseconds       i64
	connect_end_microseconds         i64
	secure_connect_start_microseconds i64
	request_start_microseconds       i64
	response_start_microseconds      i64
	http_version_alpn_identifier     string
}

@[heap]
pub struct FetchTimingInfo {
pub mut:
	start_time                                f64
	redirect_start_time                       f64
	redirect_end_time                         f64
	post_redirect_start_time                  f64
	final_service_worker_start_time           f64
	final_network_request_start_time          f64
	first_interim_network_response_start_time f64
	final_network_response_start_time         f64
	end_time                                  f64
	final_connection_timing_info              ?ConnectionTimingInfo
	server_timing_headers                     []string
	render_blocking                           bool
}

pub fn FetchTimingInfo.create() &FetchTimingInfo {
	return &FetchTimingInfo{}
}

pub fn create_opaque_timing_info(info &FetchTimingInfo) &FetchTimingInfo {
	return &FetchTimingInfo{
		start_time:               info.start_time
		post_redirect_start_time: info.start_time
	}
}

pub enum PreloadedResponseCandidateKind {
	null_
	pending
	response
}

pub struct PreloadedResponseCandidate {
pub:
	kind     PreloadedResponseCandidateKind
	response ?&Response
}

@[heap]
pub struct FetchParams {
pub mut:
	request                      &Request         = unsafe { nil }
	algorithms                   &FetchAlgorithms = unsafe { nil }
	controller                   &FetchController = unsafe { nil }
	timing_info                  &FetchTimingInfo = unsafe { nil }
	task_destination             string
	cross_origin_isolated        bool
	preloaded_response_candidate PreloadedResponseCandidateKind
	preloaded_response           ?&Response
}

pub fn FetchParams.create(request &Request, timing_info &FetchTimingInfo) &FetchParams {
	return &FetchParams{
		request:     request
		algorithms:  FetchAlgorithms.create(FetchAlgorithmsInput{})
		controller:  FetchController.create()
		timing_info: timing_info
	}
}

pub fn (params &FetchParams) copy() &FetchParams {
	return &FetchParams{
		request:                      params.request
		algorithms:                   params.algorithms
		controller:                   params.controller
		timing_info:                  params.timing_info
		task_destination:             params.task_destination
		cross_origin_isolated:        params.cross_origin_isolated
		preloaded_response_candidate: params.preloaded_response_candidate
		preloaded_response:           params.preloaded_response
	}
}

pub fn (params &FetchParams) is_aborted() bool {
	return params.controller.state() == .aborted
}

pub fn (params &FetchParams) is_canceled() bool {
	return params.controller.state() in [.aborted, .terminated, .stopped]
}

@[heap]
pub struct FetchRecord {
pub mut:
	request          &Request = unsafe { nil }
	fetch_controller ?&FetchController
}

pub fn FetchRecord.create(request &Request, controller ?&FetchController) &FetchRecord {
	return &FetchRecord{
		request:          request
		fetch_controller: controller
	}
}

pub fn (mut record FetchRecord) finalize() {
	if mut controller := record.fetch_controller { controller.stop_fetch() }
}

pub type PendingResponseCallback = fn (&Response)

@[heap]
pub struct PendingResponse {
pub:
	request &Request
mut:
	response_ ?&Response
	callback_ ?PendingResponseCallback
}

pub fn PendingResponse.create(request &Request, response ?&Response) &PendingResponse {
	return &PendingResponse{
		request:   request
		response_: response
	}
}

pub fn (response &PendingResponse) is_resolved() bool {
	return response.response_ != none
}

pub fn (mut pending PendingResponse) when_loaded(callback PendingResponseCallback) {
	pending.callback_ = callback
	if response := pending.response_ {
		callback(response)
		pending.callback_ = none
	}
}

pub fn (mut pending PendingResponse) resolve(response &Response) {
	if pending.response_ != none { return }
	pending.response_ = response
	if callback := pending.callback_ {
		callback(response)
		pending.callback_ = none
	}
}

pub fn (pending &PendingResponse) response() ?&Response {
	return pending.response_
}

@[heap]
pub struct RefCountedFlag {
pub mut:
	value bool
}

pub fn RefCountedFlag.create(value bool) &RefCountedFlag {
	return &RefCountedFlag{
		value: value
	}
}

pub enum NetworkState {
	ongoing
	complete
	error
}

pub enum FetchedDataLifecycle {
	receiving
	complete_pending
	ready_to_close
	closed
	failed
}

@[heap]
pub struct FetchedDataReceiver {
mut:
	fetch_params_    &FetchParams = unsafe { nil }
	response_        ?&Response
	body_            ?&Body
	buffer_          []u8
	pulled_bytes_    int
	lifecycle_state_ FetchedDataLifecycle
	pending_pull_    bool
	pending_promise_ ?FetchedDataPendingPromise
}

pub type FetchedDataPendingPromise = fn ()

pub fn FetchedDataReceiver.create(params &FetchParams) &FetchedDataReceiver {
	return &FetchedDataReceiver{
		fetch_params_: params
	}
}

pub fn (mut receiver FetchedDataReceiver) set_response(response &Response) {
	receiver.response_ = response
}

pub fn (mut receiver FetchedDataReceiver) set_body(body &Body) {
	receiver.body_ = body
	if mut stored_body := receiver.body_ {
		if receiver.buffer_.len > 0 {
			stored_body.append_sniff_bytes(receiver.buffer_)
		}
		if receiver.lifecycle_state_ != .receiving {
			stored_body.set_sniff_bytes_complete()
		}
	}
}

pub fn (mut receiver FetchedDataReceiver) set_pending_pull() {
	receiver.pending_pull_ = true
	receiver.pull_bytes_into_stream()
}

pub fn (mut receiver FetchedDataReceiver) handle_network_bytes(bytes []u8, state NetworkState) {
	if receiver.lifecycle_state_ in [.closed, .failed] { return }
	match state {
		.ongoing {
			receiver.buffer_ << bytes
			if mut body := receiver.body_ { body.append_sniff_bytes(bytes) }
		}
		.complete {
			// Upstream delivers an empty final chunk. Accepting a non-empty
			// final chunk keeps this boundary usable by synchronous hosts and
			// processes those bytes exactly once before completion.
			if bytes.len > 0 {
				receiver.buffer_ << bytes
				if mut body := receiver.body_ { body.append_sniff_bytes(bytes) }
			}
			if mut body := receiver.body_ { body.set_sniff_bytes_complete() }
			receiver.lifecycle_state_ = .complete_pending
		}
		.error {
			receiver.lifecycle_state_ = .failed
			if mut response := receiver.response_ { response.body = none }
		}
	}
	receiver.pull_bytes_into_stream()
}

fn (mut receiver FetchedDataReceiver) pull_bytes_into_stream() {
	if !receiver.pending_pull_ && receiver.pending_promise_ == none { return }
	if !receiver.buffer_is_eof() {
		_ = receiver.copy_unpulled_bytes()
	}
	receiver.pending_pull_ = false
	if callback := receiver.pending_promise_ {
		callback()
		receiver.pending_promise_ = none
	}
	if receiver.lifecycle_state_ == .complete_pending && receiver.buffer_is_eof() {
		receiver.lifecycle_state_ = .ready_to_close
		if receiver.pending_promise_ == none {
			receiver.close_stream()
		}
	}
}

pub fn (mut receiver FetchedDataReceiver) copy_unpulled_bytes() []u8 {
	bytes := receiver.buffer_[receiver.pulled_bytes_..].clone()
	receiver.pulled_bytes_ = receiver.buffer_.len
	return bytes
}

pub fn (receiver &FetchedDataReceiver) lifecycle_state() FetchedDataLifecycle {
	return receiver.lifecycle_state_
}

pub fn cors_check(request &Request, response &Response) bool {
	origin := response.header_list.get('Access-Control-Allow-Origin') or { return false }
	if request.credentials_mode != .include && origin == '*' { return true }
	if request.serialize_origin() != origin { return false }
	if request.credentials_mode != .include { return true }
	return response.header_list.get('Access-Control-Allow-Credentials') or { '' } == 'true'
}

pub fn tao_check(request &Request, response &Response) bool {
	if request.timing_allow_failed { return false }
	values := response.header_list.get_decode_and_split('Timing-Allow-Origin') or { []string{} }
	if '*' in values || request.serialize_origin() in values { return true }
	if request.mode == .navigate {
		if origin := request.origin.origin {
			if request.current_url().origin().value != origin.value { return false }
		}
	}
	return request.response_tainting == .basic
}

pub fn set_sec_fetch_dest_header(mut request Request) {
	value := if destination := request.destination {
		request_destination_to_string(destination)
	} else {
		'empty'
	}
	request.header_list.append(http.Header{ name: 'Sec-Fetch-Dest', value: value })
}

pub fn set_sec_fetch_mode_header(mut request Request) {
	request.header_list.append(http.Header{
		name:  'Sec-Fetch-Mode'
		value: request_mode_to_string(request.mode)
	})
}

pub fn set_sec_fetch_site_header(mut request Request) {
	mut value := 'same-origin'
	for url in request.url_list {
		origin := request.origin.origin or {
			value = 'cross-site'
			break
		}

		if url.origin().value == origin.value { continue
		 }
		value = if request_same_site(url, request.url()) { 'same-site' } else { 'cross-site' }
		if value == 'cross-site' { break
		 }
	}
	request.header_list.append(http.Header{ name: 'Sec-Fetch-Site', value: value })
}

pub fn set_sec_fetch_user_header(mut request Request) {
	if request.is_navigation_request() && request.user_activation {
		request.header_list.append(http.Header{ name: 'Sec-Fetch-User', value: '?1' })
	}
}

pub fn append_fetch_metadata_headers_for_request(mut request Request) {
	if securecontexts.is_url_potentially_trustworthy(request.url()) != .potentially_trustworthy {
		return
	}
	set_sec_fetch_dest_header(mut request)
	set_sec_fetch_mode_header(mut request)
	set_sec_fetch_site_header(mut request)
	set_sec_fetch_user_header(mut request)
}

pub fn default_user_agent_value() string {
	return 'Mozilla/5.0 (LibWeb; Ladybird) AppleWebKit/537.36 (KHTML, like Gecko) Ladybird/1.0 Safari/537.36'
}

pub struct NetworkPartitionKey {
pub:
	top_level_origin string
}

pub fn determine_the_network_partition_key(origin ?dom.Origin) ?NetworkPartitionKey {
	value := origin or { return none }
	if value.value == '' || value.value == 'opaque' { return none }
	return NetworkPartitionKey{
		top_level_origin: value.value
	}
}

pub type FetchHostHook = fn (&Request) !&Response

pub struct FetchHost {
pub:
	perform FetchHostHook @[required]
}

pub fn scheme_fetch(params &FetchParams, host &FetchHost) &PendingResponse {
	request := params.request
	if request.current_url().scheme() == 'data' {
		data := process_data_url(request.current_url()) or {
			return PendingResponse.create(request, Response.network_error(err.msg()))
		}
		mut response := Response.create()
		response.url_list = request.url_list.clone()
		response.body = data.body
		response.header_list.append(http.Header{
			name:  'Content-Type'
			value: data.mime_type.serialized()
		})
		return PendingResponse.create(request, response)
	}
	response := host.perform(request) or { Response.network_error(err.msg()) }
	return PendingResponse.create(request, response)
}

pub fn main_fetch(params &FetchParams, host &FetchHost) &PendingResponse {
	request := params.request
	if params.is_canceled() {
		return PendingResponse.create(request, appropriate_network_error(params))
	}
	if request.local_urls_only && !is_local_url(request.current_url()) {
		return PendingResponse.create(request, Response.network_error('URL is not local'))
	}
	if block_bad_port(request) == .blocked {
		return PendingResponse.create(request, Response.network_error('Bad port'))
	}
	return scheme_fetch(params, host)
}

pub fn populate_request_from_client(mut request Request) {
	if request.origin.is_client {
		if client_url := request.client_document_url {
			request.origin = RequestOrigin{
				is_client: false
				origin:    client_url.origin()
			}
		} else if creation_url := request.client_creation_url {
			request.origin = RequestOrigin{
				is_client: false
				origin:    creation_url.origin()
			}
		}
	}
	if request.referrer_policy == '' { request.referrer_policy = 'strict-origin-when-cross-origin' }
}

pub fn fetch_response_handover(params &FetchParams, response &Response) {
	algorithms := params.algorithms.input
	if callback := algorithms.process_response { callback(response) }
	if callback := algorithms.process_response_consume_body {
		callback(response, if bytes := response.body {
			BodyBytes{
				kind:  .bytes
				bytes: bytes.clone()
			}
		} else {
			BodyBytes{
				kind: .empty
			}
		})
	}
	if callback := algorithms.process_response_end_of_body { callback(response) }
}

pub fn http_network_or_cache_fetch(params &FetchParams, host &FetchHost) &PendingResponse {
	return scheme_fetch(params, host)
}

pub fn nonstandard_resource_loader_file_or_http_network_fetch(params &FetchParams, host &FetchHost) &PendingResponse {
	return scheme_fetch(params, host)
}

pub fn cors_preflight_fetch(request &Request, host &FetchHost) &PendingResponse {
	mut preflight := request.clone()
	preflight.method = 'OPTIONS'
	preflight.body = RequestBody{}
	preflight.header_list = http.HeaderList.create()
	preflight.header_list.append(http.Header{ name: 'Accept', value: '*/*' })
	preflight.header_list.append(http.Header{
		name:  'Access-Control-Request-Method'
		value: request.method
	})
	unsafe_names := get_cors_unsafe_header_names(request.header_list)
	if unsafe_names.len > 0 {
		preflight.header_list.append(http.Header{
			name:  'Access-Control-Request-Headers'
			value: unsafe_names.join(',')
		})
	}
	response := host.perform(preflight) or { Response.network_error(err.msg()) }
	if response.is_network_error() || !cors_check(request, response) {
		return PendingResponse.create(request,
			Response.network_error('CORS-preflight check failed'))
	}
	return PendingResponse.create(request, response)
}

pub fn http_fetch(params &FetchParams, host &FetchHost, make_cors_preflight bool) &PendingResponse {
	if make_cors_preflight || params.request.use_cors_preflight {
		return cors_preflight_fetch(params.request, host)
	}
	return http_network_or_cache_fetch(params, host)
}

fn remove_request_headers(mut request Request, names []string) {
	mut list := http.HeaderList.create()
	for header in request.header_list.headers() {
		if !names.any(equals_ignoring_ascii_case(it, header.name)) { list.append(header) }
	}
	request.header_list = list
}

pub fn http_redirect_fetch(params &FetchParams, response &Response, host &FetchHost) &PendingResponse {
	mut request := params.request
	location_result := response.location_url(request.current_url().fragment()) or {
		return PendingResponse.create(request, Response.network_error(err.msg()))
	}
	mut location := location_result.url or { return PendingResponse.create(request, response) }
	if request.redirect_mode == .error {
		return PendingResponse.create(request, Response.network_error('Redirect mode is error'))
	}
	if request.redirect_mode == .manual {
		return PendingResponse.create(request, filtered_response(response, .opaque_redirect))
	}
	if request.redirect_count >= 20 {
		return PendingResponse.create(request, Response.network_error('Redirect count exceeded'))
	}
	request.redirect_count++
	if location.fragment() == none { location.set_fragment(request.current_url().fragment()) }
	if ((response.status == 301 || response.status == 302) && request.method == 'POST')
		|| (response.status == 303 && request.method !in ['GET', 'HEAD']) {
		request.method = 'GET'
		request.body = RequestBody{}
		remove_request_headers(mut request, ['Content-Encoding', 'Content-Language',
			'Content-Location', 'Content-Type'])
	}
	if location.origin().value != request.current_url().origin().value {
		remove_request_headers(mut request, ['Authorization', 'Proxy-Authorization', 'Cookie',
			'Host'])
	}
	request.url_list << location
	return main_fetch(params, host)
}

pub struct IncrementalReadLoopReadRequest {
pub:
	body          &Body
	process_chunk BodyChunkCallback @[required]
	process_end   BodyEndCallback   @[required]
	process_error BodyErrorCallback @[required]
}

pub fn (request &IncrementalReadLoopReadRequest) on_chunk(chunk []u8) {
	request.process_chunk(chunk.clone())
}

pub fn (request &IncrementalReadLoopReadRequest) on_close() {
	request.process_end()
}

pub fn (request &IncrementalReadLoopReadRequest) on_error(reason string) {
	request.process_error(reason)
}

pub fn fetch(request &Request, algorithms &FetchAlgorithms, host &FetchHost) &FetchController {
	timing := FetchTimingInfo.create()
	mut params := FetchParams.create(request, timing)
	params.algorithms = algorithms
	mut controller := params.controller
	controller.set_full_timing_info(timing)
	pending := main_fetch(params, host)
	if response := pending.response() {
		if callback := algorithms.input.process_response { callback(response) }
		if callback := algorithms.input.process_response_consume_body {
			callback(response, if bytes := response.body {
				BodyBytes{
					kind:  .bytes
					bytes: bytes.clone()
				}
			} else {
				BodyBytes{
					kind: .empty
				}
			})
		}
		if callback := algorithms.input.process_response_end_of_body { callback(response) }
	}
	return controller
}

pub fn appropriate_network_error(params &FetchParams) &Response {
	return if params.is_aborted() {
		Response.aborted_network_error()
	} else {
		Response.network_error('Fetch has been terminated')
	}
}

pub fn queue_fetch_task(algorithm fn ()) u64 {
	id := fetch_next_task_id
	fetch_next_task_id++
	algorithm()
	return id
}

pub fn queue_fetch_task_for_controller(mut controller FetchController, algorithm fn ()) u64 {
	fetch_task_id := controller.next_fetch_task_id()
	event_id := queue_fetch_task(algorithm)
	controller.fetch_task_queued(fetch_task_id, event_id)
	controller.fetch_task_complete(fetch_task_id)
	return event_id
}

pub fn set_http_memory_cache_enabled(enabled bool) {
	fetch_http_memory_cache_enabled = enabled
}

pub fn http_memory_cache_enabled() bool {
	return fetch_http_memory_cache_enabled
}

pub fn clear_http_memory_cache() {
	fetch_http_memory_cache.clear()
}
