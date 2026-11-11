// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Fetching/* and the Fetch infrastructure controller/params,
// timing, task, network-partition, and fetch-record units. Platform network,
// cache, cookie, and event-loop delivery enter through FetchHost.
@[has_globals]
module fetch

import dom
import fileapi
import libjs
import url as liburl
import highresolutiontime
import http
import securecontexts
import referrercore
import sri
import streams
import strconv
import time

struct FetchMemoryCacheEntry {
	response_token   u64
	vary_key         string
	status_code      u16
	reason_phrase    string
	request_headers  &http.HeaderList
	response_headers &http.HeaderList
	request_time     i64
	response_time    i64
mut:
	last_access_time                   i64
	response_body                      []u8
	javascript_bytecode_cache          ?[]u8
	javascript_bytecode_cache_vary_key ?u64
}

__global (
	fetch_http_memory_cache_enabled  = true
	fetch_http_memory_cache_next_response_token = u64(1)
	fetch_next_task_id               = u64(1)
	fetch_http_memory_cache_pending  = map[string][]FetchMemoryCacheEntry{}
	fetch_http_memory_cache_complete = map[string][]FetchMemoryCacheEntry{}
	fetch_parallel_queue_factory FetchParallelQueueFactory
	fetch_default_user_agent_provider DefaultUserAgentProvider
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

pub enum CreateResponseBodyTransferLease {
	no
	yes
}

pub enum UseParallelQueue {
	no
	yes
}

pub type FetchParallelQueueFactory = fn () FetchTaskDestinationProvider

// Fetch cannot import HTML, so the actual Window/Worker global owns creation,
// queuing and buffering of the source PerformanceResourceTiming object.
pub interface FetchTimingReportDestination {
	fetch_timing_global_identity() voidptr
	fetch_mark_resource_timing(&FetchTimingInfo, string, string, ?CacheState, BodyInfo, u16)
}

pub type ReportTimingSteps = fn (?FetchTimingReportDestination)

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
	fetch_params_               ?&FetchParams
	pending_request_            ?&Request
	pending_network_request_    ?RequestServerRequest
	pending_preloaded_response_ ?&PendingResponse
	requires_network_           bool
	has_started_request_        bool
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

pub fn (controller &FetchController) has_report_timing_steps() bool {
	return controller.report_timing_steps_ != none
}

pub fn (mut controller FetchController) set_next_manual_redirect_steps(callback ManualRedirectSteps) {
	controller.next_manual_redirect_steps_ = callback
}

pub fn (controller &FetchController) report_timing() {
	callback := controller.report_timing_steps_ or {
		panic('FetchController.report_timing called without report timing steps')
	}
	global := if params := controller.fetch_params_ { params.reporting_global } else { ?FetchTimingReportDestination(none) }
	callback(global)
}

pub fn (controller &FetchController) report_timing_with_global(global FetchTimingReportDestination) {
	callback := controller.report_timing_steps_ or {
		panic('FetchController.report_timing called without report timing steps')
	}
	callback(global)
}

pub fn (controller &FetchController) process_next_manual_redirect() {
	callback := controller.next_manual_redirect_steps_ or {
		panic('FetchController.process_next_manual_redirect called without redirect steps')
	}
	callback()
}

pub fn (controller &FetchController) extract_full_timing_info() &FetchTimingInfo {
	return controller.full_timing_info_ or {
		panic('FetchController.extract_full_timing_info called without full timing info')
	}
}

pub fn (mut controller FetchController) abort(reason ?string) {
	controller.state_ = .aborted
	controller.serialized_abort_reason_ = reason or { 'AbortError' }
	controller.stop_request()
}

pub fn (controller &FetchController) serialized_abort_reason() ?string {
	return controller.serialized_abort_reason_
}

pub fn deserialize_serialized_abort_reason(controller &FetchController) string {
	return controller.serialized_abort_reason() or { 'AbortError' }
}

pub fn (controller &FetchController) deserialize_a_serialized_abort_reason() string {
	return deserialize_serialized_abort_reason(controller)
}

pub fn (mut controller FetchController) terminate() {
	controller.state_ = .terminated
	controller.stop_request()
}

pub fn (mut controller FetchController) stop_fetch() {
	if controller.state_ in [.aborted, .terminated] {
		return
	}
	controller.state_ = .stopped
	if params := controller.fetch_params_ {
		if destination := params.task_destination_provider {
			for _, task_id in controller.ongoing_fetch_tasks_ { destination.fetch_request_client_cancel_fetch_task(task_id) }
		}
	}
	controller.ongoing_fetch_tasks_.clear()
	if mut params := controller.fetch_params_ {
		params.algorithms = FetchAlgorithms.create(FetchAlgorithmsInput{})
	}
	controller.stop_request()
}

pub fn (mut controller FetchController) stop_request() {
	assert controller.state_ != .ongoing
	controller.pending_request_stopped_ = true
	controller.pending_request_ = none
	if request := controller.pending_network_request_ {
		controller.pending_network_request_ = none
		if stop := request.stop { stop() }
	}
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
	domain_lookup_start      f64
	domain_lookup_end        f64
	connect_start            f64
	connect_end              f64
	secure_connection_start  f64
	alpn_negotiated_protocol string
}

// Typed projection of Requests::RequestTimingInfo. Network implementations
// fill these microsecond offsets before handing them to FetchTimingInfo.
pub struct RequestTimingInfo {
pub:
	domain_lookup_start_microseconds  i64
	domain_lookup_end_microseconds    i64
	connect_start_microseconds        i64
	connect_end_microseconds          i64
	secure_connect_start_microseconds i64
	request_start_microseconds        i64
	response_start_microseconds       i64
	http_version_alpn_identifier      string
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
		end_time:                 info.end_time
		render_blocking:          info.render_blocking
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
	request                          &Request         = unsafe { nil }
	algorithms                       &FetchAlgorithms = unsafe { nil }
	controller                       &FetchController = unsafe { nil }
	timing_info                      &FetchTimingInfo = unsafe { nil }
	task_destination                 string
	task_destination_provider        ?FetchTaskDestinationProvider
	task_destination_global_identity voidptr
	reporting_global                 ?FetchTimingReportDestination
	cross_origin_isolated            bool
	preloaded_response_candidate     PreloadedResponseCandidateKind
	preloaded_response               ?&Response
	has_response_body_transfer_lease bool
}

pub fn FetchParams.create(request &Request, timing_info &FetchTimingInfo) &FetchParams {
	mut controller := FetchController.create()
	mut params := &FetchParams{
		request:     request
		algorithms:  FetchAlgorithms.create(FetchAlgorithmsInput{})
		controller:  controller
		timing_info: timing_info
	}
	if client := request.client {
		if client is FetchTaskDestinationProvider { params.task_destination_provider = client }
		if client is FetchTimingReportDestination {
			params.reporting_global = client
			params.task_destination_global_identity = client.fetch_timing_global_identity()
		}
	}
	controller.set_fetch_params(params)
	return params
}

pub fn (params &FetchParams) copy() &FetchParams {
	return &FetchParams{
		request:                          params.request
		algorithms:                       params.algorithms
		controller:                       params.controller
		timing_info:                      params.timing_info
		task_destination:                 params.task_destination
		task_destination_provider:        params.task_destination_provider
		task_destination_global_identity: params.task_destination_global_identity
		reporting_global:                 params.reporting_global
		cross_origin_isolated:            params.cross_origin_isolated
		preloaded_response_candidate:     params.preloaded_response_candidate
		preloaded_response:               params.preloaded_response
		has_response_body_transfer_lease: params.has_response_body_transfer_lease
	}
}

pub fn (params &FetchParams) is_aborted() bool {
	return params.controller.state() == .aborted
}

pub fn (params &FetchParams) is_canceled() bool {
	return params.controller.state() in [.aborted, .terminated]
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

pub fn (mut _ FetchRecord) finalize() {
	// The C++ finalizer only removes the record's intrusive-list node. V does
	// not use that list, so there is no controller action to perform here.
}

pub type PendingResponseCallback = fn (&Response)

@[heap]
pub struct PendingResponse {
pub:
	request &Request
mut:
	response_            ?&Response
	callback_            ?PendingResponseCallback
	callback_registered_ bool
}

pub fn PendingResponse.create(mut request Request, response ?&Response) &PendingResponse {
	pending := &PendingResponse{
		request:   request
		response_: response
	}
	request.add_pending_response(pending)
	return pending
}

pub fn (response &PendingResponse) is_resolved() bool {
	return response.response_ != none
}

pub fn (mut pending PendingResponse) when_loaded(callback PendingResponseCallback) {
	assert !pending.callback_registered_
	pending.callback_registered_ = true
	pending.callback_ = callback
	if pending.response_ != none {
		pending.run_callback()
	}
}

pub fn (mut pending PendingResponse) resolve(response &Response) {
	assert pending.response_ == none
	pending.response_ = response
	if pending.callback_ != none {
		pending.run_callback()
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

pub struct NetworkResponseData {
pub:
	bytes                       []u8
	immutable_bytes             ?[]u8
	immutable_bytes_file_backed bool
}

pub fn NetworkResponseData.from_bytes(bytes []u8) NetworkResponseData {
	return NetworkResponseData{
		bytes: bytes.clone()
	}
}

pub fn NetworkResponseData.from_file_backed_bytes(bytes []u8) NetworkResponseData {
	return NetworkResponseData{
		bytes:                       bytes.clone()
		immutable_bytes:             bytes.clone()
		immutable_bytes_file_backed: true
	}
}

const maximum_pending_bytes = 5 * 1024 * 1024

@[heap]
pub struct FetchedDataReceiver {
mut:
	fetch_params_                      ?&FetchParams
	stream_                            &streams.ReadableStream = unsafe { nil }
	response_                          ?&Response
	body_                              ?&Body
	cache_enabled_                     bool
	pre_body_sniff_buffer_             []u8
	cache_buffer_                      []u8
	cache_body_                        ?[]u8
	cache_body_replaces_network_buffer bool
	network_complete_                  bool
	network_request_                   ?RequestServerRequest
	pending_bytes_                     []u8
	delivery_task_queued_              bool
	paused_network_delivery_           bool
}

pub fn FetchedDataReceiver.create(params &FetchParams, stream &streams.ReadableStream) &FetchedDataReceiver {
	mut receiver := &FetchedDataReceiver{
		fetch_params_:  params
		stream_:        stream
		cache_enabled_: fetch_http_memory_cache_enabled && params.request.cache_mode != .no_store
			&& determine_the_http_cache_partition(params.request) != none
	}
	mut mutable_stream := unsafe { stream }
	mut controller := mutable_stream.byte_controller() or {
		panic('FetchedDataReceiver requires a readable byte stream')
	}
	controller.set_pull_algorithm(fn () ! {})
	controller.set_cancel_algorithm(fn [mut receiver] (reason streams.Value) ! {
		receiver.retire_cache_storage()
		if current_params := receiver.fetch_params_ {
			mut fetch_controller := current_params.controller
			fetch_controller.abort(reason.description())
		}
	})
	return receiver
}

pub fn FetchedDataReceiver.create_for_stream(stream &streams.ReadableStream) &FetchedDataReceiver {
	return &FetchedDataReceiver{
		stream_: stream
	}
}

pub fn (mut receiver FetchedDataReceiver) set_response(response &Response) {
	receiver.response_ = response
	// The public response view stays read-only; enrollment is private runtime
	// state owned by the producer and its receiver.
	mut internal := unsafe { response.cache_storage_response() }
	internal.cache_body_pending_ = true
	if !receiver.cache_enabled_ {
		internal.retire_cache_storage()
	}
}

pub fn (mut receiver FetchedDataReceiver) set_body(body &Body) {
	assert voidptr(body.stream()) == voidptr(receiver.stream_)
	receiver.body_ = body
	if mut stored_body := receiver.body_ {
		if receiver.pre_body_sniff_buffer_.len > 0 {
			stored_body.append_sniff_bytes(receiver.pre_body_sniff_buffer_)
			receiver.pre_body_sniff_buffer_.clear()
		}
		if receiver.network_complete_ {
			stored_body.set_sniff_bytes_complete()
		}
	}
}

pub fn (mut receiver FetchedDataReceiver) set_network_request(request ?RequestServerRequest) {
	receiver.network_request_ = request
}

pub fn (mut receiver FetchedDataReceiver) handle_network_data(data NetworkResponseData, state NetworkState) {
	if state == .complete {
		assert data.bytes.len == 0
		receiver.network_complete_ = true
		if mut body := receiver.body_ {
			body.set_sniff_bytes_complete()
		}
		receiver.queue_delivery_task()
		return
	}
	if state == .error {
		receiver.retire_cache_storage()
		return
	}
	if data.bytes.len == 0 {
		return
	}
	bytes := data.bytes
	if mut body := receiver.body_ {
		if immutable_bytes := data.immutable_bytes {
			if data.immutable_bytes_file_backed && body.body_source() in [.empty, .readable_stream]
				&& bytes.len == immutable_bytes.len {
				body.set_source(immutable_bytes, u64(immutable_bytes.len))
			}
		}
		body.append_sniff_bytes(bytes)
	} else if receiver.pre_body_sniff_buffer_.len < 1445 {
		space_remaining := 1445 - receiver.pre_body_sniff_buffer_.len
		to_append := if bytes.len < space_remaining { bytes.len } else { space_remaining }
		receiver.pre_body_sniff_buffer_ << bytes[..to_append]
	}
	if receiver.cache_enabled_ && !receiver.cache_body_replaces_network_buffer {
		if immutable_bytes := data.immutable_bytes {
			if data.immutable_bytes_file_backed && receiver.cache_buffer_.len == 0
				&& receiver.cache_body_ == none {
				receiver.cache_body_ = immutable_bytes.clone()
			} else {
				receiver.append_to_cache_buffer(bytes)
			}
		} else {
			receiver.append_to_cache_buffer(bytes)
		}
	}
	receiver.pending_bytes_ << bytes
	if receiver.pending_bytes_.len >= maximum_pending_bytes && !receiver.paused_network_delivery_ {
		if request := receiver.network_request_ {
			if set_paused := request.set_body_delivery_paused {
				set_paused(true)
				receiver.paused_network_delivery_ = true
			}
		}
	}
	receiver.queue_delivery_task()
}

pub fn cors_check(request &Request, response &Response) bool {
	origin := response.header_list.get('Access-Control-Allow-Origin') or { return false }
	if request.credentials_mode != .include && origin == '*' {
		return true
	}
	if request.serialize_origin() != origin {
		return false
	}
	if request.credentials_mode != .include {
		return true
	}
	return response.header_list.get('Access-Control-Allow-Credentials') or { '' } == 'true'
}

pub fn tao_check(request &Request, response &Response) bool {
	if request.timing_allow_failed {
		return false
	}
	values := response.header_list.get_decode_and_split('Timing-Allow-Origin') or { []string{} }
	if '*' in values || request.serialize_origin() in values {
		return true
	}
	if request.mode == .navigate {
		if origin := request.origin.origin {
			if !request.current_url().origin().is_same_origin(origin) {
				return false
			}
		}
	}
	return request.response_tainting == .basic
}

// https://fetch.spec.whatwg.org/#navigation-tao-check
pub fn navigation_tao_check(response &Response, destination_origin dom.Origin) bool {
	serialized_origin := destination_origin.serialize()
	for tao_values in response.navigation_timing_allow_values_list() {
		if '*' in tao_values || serialized_origin in tao_values {
			continue
		}
		return false
	}
	return true
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

		if url.origin().is_same_origin(origin) {
			continue
		}
		value = if request_same_site(url, request.url()) { 'same-site' } else { 'cross-site' }
		if value == 'cross-site' {
			break
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

// ResourceLoader installs the browser's URL-sensitive identity without adding
// a Fetch -> Loader import cycle. Standalone Fetch users retain their default.
pub type DefaultUserAgentProvider = fn (dom.URL) string

pub fn install_default_user_agent_provider(provider DefaultUserAgentProvider) {
	fetch_default_user_agent_provider = provider
}

pub fn default_user_agent_for_url(url dom.URL) string {
	if fetch_default_user_agent_provider != unsafe { nil } {
		return fetch_default_user_agent_provider(url)
	}
	return default_user_agent_value()
}

pub struct NetworkPartitionKey {
pub:
	// Upstream keeps the URL::Origin itself in the partition key. Keeping the
	// typed origin is important: two opaque origins serialize for the web as
	// `null`, but their nonces still make them distinct partition keys.
	top_level_origin dom.Origin
}

pub fn determine_the_network_partition_key(origin ?dom.Origin) ?NetworkPartitionKey {
	value := origin or { return none }
	return NetworkPartitionKey{
		top_level_origin: value
	}
}

pub type FetchHostHook = fn (&Request) !&Response

pub type FetchHostParamsHook = fn (&FetchParams, &Request) &PendingResponse

pub type FetchAsyncHostHook = fn (&Request) &PendingResponse

pub struct FetchHost {
pub:
	perform             FetchHostHook @[required]
	// The real ResourceLoader callbacks need the shared controller, timing info
	// and FetchedDataReceiver task destination, not a detached request shadow.
	perform_async_with_params ?FetchHostParamsHook
	perform_async       ?FetchAsyncHostHook
	preferred_languages []string = ['en-US']
}

fn perform_host_fetch(params &FetchParams, request &Request, host &FetchHost) &PendingResponse {
	mut filtered_request := unsafe { &Request(request) }
	if response := filtered_request.apply_adblock() { return PendingResponse.create(mut filtered_request, response) }
	mut pending := if perform := host.perform_async_with_params {
		perform(params, request)
	} else if perform := host.perform_async {
		perform(request)
	} else {
		response := host.perform(request) or { Response.network_error(err.msg()) }
		PendingResponse.create(mut filtered_request, response)
	}
	if response := pending.response() {
		return PendingResponse.create(mut filtered_request, request.apply_adblock_response(response))
	}
	result := PendingResponse.create(mut filtered_request, none)
	pending.when_loaded(fn [request, result] (response &Response) {
		mut target := unsafe { &PendingResponse(result) }
		target.resolve(request.apply_adblock_response(response))
	})
	return result
}

// Source Fetching.cpp:768 and 1016: these adapters retain the actual request
// owners and query their current origin; they do not capture a partition key.
struct BlobURLFetchClientOwner {
	client RequestClient @[required]
}

fn (owner &BlobURLFetchClientOwner) blob_url_partition_origin() liburl.Origin {
	return owner.client.fetch_request_client_origin().liburl_origin() or {
		panic('Source Blob Fetch client requires an actual typed Origin')
	}
}

struct BlobURLFetchReservedClientOwner {
	client RequestReservedClient @[required]
}

fn (owner &BlobURLFetchReservedClientOwner) blob_url_partition_origin() liburl.Origin {
	return owner.client.fetch_request_environment_blob_url_origin()
}

fn obtain_request_blob_snapshot(request &Request, entry liburl.BlobURLEntry) !&fileapi.Blob {
	mut access := fileapi.BlobURLObtainEnvironment(fileapi.TopLevelNavigation{})
	is_document_navigation := if destination := request.destination { destination == .document } else { false }
	if !is_document_navigation {
		// The chosen Environment's creation URL may differ from the client's.
		creation_url := if reserved := request.reserved_client {
			reserved.fetch_request_environment_creation_url()
		} else if client := request.client {
			client.fetch_request_client_creation_url()
		} else {
			return error('Request is missing fetch client')
		}
		is_self_fetch := if client := request.client {
			client.fetch_request_client_is_window()
				&& client.fetch_request_client_is_top_level_window()
				&& creation_url == request.current_url()
		} else {
			false
		}
		if is_self_fetch {
			access = fileapi.BlobURLObtainEnvironment(fileapi.TopLevelSelfFetch{})
		} else if reserved := request.reserved_client {
			access = fileapi.BlobURLObtainEnvironment(fileapi.BlobURLRequestEnvironment{
				environment: &BlobURLFetchReservedClientOwner{
					client: reserved
				}
			})
		} else if client := request.client {
			access = fileapi.BlobURLObtainEnvironment(fileapi.BlobURLRequestEnvironment{
				environment: &BlobURLFetchClientOwner{
					client: client
				}
			})
		}
	}
	object := fileapi.obtain_a_blob_object(entry, access) or {
		return error("Failed to obtain a Blob object from 'blob:' URL")
	}
	if object is liburl.BlobURLBlob {
		// Blob.h's String overload calls AK's unvalidated UTF8 conversion.
		return fileapi.Blob.create_utf16(object.data,
			libjs.utf16_string_from_utf8_without_validation(object.type_))
	}
	return error("Failed to obtain a Blob object from 'blob:' URL")
}

// Standalone string fixtures keep their separate Legacy store boundary.
fn obtain_legacy_request_blob(request &Request) !&fileapi.Blob {
	entry := fileapi.resolve_a_legacy_blob_url(request.current_url().serialize()) or {
		return error("Request has an invalid 'blob:' URL")
	}
	if request.method != 'GET' {
		return error("Request has an invalid 'blob:' URL")
	}

	is_document_navigation := if destination := request.destination {
		destination == .document
	} else {
		false
	}
	is_creation_url_self_fetch := if creation_url := request.client_creation_url {
		creation_url == request.current_url()
	} else {
		false
	}
	access := if is_document_navigation {
		fileapi.LegacyBlobURLObtainEnvironment(fileapi.TopLevelNavigation{})
	} else if request.client_present && request.client_is_window
		&& request.client_is_top_level_window && is_creation_url_self_fetch {
		fileapi.LegacyBlobURLObtainEnvironment(fileapi.TopLevelSelfFetch{})
	} else {
		mut environment := fileapi.LegacyBlobURLEnvironment{}
		if reserved_client := request.reserved_client {
			creation_url := reserved_client.fetch_request_environment_creation_url()
			environment = fileapi.LegacyBlobURLEnvironment{
				id:          creation_url.serialize()
				origin:      creation_url.origin().serialize()
				storage_key: creation_url.origin().serialize_for_ipc()
			}
		} else if client := request.client {
			origin := client.fetch_request_client_origin()
			environment = fileapi.LegacyBlobURLEnvironment{
				id:          client.fetch_request_client_creation_url().serialize()
				origin:      origin.serialize()
				storage_key: origin.serialize_for_ipc()
			}
		} else {
			return error('Request is missing fetch client')
		}
		fileapi.LegacyBlobURLObtainEnvironment(environment)
	}
	object := fileapi.obtain_a_legacy_blob_object(entry, access) or {
		return error("Failed to obtain a Blob object from 'blob:' URL")
	}
	blob := object.blob or { return error("Failed to obtain a Blob object from 'blob:' URL") }

	return blob
}

pub fn scheme_fetch(params &FetchParams, host &FetchHost) &PendingResponse {
	mut request := params.request
	if params.is_canceled() {
		return PendingResponse.create(mut request, appropriate_network_error(params))
	}
	scheme := request.current_url().scheme()
	if scheme == 'about' && request.current_url().serialize_path() == 'blank' {
		mut response := Response.create()
		response.status_message = 'OK'
		response.header_list.append(http.Header{
			name:  'Content-Type'
			value: 'text/html;charset=utf-8'
		})
		response.set_body_bytes([]u8{})
		return PendingResponse.create(mut request, response)
	}
	if request.current_url().scheme() == 'data' {
		data := process_data_url(request.current_url()) or {
			return PendingResponse.create(mut request, Response.network_error(err.msg()))
		}
		mut response := Response.create()
		response.url_list = request.url_list.clone()
		response.status_message = 'OK'
		response.set_body_bytes(data.body)
		response.header_list.append(http.Header{
			name:  'Content-Type'
			value: data.mime_type.serialized()
		})
		return PendingResponse.create(mut request, response)
	}
	if scheme == 'blob' {
		if request.method != 'GET' {
			return PendingResponse.create(mut request,
				Response.network_error("Request has an invalid 'blob:' URL"))
		}
		current := request.current_url().parsed() or {
			return PendingResponse.create(mut request,
				Response.network_error("Request has an invalid 'blob:' URL"))
		}
		snapshot := current.blob_url_entry()
		blob := if entry := snapshot {
			obtain_request_blob_snapshot(request, entry) or {
				return PendingResponse.create(mut request, Response.network_error(err.msg()))
			}
		} else {
			obtain_legacy_request_blob(request) or {
				return PendingResponse.create(mut request, Response.network_error(err.msg()))
			}
		}
		content_type := if snapshot != none {
			http.Header.isomorphic_encode_utf16('Content-Type', blob.type_utf16()).value
		} else {
			// Retain the standalone Legacy adapter's byte-string boundary.
			blob.type_()
		}
		mut response := Response.create()
		bytes := blob.raw_bytes()
		if range_header := request.header_list.get('Range') {
			range_value := parse_single_range_header_value(range_header, true) or {
				return PendingResponse.create(mut request, Response.network_error('Failed to parse single range header value'))
			}
			full_length := u64(bytes.len)
			mut range_start := range_value.start
			mut range_end := range_value.end
			if start := range_start {
				if start >= full_length {
					return PendingResponse.create(mut request, Response.network_error('rangeStart is greater than or equal to fullLength'))
				}
				if end := range_end {
					if end >= full_length {
						range_end = full_length - 1
					}
				} else {
					range_end = full_length - 1
				}
			} else {
				suffix_length := range_end or {
					return PendingResponse.create(mut request, Response.network_error('Invalid empty byte range'))
				}
				range_start = if suffix_length >= full_length {
					u64(0)
				} else {
					full_length - suffix_length
				}
				range_end = full_length - 1
			}
			start := range_start or { u64(0) }
			end := range_end or { full_length - 1 }
			response.set_body_bytes(bytes[int(start)..int(end + 1)])
			response.status = 206
			response.status_message = 'Partial Content'
			response.range_requested = true
			response.header_list.append(http.Header{ name: 'Content-Length', value: '${end - start + 1}' })
			response.header_list.append(http.Header{ name: 'Content-Type', value: content_type })
			response.header_list.append(http.Header{ name: 'Content-Range', value: 'bytes ${start}-${end}/${full_length}' })
		} else {
			response.status_message = 'OK'
			response.set_body_bytes(bytes)
			response.header_list.append(http.Header{ name: 'Content-Length', value: '${bytes.len}' })
			response.header_list.append(http.Header{ name: 'Content-Type', value: content_type })
		}
		return PendingResponse.create(mut request, response)
	}
	if scheme in ['http', 'https'] {
		return http_fetch(params, host, false)
	}
	if scheme in ['file', 'resource'] {
		origin := request.origin.origin or {
			return PendingResponse.create(mut request, Response.network_error("Request with 'file:' or 'resource:' URL blocked"))
		}
		if (!origin.is_opaque() && !origin.serialize().starts_with('file:') && !origin.serialize().starts_with('resource:'))
			|| request.destination == none {
			return PendingResponse.create(mut request, Response.network_error("Request with 'file:' or 'resource:' URL blocked"))
		}
		return nonstandard_resource_loader_file_or_http_network_fetch(params, host)
	}
	if scheme == 'about' {
		return nonstandard_resource_loader_file_or_http_network_fetch(params, host)
	}
	message := if scheme == 'about' {
		"Request has invalid 'about:' URL, only 'about:blank' can be fetched"
	} else {
		"Request URL has invalid scheme, must be one of 'about', 'blob', 'data', 'file', 'http', or 'https'"
	}
	return PendingResponse.create(mut request, Response.network_error(message))
}

pub fn main_fetch(params &FetchParams, host &FetchHost) &PendingResponse {
	mut request := params.request
	mut response := ?&Response(none)
	mut pending_response := ?&PendingResponse(none)
	mut clear_preflight_cache_on_error := false
	if request.local_urls_only && !is_local_url(request.current_url()) {
		response = Response.network_error('Request with local-URLs-only flag must have a local URL')
	}
	if apply_request_security_policies(mut request) {
		response = Response.network_error('Request was blocked')
	}
	if response == none {
		for attempt in 0 .. 8 {
			original_url := request.current_url().serialize()
			candidate := request.apply_adblock()
			rewritten_url := request.current_url().serialize()
			// Security policy must inspect the URL that will actually be fetched.
			// It can also upgrade an insecure rewritten URL, which then needs a
			// fresh filtering decision before a preload or cache may be reused.
			if rewritten_url != original_url && apply_request_security_policies(mut request) {
				response = Response.network_error('Request was blocked')
				break
			}
			if request.current_url().serialize() != rewritten_url {
				if attempt == 7 { response = Response.network_error('Adblock security-policy rewrite limit exceeded') }
				continue
			}
			if filtered_response := candidate { response = filtered_response }
			break
		}
	}
	// 8. If request's referrer policy is the empty string, then set request's referrer policy to request's policy
	//    container's referrer policy.
	if request.referrer_policy == '' {
		policy_container := request.resolved_policy_container or { RequestPolicyContainer{} }
		request.referrer_policy = policy_container.referrer_policy
	}
	// Fetching.cpp main fetch step 9. Redirects re-enter this step with the
	// response-selected policy, so an already reduced referrer never expands.
	if request.referrer.url != none || request.referrer.sentinel != .no_referrer {
		request.referrer = if determined := referrercore.determine_requests_referrer(request.referrer_policy,
			request.referrer_source(), request.current_url())
		{
			Referrer{
				url: determined
			}
		} else {
			Referrer{
				sentinel: .no_referrer
			}
		}
	}
	if response == none && params.preloaded_response_candidate == .pending {
		mut controller := params.controller
		if pending := controller.pending_preloaded_response() {
			return pending
		}
		pending := PendingResponse.create(mut request, none)
		controller.set_pending_preloaded_response(pending)
		return pending
	}
	if response == none {
		if preloaded := params.preloaded_response {
			response = preloaded
		} else {
			origin := request.origin.origin
			is_same_origin := if request_origin := origin {
				request.current_url().origin().is_same_origin(request_origin)
			} else {
				false
			}
			is_file_to_file_font_load := if request_origin := origin {
				is_font := if destination := request.destination { destination == .font } else { false }
				request_origin.is_opaque_file_origin() && request.current_url().scheme() == 'file'
					&& is_font
			} else { false }
			if (is_same_origin && request.response_tainting == .basic) || is_file_to_file_font_load || request.current_url().scheme() == 'data' || request.mode in [
				.navigate,
				.websocket,
			] {
				request.response_tainting = .basic
				pending_response = scheme_fetch(params, host)
			} else if request.mode == .same_origin {
				response = Response.network_error("Request with 'same-origin' mode must have same URL and request origin")
			} else if request.mode == .no_cors {
				if request.redirect_mode != .follow {
					response = Response.network_error("Request with 'no-cors' mode must have redirect mode set to 'follow'")
				} else {
					request.response_tainting = .opaque
					pending_response = scheme_fetch(params, host)
				}
			} else if request.current_url().scheme() !in ['http', 'https'] {
				response = Response.network_error("Request with 'cors' mode must have URL with HTTP or HTTPS scheme")
			} else {
				request.response_tainting = .cors
				make_preflight := request.use_cors_preflight || (request.unsafe_request && (!http.is_cors_safelisted_method(request.method) || get_cors_unsafe_header_names(request.header_list).len > 0))
				pending_response = http_fetch(params, host, make_preflight)
				clear_preflight_cache_on_error = make_preflight
			}
		}
	}
	if mut pending := pending_response {
		if loaded := pending.response() {
			return finish_main_fetch(params, loaded, clear_preflight_cache_on_error)
		}
		result := PendingResponse.create(mut request, none)
		pending.when_loaded(fn [params, result, clear_preflight_cache_on_error] (loaded &Response) {
			finished := finish_main_fetch(params, loaded, clear_preflight_cache_on_error)
			resolve_pending_response_from(result, finished)
		})
		return result
	}
	return finish_main_fetch(params, response or { appropriate_network_error(params) }, clear_preflight_cache_on_error)
}

fn finish_main_fetch(params &FetchParams, response &Response, clear_preflight_cache_on_error bool) &PendingResponse {
	mut request := params.request
	mut resolved := if params.is_canceled() { appropriate_network_error(params) } else { response }
	resolved = request.apply_adblock_response(resolved)
	if clear_preflight_cache_on_error && resolved.is_network_error() {
		mut preflight_cache := PreflightCache.the()
		preflight_cache.clear_cache_entries(request)
	}

	if !resolved.is_network_error() && resolved.internal_response == none {
		if request.response_tainting == .cors {
			if exposed_names := resolved.header_list.get_decode_and_split('Access-Control-Expose-Headers') {
				if request.credentials_mode != .include && '*' in exposed_names {
					mut unique_names := []string{}
					for header in resolved.header_list.headers() {
						if !unique_names.any(equals_ignoring_ascii_case(it, header.name)) {
							unique_names << header.name
						}
					}
					resolved.cors_exposed_header_name_list = unique_names
				} else if exposed_names.len > 0 {
					resolved.cors_exposed_header_name_list = exposed_names
				}
			}
		}
		resolved = match request.response_tainting {
			.basic { filtered_response(resolved, .basic) }
			.cors { filtered_response(resolved, .cors) }
			.opaque { filtered_response(resolved, .opaque) }
		}
	}
	mut internal := resolved.unsafe_response()
	if internal.url_list.len == 0 {
		internal.url_list = request.url_list.clone()
	}
	internal.redirect_taint = request.redirect_taint()
	if request.is_navigation_request() {
		internal.set_navigation_timing_allow_values_list(request.navigation_timing_allow_values_list())
	}
	if !request.timing_allow_failed {
		internal.timing_allow_passed = true
	}
	if !resolved.is_network_error() && (response_blocked_by_security_policy(mut request, internal) || should_response_to_request_be_blocked_due_to_its_mime_type(internal, request) == .blocked || should_response_to_request_be_blocked_due_to_nosniff(internal, request) == .blocked) {
		resolved = Response.network_error('Response was blocked')
		internal = resolved
	}
	if resolved.response_type == .opaque && internal.status == 206 && internal.range_requested && !request.header_list.contains('Range') {
		resolved = Response.network_error("Response has status 206 and 'range-requested' flag set, but request has no 'Range' header")
		internal = resolved
	}
	if !resolved.is_network_error() && (request.method in ['HEAD', 'CONNECT'] || is_null_body_status(internal.status)) {
		internal.body = none
	}
	if request.integrity_metadata.len > 0 {
		body := internal.body or {
			return PendingResponse.create(mut request, Response.network_error('Response body could not be processed'))
		}
		bytes := body.bytes()
		matches := sri.do_bytes_match_metadata_list(bytes, request.integrity_metadata) or { false }
		if !matches {
			resolved = Response.network_error('Response body could not be processed')
		}
	}
	return PendingResponse.create(mut request, resolved)
}

pub fn populate_request_from_client(mut request Request) {
	if request.traversable_for_user_prompts == .client {
		request.traversable_for_user_prompts = .no_traversable
	}
	if client := request.client {
		request.client_present = true
		request.client_is_window = client.fetch_request_client_is_window()
		request.client_is_top_level_window = client.fetch_request_client_is_top_level_window()
		request.client_origin_opaque = client.fetch_request_client_origin().value == 'opaque'
		request.client_document_url = client.fetch_request_client_document_url()
		request.client_creation_url = client.fetch_request_client_creation_url()
		request.embedder_policy_credentialless = client.fetch_request_client_embedder_policy_credentialless()
	}
	if request.origin.is_client {
		client := request.client or {
			panic('populate_request_from_client requires a client when request origin is client')
		}
		request.origin = RequestOrigin{
			is_client: false
			origin:    client.fetch_request_client_origin()
		}
	}

	// 3. If request's policy container is "client":
	if request.policy_container == .client && request.resolved_policy_container == none {
		// 1. If request's client is non-null, then set request's policy container to a clone of request's client's
		//    policy container.
		if client := request.client {
			request.resolved_policy_container = client.fetch_request_client_policy_container()
		} else {
			// 2. Otherwise, set request's policy container to a new policy container.
			request.resolved_policy_container = RequestPolicyContainer{}
		}
	}
}

pub fn http_network_or_cache_fetch(params &FetchParams, host &FetchHost) &PendingResponse {
	mut request := params.request
	if params.is_canceled() {
		return PendingResponse.create(mut request, appropriate_network_error(params))
	}
	mut http_request := request.clone()
	if http_request.body.kind == .empty && http_request.method in ['POST', 'PUT'] {
		http_request.header_list.append(http.Header{ name: 'Content-Length', value: '0' })
	} else if body := http_request.body.body_object {
		if length := body.length {
			http_request.header_list.append(http.Header{
				name:  'Content-Length'
				value: length.str()
			})
		}
	} else if http_request.body.kind == .bytes {
		http_request.header_list.append(http.Header{
			name:  'Content-Length'
			value: http_request.body.bytes.len.str()
		})
	}
	if referrer_url := http_request.referrer.url {
		http_request.header_list.append(http.Header{
			name:  'Referer'
			value: referrer_url.serialize()
		})
	}
	http_request.add_origin_header()
	append_fetch_metadata_headers_for_request(mut http_request)
	if !http_request.header_list.contains('User-Agent') {
		http_request.header_list.append(http.Header{
			name:  'User-Agent'
			value: default_user_agent_for_url(http_request.current_url())
		})
	}
	if http_request.cache_mode == .default && ['If-Modified-Since', 'If-None-Match',
		'If-Unmodified-Since', 'If-Match', 'If-Range'].any(http_request.header_list.contains(it)) {
		http_request.cache_mode = .no_store
	}
	if http_request.cache_mode == .no_cache && !http_request.prevent_no_cache_cache_control_header_modification && !http_request.header_list.contains('Cache-Control') {
		http_request.header_list.append(http.Header{ name: 'Cache-Control', value: 'max-age=0' })
	}
	if http_request.cache_mode in [.no_store, .reload] {
		if !http_request.header_list.contains('Pragma') {
			http_request.header_list.append(http.Header{ name: 'Pragma', value: 'no-cache' })
		}
		if !http_request.header_list.contains('Cache-Control') {
			http_request.header_list.append(http.Header{
				name:  'Cache-Control'
				value: 'no-cache'
			})
		}
	}
	include_credentials := request.includes_credentials()
	if determine_the_http_cache_partition(http_request) == none {
		http_request.cache_mode = .no_store
	}
	mut response := ?&Response(none)
	if http_request.cache_mode !in [.no_store, .reload] {
		response = select_response_from_cache(http_request)
	}
	if mut stored_response := response {
		stored_response.cache_state = .local
	} else {
		mut controller := params.controller
		controller.set_pending_request(http_request)
		if destination := request.destination {
			if destination == .font {
				controller.requires_network_ = true
			}
		}
		{
			mut pending := perform_host_fetch(params, http_request, host)
			if forward_response := pending.response() {
				return finish_http_network_or_cache_fetch(params, http_request, forward_response, include_credentials, true)
			}
			result := PendingResponse.create(mut request, none)
			pending.when_loaded(fn [params, http_request, include_credentials, result] (forward_response &Response) {
				finished := finish_http_network_or_cache_fetch(params, http_request, forward_response, include_credentials, true)
				resolve_pending_response_from(result, finished)
			})
			return result
		}
	}
	return finish_http_network_or_cache_fetch(params, http_request, response or { Response.network_error('HTTP fetch produced no response') }, include_credentials, false)
}

fn finish_http_network_or_cache_fetch(params &FetchParams, http_request &Request, response &Response, include_credentials bool, network_response bool) &PendingResponse {
	mut request := params.request
	mut forward_response := if params.is_canceled() {
		appropriate_network_error(params)
	} else {
		response
	}
	forward_response = http_request.apply_adblock_response(forward_response)
	if network_response {
		mut controller := params.controller
		if params.has_response_body_transfer_lease {
			if request_server_request := forward_response.request_server_request() {
				if set_paused := request_server_request.set_body_delivery_paused {
					set_paused(true)
				}
			}
		}
		controller.set_pending_request(none)
		if forward_response.status >= 200 && forward_response.status <= 399
			&& http_request.method !in ['GET', 'HEAD', 'OPTIONS', 'TRACE'] {
			invalidate_response_in_cache(http_request)
		}
		store_response_in_cache(http_request, mut forward_response)
		finalize_response_in_cache(http_request, forward_response)
	}
	mut resolved := forward_response
	resolved.url_list = http_request.url_list.clone()
	if http_request.header_list.contains('Range') { resolved.range_requested = true }
	resolved.request_includes_credentials = include_credentials
	return PendingResponse.create(mut request, resolved)
}

pub fn nonstandard_resource_loader_file_or_http_network_fetch(params &FetchParams, host &FetchHost) &PendingResponse {
	return perform_host_fetch(params, params.request, host)
}

pub fn cors_preflight_fetch(mut request Request, host &FetchHost) &PendingResponse {
	mut preflight := Request.create()
	preflight.method = 'OPTIONS'
	preflight.url_list = request.url_list.clone()
	preflight.client = request.client
	preflight.initiator = request.initiator
	preflight.initiator_type = request.initiator_type
	preflight.destination = request.destination
	preflight.origin = request.origin
	preflight.referrer = request.referrer
	preflight.referrer_policy = request.referrer_policy
	preflight.mode = .cors
	preflight.response_tainting = .cors
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
	{
		mut pending := perform_host_fetch(FetchParams.create(preflight, FetchTimingInfo.create()), preflight, host)
		if response := pending.response() {
			return finish_cors_preflight_fetch(mut request, response, unsafe_names)
		}
		result := PendingResponse.create(mut request, none)
		pending.when_loaded(fn [unsafe_names, result] (response &Response) {
			mut mutable_request := result.request
			finished := finish_cors_preflight_fetch(mut mutable_request, response, unsafe_names)
			resolve_pending_response_from(result, finished)
		})
		return result
	}
}

fn finish_cors_preflight_fetch(mut request Request, response &Response, unsafe_names []string) &PendingResponse {
	if response.is_network_error() || !cors_check(request, response) || !is_ok_status(response.status) {
		return PendingResponse.create(mut request, Response.network_error('CORS-preflight check failed'))
	}
	mut methods := response.header_list.extract_header_list_values('Access-Control-Allow-Methods') or {
		return PendingResponse.create(mut request, Response.network_error('The Access-Control-Allow-Methods in the CORS-preflight response is syntactically invalid'))
	}
	header_names := response.header_list.extract_header_list_values('Access-Control-Allow-Headers') or {
		return PendingResponse.create(mut request, Response.network_error('The Access-Control-Allow-Headers in the CORS-preflight response is syntactically invalid'))
	}
	if methods.len == 0 && request.use_cors_preflight {
		methods = [request.method]
	}
	if request.method !in methods && !http.is_cors_safelisted_method(request.method) {
		if request.credentials_mode == .include || '*' !in methods {
			return PendingResponse.create(mut request, Response.network_error("Non-CORS-safelisted method '${request.method}' was not allowed by the CORS-preflight response"))
		}
	}
	for header in request.header_list.headers() {
		if is_cors_non_wildcard_request_header_name(header.name)
			&& !header_names.any(equals_ignoring_ascii_case(it, header.name)) {
			return PendingResponse.create(mut request, Response.network_error("Header '${header.name}' was not allowed by the CORS-preflight response"))
		}
	}
	for unsafe_name in unsafe_names {
		if header_names.any(equals_ignoring_ascii_case(it, unsafe_name)) {
			continue
		}
		if request.credentials_mode == .include || '*' !in header_names {
			return PendingResponse.create(mut request, Response.network_error("CORS-unsafe header '${unsafe_name}' was not allowed by the CORS-preflight response"))
		}
	}
	mut max_age := 5 * time.second
	max_age_values := response.header_list.extract_header_list_values('Access-Control-Max-Age') or {
		[]string{}
	}
	if max_age_values.len == 1 {
		if seconds := strconv.atoi(max_age_values[0]) {
			if seconds >= -2_147_483_648 && seconds <= 2_147_483_647 {
				max_age = time.Duration(seconds) * time.second
				if max_age > preflight_cache_max_age_limit {
					max_age = preflight_cache_max_age_limit
				}
			}
		}
	}
	mut preflight_cache := PreflightCache.the()
	for method in methods {
		preflight_cache.cache_method(request, method, max_age)
	}
	for header_name in header_names {
		preflight_cache.cache_header_name(request, header_name, max_age)
	}
	return PendingResponse.create(mut request, response)
}

pub fn http_fetch(params &FetchParams, host &FetchHost, make_cors_preflight bool) &PendingResponse {
	mut request := params.request
	mut preflight_cache := PreflightCache.the()
	method_needs_preflight := !preflight_cache.is_a_method_cache_entry_match(request, request.method) && (!http.is_cors_safelisted_method(request.method) || request.use_cors_preflight)
	unsafe_names := get_cors_unsafe_header_names(request.header_list)
	headers_need_preflight := unsafe_names.any(!preflight_cache.is_a_header_name_cache_entry_match(request, it))
	needs_preflight := make_cors_preflight && (method_needs_preflight || headers_need_preflight)
	if needs_preflight {
		mut pending := cors_preflight_fetch(mut request, host)
		if preflight_response := pending.response() {
			if preflight_response.is_network_error() {
				return PendingResponse.create(mut request, preflight_response)
			}
		} else {
			result := PendingResponse.create(mut request, none)
			pending.when_loaded(fn [params, host, result] (preflight_response &Response) {
				if preflight_response.is_network_error() {
					mut mutable_result := unsafe { &PendingResponse(result) }
					mutable_result.resolve(preflight_response)
				} else {
					resolve_pending_response_from(result, continue_http_fetch(params, host))
				}
			})
			return result
		}
	}
	return continue_http_fetch(params, host)
}

fn continue_http_fetch(params &FetchParams, host &FetchHost) &PendingResponse {
	mut request := params.request
	if params.is_canceled() {
		return PendingResponse.create(mut request, appropriate_network_error(params))
	}
	if request.redirect_mode == .follow {
		request.service_workers_mode = .none
	}
	mut pending := http_network_or_cache_fetch(params, host)
	if response := pending.response() { return finish_http_fetch(params, host, response) }
	result := PendingResponse.create(mut request, none)
	pending.when_loaded(fn [params, host, result] (response &Response) {
		resolve_pending_response_from(result, finish_http_fetch(params, host, response))
	})
	return result
}

fn finish_http_fetch(params &FetchParams, host &FetchHost, network_response &Response) &PendingResponse {
	mut request := params.request
	mut response := if params.is_canceled() {
		appropriate_network_error(params)
	} else {
		network_response
	}

	mut internal := response.unsafe_response()
	if request.response_tainting == .cors && internal.status !in [u16(304), 407] && !cors_check(request, internal) {
		return PendingResponse.create(mut request, Response.network_error("Request with 'cors' response tainting failed CORS check"))
	}
	if !tao_check(request, internal) {
		request.timing_allow_failed = true
	}
	if is_redirect_status(internal.status) {
		if request.is_navigation_request() {
			request.append_to_navigation_timing_allow_values_list(internal)
		}
		match request.redirect_mode {
			.error {
				response = Response.network_error("Request with 'error' redirect mode received redirect response")
			}
			.manual {
				if request.mode == .navigate {
					mut controller := params.controller
					controller.set_next_manual_redirect_steps(fn [params, response, host] () {
						_ = http_redirect_fetch(params, response, host)
					})
				} else {
					response = filtered_response(internal, .opaque_redirect)
				}
			}
			.follow {
				return http_redirect_fetch(params, response, host)
			}
		}
	}
	return PendingResponse.create(mut request, response)
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
	internal := response.unsafe_response()
	location_result := internal.location_url(request.current_url().fragment()) or {
		internal.release_request_transfer_lease()
		internal.stop_request_server_request()
		return PendingResponse.create(mut request, Response.network_error(err.msg()))
	}
	mut location := location_result.url or { return PendingResponse.create(mut request, response) }
	internal.release_request_transfer_lease()
	internal.stop_request_server_request()
	if location.scheme() !in ['http', 'https'] {
		return PendingResponse.create(mut request, Response.network_error('Request redirect URL must have HTTP or HTTPS scheme'))
	}
	if request.redirect_count == 20 {
		return PendingResponse.create(mut request, Response.network_error('Request has reached maximum redirect count of 20'))
	}
	request.redirect_count++
	location_includes_credentials := location.username().len > 0 || location.password().len > 0
	if request.mode == .cors && location_includes_credentials {
		if origin := request.origin.origin {
			if !origin.is_same_origin(location.origin()) {
				return PendingResponse.create(mut request, Response.network_error("Request with 'cors' mode and different URL and request origin must not include credentials in redirect URL"))
			}
		}
	}
	if request.response_tainting == .cors && location_includes_credentials {
		return PendingResponse.create(mut request, Response.network_error("Request with 'cors' response tainting must not include credentials in redirect URL"))
	}
	if ((internal.status == 301 || internal.status == 302) && request.method == 'POST') || (internal.status == 303 && request.method !in [
		'GET',
		'HEAD',
	]) {
		request.method = 'GET'
		request.body = RequestBody{}
		remove_request_headers(mut request, ['Content-Encoding', 'Content-Language', 'Content-Location',
			'Content-Type'])
	}
	if !location.origin().is_same_origin(request.current_url().origin()) {
		remove_request_headers(mut request, ['Authorization'])
	}
	now := highresolutiontime.coarsened_shared_current_time(params.cross_origin_isolated)
	mut timing_info := params.timing_info
	timing_info.redirect_end_time = now
	timing_info.post_redirect_start_time = now
	if timing_info.redirect_start_time == 0 {
		timing_info.redirect_start_time = timing_info.start_time
	}
	request.url_list << location
	// Fetching.cpp:1605–1606 / AbstractOperations.cpp:45–54 uses the
	// internal Response's actual HeaderList and preserves an empty result.
	policy := referrercore.parse_a_referrer_policy_from_header_list(internal.header_list)
	if policy != .empty_string {
		request.referrer_policy = referrercore.to_string(policy)
	}
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

pub fn fetch(request &Request, algorithms &FetchAlgorithms, host &FetchHost, create_response_body_transfer_lease CreateResponseBodyTransferLease) &FetchController {
	return fetch_with_parallel_queue(request, algorithms, host, .no, create_response_body_transfer_lease)
}

pub fn install_parallel_queue_factory(factory FetchParallelQueueFactory) {
	fetch_parallel_queue_factory = factory
}

pub fn fetch_with_parallel_queue(request &Request, algorithms &FetchAlgorithms, host &FetchHost, use_parallel_queue UseParallelQueue, create_response_body_transfer_lease CreateResponseBodyTransferLease) &FetchController {
	assert request.mode == .navigate || algorithms.input.process_early_hints_response == none
	mut mutable_request := unsafe { request }
	populate_request_from_client(mut mutable_request)
	cross_origin_isolated := if client := mutable_request.client {
		client.fetch_request_client_cross_origin_isolated_capability()
	} else {
		false
	}
	now := highresolutiontime.coarsened_shared_current_time(cross_origin_isolated)
	mut timing := FetchTimingInfo.create()
	timing.start_time = now
	timing.post_redirect_start_time = now
	timing.render_blocking = mutable_request.render_blocking
	mut params := FetchParams.create(mutable_request, timing)
	if use_parallel_queue == .yes {
		assert fetch_parallel_queue_factory != unsafe { nil }
		params.task_destination_provider = fetch_parallel_queue_factory()
		params.task_destination_global_identity = unsafe { nil }
	}
	params.algorithms = algorithms
	params.cross_origin_isolated = cross_origin_isolated
	params.has_response_body_transfer_lease = create_response_body_transfer_lease == .yes
	if !mutable_request.header_list.contains('Accept') {
		mut value := '*/*'
		is_prefetch := if initiator := mutable_request.initiator {
			initiator == .prefetch
		} else {
			false
		}
		is_document_destination := if destination := mutable_request.destination {
			destination in [.document, .frame, .iframe]
		} else {
			false
		}
		if is_prefetch || is_document_destination {
			value = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
		} else if destination := mutable_request.destination {
			value = match destination {
				// AD-HOC: Advertise the alpha-preserving formats supported by the image decoders.
				.image { 'image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5' }
				.json { 'application/json,*/*;q=0.5' }
				.style { 'text/css,*/*;q=0.1' }
				else { value }
			}
		}
		mutable_request.header_list.append(http.Header{ name: 'Accept', value: value })
	}
	if !mutable_request.header_list.contains('Accept-Language') {
		mutable_request.header_list.append(http.Header{
			name:  'Accept-Language'
			value: host.preferred_languages.join(',')
		})
	}
	mut pending := main_fetch(params, host)
	if response := pending.response() {
		fetch_response_handover(params, response)
	} else {
		pending.when_loaded(fn [params] (response &Response) {
			fetch_response_handover(params, response)
		})
	}
	return params.controller
}

// PendingResponse callbacks are the upstream continuation boundary: resolving
// one stage must preserve an unresolved response from a later redirect/stage.
fn resolve_pending_response_from(result &PendingResponse, source &PendingResponse) {
	mut target := unsafe { &PendingResponse(result) }
	if response := source.response() {
		target.resolve(response)
		return
	}
	mut pending_source := unsafe { &PendingResponse(source) }
	pending_source.when_loaded(fn [result] (response &Response) {
		mut target := unsafe { &PendingResponse(result) }
		target.resolve(response)
	})
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

// HTML owns the global object's event loop. This optional typed projection
// supplies the real networking destination without introducing a module cycle.
pub interface FetchTaskDestinationProvider {
	fetch_request_client_queue_fetch_task(algorithm fn ()) u64
	fetch_request_client_cancel_fetch_task(task_id u64)
	fetch_request_client_deferred_invoke(algorithm fn ())
}

pub fn deferred_invoke_for_request(request &Request, algorithm fn ()) {
	if client := request.client {
		if client is FetchTaskDestinationProvider {
			client.fetch_request_client_deferred_invoke(algorithm)
			return
		}
	}
	queue_fetch_task(algorithm)
}

pub fn queue_fetch_task_for_controller(mut controller FetchController, algorithm fn ()) u64 {
	fetch_task_id := controller.next_fetch_task_id()
	if params := controller.fetch_params_ {
		if destination := params.task_destination_provider {
				controller_pointer := voidptr(&controller)
				event_id := destination.fetch_request_client_queue_fetch_task(fn [controller_pointer, fetch_task_id, algorithm] () {
					mut owner := unsafe { &FetchController(controller_pointer) }
					owner.fetch_task_complete(fetch_task_id)
					algorithm()
				})
				controller.fetch_task_queued(fetch_task_id, event_id)
				return event_id
		}
	}
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
	// Keep response tokens monotonic: a late completion must not consume an
	// entry registered after the cache was cleared.
	fetch_http_memory_cache_pending.clear()
	fetch_http_memory_cache_complete.clear()
}

fn update_javascript_bytecode_cache_entries(entries []FetchMemoryCacheEntry, request_headers &http.HeaderList, vary_key u64, javascript_bytecode_cache []u8) []FetchMemoryCacheEntry {
	mut updated := entries.clone()
	for mut entry in updated {
		request_vary_key := http.create_vary_key(request_headers, entry.response_headers) or { continue }
		if request_vary_key != entry.vary_key {
			continue
		}
		entry.javascript_bytecode_cache = javascript_bytecode_cache.clone()
		entry.javascript_bytecode_cache_vary_key = vary_key
	}
	return updated
}

pub fn update_javascript_bytecode_cache_in_http_memory_cache(partition_key NetworkPartitionKey, url dom.URL, method string, request_headers &http.HeaderList, vary_key u64, javascript_bytecode_cache []u8) {
	if !fetch_http_memory_cache_enabled || !http.is_cacheable_request(method, request_headers) {
		return
	}
	key := fetch_memory_cache_key(partition_key, url, method)
	if entries := fetch_http_memory_cache_complete[key] {
		fetch_http_memory_cache_complete[key] = update_javascript_bytecode_cache_entries(entries, request_headers, vary_key, javascript_bytecode_cache)
	}
	if entries := fetch_http_memory_cache_pending[key] {
		fetch_http_memory_cache_pending[key] = update_javascript_bytecode_cache_entries(entries, request_headers, vary_key, javascript_bytecode_cache)
	}
}
