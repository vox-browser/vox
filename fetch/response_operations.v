// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Accessor and filtered-response entry points from HTTP/Responses.{h,cpp} and
// the Web-facing Response object. Filtered responses share Response storage in
// V; inherited setters still forward to the internal response as upstream does.
module fetch

import dom
import http
import mimesniff

pub fn (response &Response) fetch_response_type() ResponseType {
	return response.response_type
}

pub fn (response &Response) fetch_response_aborted() bool {
	if internal := response.internal_response {
		return internal.aborted
	}
	return response.aborted
}

pub fn (mut response Response) set_aborted(aborted bool) {
	if mut internal := response.internal_response {
		internal.aborted = aborted
		return
	}
	response.aborted = aborted
}

pub fn (response &Response) fetch_response_url_list() []dom.URL {
	if response.response_type == .opaque {
		return []dom.URL{}
	}
	if internal := response.internal_response {
		return internal.url_list.clone()
	}
	return response.url_list.clone()
}

pub fn (mut response Response) set_url_list(url_list []dom.URL) {
	if mut internal := response.internal_response {
		internal.url_list = url_list.clone()
		return
	}
	response.url_list = url_list.clone()
}

pub fn (mut response Response) set_status(status u16) {
	if mut internal := response.internal_response {
		internal.status = status
		return
	}
	response.status = status
}

pub fn (response &Response) fetch_response_status() u16 {
	if response.response_type in [.opaque, .opaque_redirect] {
		return 0
	}
	if internal := response.internal_response {
		return internal.status
	}
	return response.status
}

pub fn (response &Response) fetch_response_status_message() string {
	if response.response_type in [.opaque, .opaque_redirect] {
		return ''
	}
	if internal := response.internal_response {
		return internal.status_message
	}
	return response.status_message
}

pub fn (mut response Response) set_status_message(message string) {
	if mut internal := response.internal_response {
		internal.status_message = message
		return
	}
	response.status_message = message
}

pub fn (response &Response) fetch_response_header_list() &http.HeaderList {
	return response.header_list
}

pub fn (mut response Response) set_header_list(header_list &http.HeaderList) {
	if mut internal := response.internal_response {
		internal.header_list = header_list
		return
	}
	response.header_list = header_list
}

pub fn (response &Response) fetch_response_body() ?&Body {
	if response.response_type in [.opaque, .opaque_redirect] {
		return none
	}
	if internal := response.internal_response {
		return internal.body
	}
	return response.body
}

pub fn (mut response Response) set_body(body ?&Body) {
	if mut internal := response.internal_response {
		internal.body = body
		return
	}
	response.body = body
}

// Byte buffers are the host-network boundary in this standalone port. Keep
// conversion at that boundary; the response record itself always owns a Body.
pub fn (mut response Response) set_body_bytes(bytes ?[]u8) {
	if value := bytes {
		response.set_body(Body.from_bytes(value, .bytes))
	} else {
		response.set_body(none)
	}
}

pub fn (response &Response) fetch_response_body_bytes() ?[]u8 {
	body := response.fetch_response_body() or { return none }
	return body.bytes()
}

pub fn (response &Response) fetch_response_cache_state() ?CacheState {
	if internal := response.internal_response {
		return internal.cache_state
	}
	return response.cache_state
}

pub fn (mut response Response) set_cache_state(cache_state ?CacheState) {
	if mut internal := response.internal_response {
		internal.cache_state = cache_state
		return
	}
	response.cache_state = cache_state
}

pub fn (response &Response) fetch_response_cors_exposed_header_name_list() []string {
	if internal := response.internal_response {
		return internal.cors_exposed_header_name_list.clone()
	}
	return response.cors_exposed_header_name_list.clone()
}

pub fn (mut response Response) set_cors_exposed_header_name_list(names []string) {
	if mut internal := response.internal_response {
		internal.cors_exposed_header_name_list = names.clone()
		return
	}
	response.cors_exposed_header_name_list = names.clone()
}

pub fn (response &Response) fetch_response_range_requested() bool {
	if internal := response.internal_response {
		return internal.range_requested
	}
	return response.range_requested
}

pub fn (mut response Response) set_range_requested(range_requested bool) {
	if mut internal := response.internal_response {
		internal.range_requested = range_requested
		return
	}
	response.range_requested = range_requested
}

pub fn (response &Response) fetch_response_request_includes_credentials() bool {
	if internal := response.internal_response {
		return internal.request_includes_credentials
	}
	return response.request_includes_credentials
}

pub fn (mut response Response) set_request_includes_credentials(includes_credentials bool) {
	if mut internal := response.internal_response {
		internal.request_includes_credentials = includes_credentials
		return
	}
	response.request_includes_credentials = includes_credentials
}

pub fn (response &Response) fetch_response_timing_allow_passed() bool {
	if internal := response.internal_response {
		return internal.timing_allow_passed
	}
	return response.timing_allow_passed
}

pub fn (mut response Response) set_timing_allow_passed(passed bool) {
	if mut internal := response.internal_response {
		internal.timing_allow_passed = passed
		return
	}
	response.timing_allow_passed = passed
}

pub fn (response &Response) navigation_timing_allow_values_list() [][]string {
	if internal := response.internal_response {
		return internal.navigation_timing_allow_values_list()
	}
	return clone_navigation_timing_allow_values_list(response.navigation_timing_allow_values_list_)
}

pub fn (mut response Response) set_navigation_timing_allow_values_list(values [][]string) {
	if mut internal := response.internal_response {
		internal.set_navigation_timing_allow_values_list(values)
		return
	}
	response.navigation_timing_allow_values_list_ = clone_navigation_timing_allow_values_list(values)
}

pub fn (response &Response) fetch_response_body_info() BodyInfo {
	if internal := response.internal_response {
		return internal.body_info
	}
	return response.body_info
}

pub fn (mut response Response) set_body_info(info BodyInfo) {
	if mut internal := response.internal_response {
		internal.body_info = info
		return
	}
	response.body_info = info
}

pub fn (response &Response) javascript_bytecode_cache() ?[]u8 {
	cache := response.javascript_bytecode_cache_ or { return none }
	return cache.clone()
}

pub fn (mut response Response) set_javascript_bytecode_cache(cache ?[]u8) {
	if bytes := cache {
		response.javascript_bytecode_cache_ = bytes.clone()
	} else {
		response.javascript_bytecode_cache_ = none
	}
}

pub fn (response &Response) javascript_bytecode_cache_vary_key() ?u64 {
	return response.javascript_bytecode_cache_vary_key_
}

pub fn (mut response Response) set_javascript_bytecode_cache_vary_key(vary_key ?u64) {
	response.javascript_bytecode_cache_vary_key_ = vary_key
}

pub fn (response &Response) javascript_bytecode_cache_memory_cache_request_headers() ?&http.HeaderList {
	return response.javascript_bytecode_cache_memory_cache_request_headers_
}

pub fn (mut response Response) set_javascript_bytecode_cache_memory_cache_request_headers(request_headers ?&http.HeaderList) {
	if headers := request_headers {
		response.javascript_bytecode_cache_memory_cache_request_headers_ = clone_header_list(headers)
	} else {
		response.javascript_bytecode_cache_memory_cache_request_headers_ = none
	}
}

pub fn (response &Response) fetch_response_redirect_taint() RedirectTaint {
	if internal := response.internal_response {
		return internal.fetch_response_redirect_taint()
	}
	return response.redirect_taint
}

pub fn (mut response Response) set_redirect_taint(taint RedirectTaint) {
	if mut internal := response.internal_response {
		internal.set_redirect_taint(taint)
		return
	}
	response.redirect_taint = taint
}

pub fn (response &Response) fetch_response_network_error_message() ?string {
	return response.network_error_message
}

pub fn (response &Response) fetch_response_monotonic_response_time() i64 {
	return response.monotonic_response_time
}

pub fn (response &Response) fetch_response_method() string {
	return response.method
}

pub fn (mut response Response) set_method(method string) {
	response.method = method
}

pub fn (response &Response) internal_response() &Response {
	return response.internal_response or { response }
}

pub fn Response.appropriate_network_error(params &FetchParams) &Response {
	return appropriate_network_error(params)
}

pub fn Response.create_basic_filtered_response(internal &Response) &Response {
	return filtered_response(internal, .basic)
}

pub fn Response.create_cors_filtered_response(internal &Response) &Response {
	return filtered_response(internal, .cors)
}

pub fn Response.create_opaque_filtered_response(internal &Response) &Response {
	return filtered_response(internal, .opaque)
}

pub fn Response.create_opaque_redirect_filtered_response(internal &Response) &Response {
	return filtered_response(internal, .opaque_redirect)
}

pub fn is_valid_status_text(value string) bool {
	// Status messages are HTTP octets, including obs-text (0x80-0xff).
	// Decoding them as UTF-8 rejects a valid single high byte.
	return value.bytes().all(it == `\t` || (it >= 0x20 && it != 0x7f))
}

// Web-exposed Response object adapters.
pub fn ResponseObject.construct_impl(body_init ?BodyInit, init ResponseInit) !&ResponseObject {
	return ResponseObject.construct(body_init, init)
}

pub fn (object &ResponseObject) mime_type_impl() ?mimesniff.MimeType {
	return extract_mime_type(object.response_.header_list)
}

pub fn (object &ResponseObject) body_impl() ?&Body {
	return object.response_.fetch_response_body()
}

pub fn (object &ResponseObject) as_platform_object() &ResponseObject {
	return object
}

pub fn (mut object ResponseObject) initialize_response(init ResponseInit, body_with_type ?BodyWithType) ! {
	if init.status < 200 || init.status > 599 {
		return error('RangeError: Invalid response status')
	}
	if !is_valid_status_text(init.status_text) {
		return error('TypeError: Invalid response status text')
	}
	object.response_.status = init.status
	object.response_.status_message = init.status_text
	if init.headers_present || init.headers.len > 0 {
		object.headers_.fill(init.headers)!
	}
	if extracted := body_with_type {
		if is_null_body_status(init.status) {
			return error('TypeError: Null-body status cannot have a body')
		}
		object.response_.body = extracted.body
		if content_type := extracted.type_ {
			if !object.response_.header_list.contains('Content-Type') {
				object.response_.header_list.append(http.Header{
					name: 'Content-Type'
					value: content_type
				})
			}
		}
	}
}
