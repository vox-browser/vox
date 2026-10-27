// Copyright (c) 2022-2023, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Fetch/Infrastructure/HTTP/Responses.{h,cpp} — the Fetch
// `response` record (https://fetch.spec.whatwg.org/#concept-response): its enumerations, fields,
// the network-error creators, the network-error predicates, and url().
module fetch

import dom
import http
import time

// https://fetch.spec.whatwg.org/#concept-response-cache-state
pub enum CacheState {
	local
	validated
}

// https://fetch.spec.whatwg.org/#concept-response-type
pub enum ResponseType {
	basic
	cors
	default
	error
	opaque
	opaque_redirect
}

// https://fetch.spec.whatwg.org/#response-redirect-taint
pub enum RedirectTaint {
	same_origin
	same_site
	cross_site
}

// https://fetch.spec.whatwg.org/#response-body-info
pub struct BodyInfo {
pub mut:
	encoded_size u64
	decoded_size u64
	content_type string
}

pub type RequestServerAction = fn ()

pub type RequestServerResumeUpTo = fn (uint)

pub type RequestServerSetBodyDeliveryPaused = fn (bool)

pub struct RequestServerRequest {
pub:
	client_id                  int = -1
	request_id                 u64
	has_file_backed_response_body bool
	release_transfer_lease     ?RequestServerAction
	resume_body_delivery       ?RequestServerAction
	resume_body_delivery_up_to ?RequestServerResumeUpTo
	set_body_delivery_paused   ?RequestServerSetBodyDeliveryPaused
	stop                       ?RequestServerAction
}

fn clone_navigation_timing_allow_values_list(values [][]string) [][]string {
	mut cloned := [][]string{cap: values.len}
	for value in values {
		cloned << value.clone()
	}
	return cloned
}

fn clone_header_list(source &http.HeaderList) &http.HeaderList {
	mut cloned := http.HeaderList.create()
	for header in source.headers() {
		cloned.append(header)
	}
	return cloned
}

// https://fetch.spec.whatwg.org/#concept-response
@[heap]
pub struct Response {

	// https://fetch.spec.whatwg.org/#concept-response-type
pub mut:
	response_type ResponseType = .default
	// https://fetch.spec.whatwg.org/#concept-response-aborted
	aborted bool
	// https://fetch.spec.whatwg.org/#concept-response-url-list
	url_list []dom.URL
	// https://fetch.spec.whatwg.org/#concept-response-status
	status u16 = 200
	// https://fetch.spec.whatwg.org/#concept-response-status-message
	status_message string
	// https://fetch.spec.whatwg.org/#concept-response-header-list
	header_list &http.HeaderList = http.HeaderList.create()
	// https://fetch.spec.whatwg.org/#concept-response-body (a Body, or null).
	body ?&Body
	// https://fetch.spec.whatwg.org/#concept-response-cache-state
	cache_state ?CacheState
	// https://fetch.spec.whatwg.org/#concept-response-cors-exposed-header-name-list
	cors_exposed_header_name_list []string
	// https://fetch.spec.whatwg.org/#concept-response-range-requested-flag
	range_requested bool
	// https://fetch.spec.whatwg.org/#response-request-includes-credentials
	request_includes_credentials bool = true
	// https://fetch.spec.whatwg.org/#concept-response-timing-allow-passed
	timing_allow_passed bool
	// https://fetch.spec.whatwg.org/#response-navigation-timing-allow-values-list
	navigation_timing_allow_values_list_ [][]string
	// https://fetch.spec.whatwg.org/#response-body-info
	body_info BodyInfo
	// https://fetch.spec.whatwg.org/#response-redirect-taint
	redirect_taint          RedirectTaint = .same_origin
	method                  string
	monotonic_response_time i64
	// https://fetch.spec.whatwg.org/#concept-network-error (the network error message).
	network_error_message                                   ?string
	javascript_bytecode_cache_                              ?[]u8
	javascript_bytecode_cache_vary_key_                     ?u64
	javascript_bytecode_cache_memory_cache_request_headers_ ?&http.HeaderList
	internal_response                                       ?&Response
	request_server_request_                                 ?RequestServerRequest
}

// https://fetch.spec.whatwg.org/#concept-response-clone (allocation only).
pub fn Response.create() &Response {
	return &Response{
		monotonic_response_time: i64(time.sys_mono_now())
	}
}

// https://fetch.spec.whatwg.org/#concept-network-error
pub fn Response.network_error(message string) &Response {
	// A network error is a response whose type is "error", status is 0, ... and body is null.
	mut response := Response.create()
	response.status = 0
	response.response_type = .error
	response.network_error_message = message
	return response
}

// https://fetch.spec.whatwg.org/#concept-aborted-network-error
pub fn Response.aborted_network_error() &Response {
	mut response := Response.network_error('Fetch has been aborted')
	response.aborted = true
	return response
}

// https://fetch.spec.whatwg.org/#concept-response-url
// A response's URL is the last URL in its URL list, or null if the list is empty.
pub fn (response &Response) url() ?dom.URL {
	url_list := response.fetch_response_url_list()
	if url_list.len == 0 {
		return none
	}
	return url_list.last()
}

// https://fetch.spec.whatwg.org/#aborted-network-error
pub fn (response &Response) is_aborted_network_error() bool {
	// A response whose type is "error" and aborted flag is set.
	return response.fetch_response_type() == .error && response.fetch_response_aborted()
}

// https://fetch.spec.whatwg.org/#concept-network-error
pub fn (response &Response) is_network_error() bool {
	// type "error", status 0, empty status message, empty header list, null body, default body info.
	if response.fetch_response_type() != .error {
		return false
	}
	if response.fetch_response_status() != 0 {
		return false
	}
	if response.fetch_response_status_message().len != 0 {
		return false
	}
	// The header list is empty.
	if !response.fetch_response_header_list().is_empty() {
		return false
	}
	if response.fetch_response_body() != none {
		return false
	}
	if response.fetch_response_body_info() != BodyInfo{} {
		return false
	}
	return true
}

pub struct LocationURLResult {
pub:
	url ?dom.URL
}

pub fn (response &Response) location_url(request_fragment ?string) !LocationURLResult {
	if !is_redirect_status(response.fetch_response_status()) {
		return LocationURLResult{}
	}
	values := response.header_list.get_decode_and_split('Location') or {
		return LocationURLResult{}
	}
	if values.len != 1 {
		return LocationURLResult{}
	}
	base := response.url() or { dom.URL{} }
	mut location := dom.dom_url_parse(values[0], base, 'UTF-8') or {
		return error("Invalid 'Location' header URL")
	}
	if location.fragment() == none {
		location.set_fragment(request_fragment)
	}
	return LocationURLResult{
		url: location
	}
}

pub fn (response &Response) clone() &Response {
	if internal := response.internal_response {
		return filtered_response(internal.clone(), response.response_type)
	}
	mut headers := http.HeaderList.create()
	for header in response.header_list.headers() {
		headers.append(header)
	}
	return &Response{
		response_type: response.response_type
		aborted: response.aborted
		url_list: response.url_list.clone()
		status: response.status
		status_message: response.status_message
		header_list: headers
		body: clone_body(response.body)
		cache_state: response.cache_state
		cors_exposed_header_name_list: response.cors_exposed_header_name_list.clone()
		range_requested: response.range_requested
		request_includes_credentials: response.request_includes_credentials
		timing_allow_passed: response.timing_allow_passed
		navigation_timing_allow_values_list_: clone_navigation_timing_allow_values_list(response.navigation_timing_allow_values_list_)
		body_info: response.body_info
		redirect_taint: response.redirect_taint
		javascript_bytecode_cache_: response.javascript_bytecode_cache()
		javascript_bytecode_cache_vary_key_: response.javascript_bytecode_cache_vary_key()
		javascript_bytecode_cache_memory_cache_request_headers_: if cache_request_headers := response.javascript_bytecode_cache_memory_cache_request_headers_ {
			clone_header_list(cache_request_headers)
		} else {
			none
		}
		request_server_request_: response.request_server_request_
		monotonic_response_time: i64(time.sys_mono_now())
	}
}

pub fn (response &Response) request_server_request() ?RequestServerRequest {
	if internal := response.internal_response {
		return internal.request_server_request()
	}
	return response.request_server_request_
}

pub fn (mut response Response) set_request_server_request(request RequestServerRequest) {
	if mut internal := response.internal_response {
		internal.set_request_server_request(request)
		return
	}
	response.request_server_request_ = request
}

pub fn (response &Response) release_request_transfer_lease() {
	if internal := response.internal_response {
		internal.release_request_transfer_lease()
		return
	}
	request := response.request_server_request_ or { return }
	if release := request.release_transfer_lease {
		release()
	}
}

pub fn (response &Response) resume_body_delivery() {
	if internal := response.internal_response {
		internal.resume_body_delivery()
		return
	}
	response.release_request_transfer_lease()
	request := response.request_server_request_ or { return }
	if resume := request.resume_body_delivery {
		resume()
	}
}

pub fn (response &Response) resume_body_delivery_up_to(byte_count uint) {
	if internal := response.internal_response {
		internal.resume_body_delivery_up_to(byte_count)
		return
	}
	request := response.request_server_request_ or { return }
	if resume := request.resume_body_delivery_up_to {
		resume(byte_count)
	}
}

fn (response &Response) stop_request_server_request() {
	request := response.request_server_request() or { return }
	if stop := request.stop {
		stop()
	}
}

pub fn (response &Response) unsafe_response() &Response {
	return response.internal_response or { response }
}

pub fn (response &Response) is_cors_same_origin() bool {
	return response.fetch_response_type() in [.basic, .cors, .default]
}

pub fn (response &Response) is_cors_cross_origin() bool {
	return response.fetch_response_type() in [.opaque, .opaque_redirect]
}

pub fn filtered_response(internal &Response, response_type ResponseType) &Response {
	mut headers := http.HeaderList.create()
	match response_type {
		.basic {
			for header in internal.header_list.headers() {
				if !is_forbidden_response_header_name(header.name) { headers.append(header) }
			}
		}
		.cors {
			for header in internal.header_list.headers() {
				if is_cors_safelisted_response_header_name(header.name, internal.cors_exposed_header_name_list) {
					headers.append(header)
				}
			}
		}
		else {}
	}
	if response_type == .opaque {
		return &Response{
			response_type: .opaque
			aborted: internal.aborted
			status: 0
			header_list: headers
			cache_state: internal.cache_state
			body_info: internal.body_info
			monotonic_response_time: i64(time.sys_mono_now())
			internal_response: internal
		}
	}
	if response_type == .opaque_redirect {
		return &Response{
			response_type: .opaque_redirect
			aborted: internal.aborted
			status: 0
			url_list: internal.url_list.clone()
			header_list: headers
			cache_state: internal.cache_state
			body_info: internal.body_info
			monotonic_response_time: i64(time.sys_mono_now())
			internal_response: internal
		}
	}
	return &Response{
		response_type: response_type
		aborted: internal.aborted
		url_list: internal.url_list.clone()
		status: internal.status
		status_message: internal.status_message
		header_list: headers
		cache_state: internal.cache_state
		cors_exposed_header_name_list: internal.cors_exposed_header_name_list.clone()
		range_requested: internal.range_requested
		request_includes_credentials: internal.request_includes_credentials
		timing_allow_passed: internal.timing_allow_passed
		body_info: internal.body_info
		monotonic_response_time: i64(time.sys_mono_now())
		internal_response: internal
	}
}
