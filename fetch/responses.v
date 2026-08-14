// Copyright (c) 2022-2023, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Fetch/Infrastructure/HTTP/Responses.{h,cpp} — the Fetch
// `response` record (https://fetch.spec.whatwg.org/#concept-response): its enumerations, fields,
// the network-error creators, the network-error predicates, and url(). As with Request, the
// LibHTTP header list and the Fetch Body object are untranslated and held opaquely; the header
// list is represented as "empty" for this port (network errors carry no headers), which is what
// is_network_error inspects.
module fetch

import dom

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

// https://fetch.spec.whatwg.org/#concept-response
@[heap]
pub struct Response {
pub mut:
	// https://fetch.spec.whatwg.org/#concept-response-type
	response_type ResponseType = .default
	// https://fetch.spec.whatwg.org/#concept-response-aborted
	aborted bool
	// https://fetch.spec.whatwg.org/#concept-response-url-list
	url_list []dom.URL
	// https://fetch.spec.whatwg.org/#concept-response-status
	status u16 = 200
	// https://fetch.spec.whatwg.org/#concept-response-status-message
	status_message string
	// The header list is a HTTP::HeaderList (not translated); a nil handle means "empty" here.
	header_list voidptr = unsafe { nil }
	// https://fetch.spec.whatwg.org/#concept-response-body (a Body, or null). The Body object is
	// opaque; none means the null body that is_network_error checks for.
	body ?[]u8
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
	// https://fetch.spec.whatwg.org/#response-body-info
	body_info BodyInfo
	// https://fetch.spec.whatwg.org/#response-redirect-taint
	redirect_taint          RedirectTaint = .same_origin
	method                  string
	monotonic_response_time i64
	// https://fetch.spec.whatwg.org/#concept-network-error (the network error message).
	network_error_message ?string
}

// https://fetch.spec.whatwg.org/#concept-response-clone (allocation only).
pub fn Response.create() &Response {
	return &Response{}
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
	if response.url_list.len == 0 {
		return none
	}
	return response.url_list.last()
}

// https://fetch.spec.whatwg.org/#aborted-network-error
pub fn (response &Response) is_aborted_network_error() bool {
	// A response whose type is "error" and aborted flag is set.
	return response.response_type == .error && response.aborted
}

// https://fetch.spec.whatwg.org/#concept-network-error
pub fn (response &Response) is_network_error() bool {
	// type "error", status 0, empty status message, empty header list, null body, default body info.
	if response.response_type != .error {
		return false
	}
	if response.status != 0 {
		return false
	}
	if response.status_message.len != 0 {
		return false
	}
	// The header list is empty (opaque; always empty in this port).
	if response.header_list != unsafe { nil } {
		return false
	}
	if response.body != none {
		return false
	}
	if response.body_info != BodyInfo{} {
		return false
	}
	return true
}
