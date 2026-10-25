// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Request.cpp: uncached Fetch easy handle, header/data callbacks, completion,
// timing and detach/free; Fetching.cpp: ResourceLoader callback projection.
// This in-process adapter is not the unported RequestServer IPC/cache/DNS state
// machine. It uses the OS/libcurl resolver and system certificate verification.
module requestserver

import fetch
import http
import os
import platform

@[heap]
pub struct CurlRequest {
	connection_ &CurlConnection
	request_ &fetch.Request
	params_ &fetch.FetchParams
	pending_ &fetch.PendingResponse
	body_ &fetch.Body
	receiver_ &fetch.FetchedDataReceiver
mut:
	id_ u64
	easy_ voidptr
	headers_ voidptr
	in_multi_ bool
	sent_headers_ bool
	adblock_blocked_ bool
	finished_ bool
	stop_requested_ bool
	response_headers_ &http.HeaderList = http.HeaderList.create()
	reason_phrase_ ?string
	request_body_ []u8
}

pub fn (mut connection CurlConnection) fetch_host() &fetch.FetchHost {
	return &fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response { return error('Native RequestServer transport requires asynchronous Fetch') }
		perform_async_with_params: fn [mut connection] (params &fetch.FetchParams, request &fetch.Request) &fetch.PendingResponse {
			return connection.start_fetch(params, request)
		}
	}
}

pub fn (mut connection CurlConnection) start_fetch(params &fetch.FetchParams, input &fetch.Request) &fetch.PendingResponse {
	// Font and image requests can start during a temporary style/layout pass.
	// Curl retains these requests, map entries and callbacks until completion.
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	mut request := unsafe { &fetch.Request(input) }
	pending := fetch.PendingResponse.create(mut request, none)
	if filtered_response := request.apply_adblock() {
		mut output := pending
		output.resolve(filtered_response)
		return pending
	}
	if connection.closed_ {
		mut output := pending
		output.resolve(fetch.Response.network_error('RequestServer is currently unavailable'))
		return pending
	}
	body := fetch.Body.streaming()
	mut native := &CurlRequest{
		connection_: &connection
		request_: request
		params_: params
		pending_: pending
		body_: body
		receiver_: fetch.FetchedDataReceiver.create(params, body.stream())
		id_: connection.next_id_
		easy_: C.curl_easy_init()
	}
	connection.next_id_++
	if native.easy_ == unsafe { nil } {
		mut output := pending
		output.resolve(fetch.Response.network_error('Failed to initialize curl easy handle'))
		return pending
	}
	if object := request.body.body_object { native.request_body_ = object.bytes() }
	else if request.body.kind == .bytes { native.request_body_ = request.body.bytes.clone() }
	check_curl_result(C.vox_curl_setopt_pointer(native.easy_, C.CURLOPT_PRIVATE, native), C.CURLE_OK)
	check_curl_result(C.vox_curl_setopt_long(native.easy_, C.CURLOPT_NOSIGNAL, 1), C.CURLE_OK)
	check_curl_result(C.vox_curl_setopt_pointer(native.easy_, C.CURLOPT_ACCEPT_ENCODING, c''), C.CURLE_OK)
	check_curl_result(C.vox_curl_setopt_pointer(native.easy_, C.CURLOPT_URL, request.current_url().serialize().str), C.CURLE_OK)
	if proxy := os.getenv_opt('VOX_PROXY') {
		if proxy.trim_space() != '' {
			// libcurl keeps the scheme, including socks5h's remote DNS, and
			// copies this string: https://curl.se/libcurl/c/CURLOPT_PROXY.html
			check_curl_result(C.vox_curl_setopt_pointer(native.easy_, C.CURLOPT_PROXY,
				proxy.trim_space().str), C.CURLE_OK)
		}
	}
	check_curl_result(C.vox_curl_setopt_long(native.easy_, C.CURLOPT_CONNECTTIMEOUT, 90), C.CURLE_OK)
	check_curl_result(C.vox_curl_setopt_pointer(native.easy_, C.CURLOPT_CUSTOMREQUEST, request.method.str), C.CURLE_OK)
	check_curl_result(C.vox_curl_setopt_long(native.easy_, C.CURLOPT_FOLLOWLOCATION, 0), C.CURLE_OK)
	if request.method in ['POST', 'PUT', 'PATCH', 'DELETE'] {
		check_curl_result(C.vox_curl_setopt_long(native.easy_, C.CURLOPT_POSTFIELDSIZE, native.request_body_.len), C.CURLE_OK)
		check_curl_result(C.vox_curl_setopt_pointer(native.easy_, C.CURLOPT_POSTFIELDS, native.request_body_.data), C.CURLE_OK)
		if !request.header_list.contains('Content-Type') { native.append_curl_header('Content-Type:') }
	} else if request.method == 'HEAD' {
		check_curl_result(C.vox_curl_setopt_long(native.easy_, C.CURLOPT_NOBODY, 1), C.CURLE_OK)
	}
	for header in request.header_list.headers() {
		native.append_curl_header(if header.value == '' { '${header.name};' } else { '${header.name}: ${header.value}' })
	}
	if native.headers_ != unsafe { nil } {
		check_curl_result(C.vox_curl_setopt_pointer(native.easy_, C.CURLOPT_HTTPHEADER, native.headers_), C.CURLE_OK)
	}
	check_curl_result(C.vox_curl_setopt_write(native.easy_, C.CURLOPT_HEADERFUNCTION, curl_header_received), C.CURLE_OK)
	check_curl_result(C.vox_curl_setopt_pointer(native.easy_, C.CURLOPT_HEADERDATA, native), C.CURLE_OK)
	check_curl_result(C.vox_curl_setopt_write(native.easy_, C.CURLOPT_WRITEFUNCTION, curl_data_received), C.CURLE_OK)
	check_curl_result(C.vox_curl_setopt_pointer(native.easy_, C.CURLOPT_WRITEDATA, native), C.CURLE_OK)
	connection.requests_[native.id_] = native
	handle := native.request_handle()
	native.receiver_.set_network_request(handle)
	mut controller := params.controller
	controller.set_pending_network_request(handle)
	// RequestClient::start_request crosses IPC before RequestServer adds the
	// handle. Preserve that asynchronous boundary in this in-process adapter,
	// including redirects started from a curl header callback.
	mut plugin := connection.deferred_
	plugin.deferred_invoke(fn [mut native] () {
		if native.finished_ || native.stop_requested_ { return }
		check_curl_result(C.curl_multi_add_handle(native.connection_.multi_, native.easy_), C.CURLM_OK)
		native.in_multi_ = true
	})
	return pending
}

fn (mut request CurlRequest) append_curl_header(value string) {
	request.headers_ = C.curl_slist_append(request.headers_, value.str)
	assert request.headers_ != unsafe { nil }
}

fn (request &CurlRequest) request_handle() fetch.RequestServerRequest {
	return fetch.RequestServerRequest{
		request_id: request.id_
		stop: fn [request] () { mut native := unsafe { &CurlRequest(request) }; native.stop() }
		set_body_delivery_paused: fn [request] (paused bool) {
			if request.finished_ { return }
			check_curl_result(C.curl_easy_pause(request.easy_, if paused { C.CURLPAUSE_RECV } else { C.CURLPAUSE_CONT }), C.CURLE_OK)
		}
		resume_body_delivery: fn [request] () {
			if !request.finished_ { check_curl_result(C.curl_easy_pause(request.easy_, C.CURLPAUSE_CONT), C.CURLE_OK) }
		}
	}
}

fn curl_header_received(buffer voidptr, size usize, count usize, owner voidptr) usize {
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	mut request := unsafe { &CurlRequest(owner) }
	length := size * count
	line := unsafe { (&u8(buffer)).vbytes(int(length)).bytestr() }
	if line.starts_with('HTTP/') {
		// An informational response has its own header block. Its fields must
		// not become response-header conditions on the final response.
		request.response_headers_ = http.HeaderList.create()
		request.reason_phrase_ = none
		first := line.index(' ') or { return length }
		if second := line[first + 1..].index(' ') {
			reason := http.normalize_header_value(line[first + 2 + second..])
			if reason != '' {
				// TextCodec's exact ISO-8859-1 decoder maps every byte to that
				// code point; Encoding's web label would instead select CP1252.
				request.reason_phrase_ = reason.bytes().map(rune(it)).string()
				return length
			}
		}
	}
	if line.trim_space() == '' && C.vox_curl_status(request.easy_) >= 200 {
		if !request.transfer_headers_to_client_if_needed() { return 0 }
	}
	if colon := line.index(':') {
		request.response_headers_.append(http.Header{
			name: http.normalize_header_value(line[..colon])
			value: http.normalize_header_value(line[colon + 1..])
		})
	}
	return length
}

fn curl_data_received(buffer voidptr, size usize, count usize, owner voidptr) usize {
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	mut request := unsafe { &CurlRequest(owner) }
	if !request.transfer_headers_to_client_if_needed() { return 0 }
	length := size * count
	bytes := unsafe { (&u8(buffer)).vbytes(int(length)).clone() }
	request.receiver_.handle_network_data(fetch.NetworkResponseData.from_bytes(bytes), .ongoing)
	return length
}

fn (mut request CurlRequest) transfer_headers_to_client_if_needed() bool {
	if request.sent_headers_ { return !request.adblock_blocked_ }
	request.sent_headers_ = true
	mut response := fetch.Response.create()
	response.status = u16(C.vox_curl_status(request.easy_))
	response.status_message = request.reason_phrase_ or { '' }
	response.header_list = request.response_headers_
	response.url_list = request.request_.url_list.clone()
	response.body = request.body_
	filtered := request.request_.apply_adblock_response(response)
	if filtered.is_network_error() {
		request.adblock_blocked_ = true
		request.pending_.resolve(filtered)
		return false
	}
	response.set_request_server_request(request.request_handle())
	request.receiver_.set_response(response)
	request.receiver_.set_body(request.body_)
	request.pending_.resolve(response)
	return true
}

fn (request &CurlRequest) acquire_timing_info() fetch.RequestTimingInfo {
	queue := C.vox_curl_queue_time(request.easy_)
	lookup := C.vox_curl_time(request.easy_, C.CURLINFO_NAMELOOKUP_TIME_T)
	connect := C.vox_curl_time(request.easy_, C.CURLINFO_CONNECT_TIME_T)
	secure := C.vox_curl_time(request.easy_, C.CURLINFO_APPCONNECT_TIME_T)
	version := C.vox_curl_version(request.easy_)
	return fetch.RequestTimingInfo{
		domain_lookup_start_microseconds: queue
		domain_lookup_end_microseconds: lookup
		connect_start_microseconds: lookup
		connect_end_microseconds: if secure != 0 { secure } else { connect }
		secure_connect_start_microseconds: if secure != 0 { connect } else { 0 }
		request_start_microseconds: C.vox_curl_time(request.easy_, C.CURLINFO_PRETRANSFER_TIME_T)
		response_start_microseconds: C.vox_curl_time(request.easy_, C.CURLINFO_STARTTRANSFER_TIME_T)
		http_version_alpn_identifier: match version {
			C.CURL_HTTP_VERSION_1_0 { 'http/1.0' }
			C.CURL_HTTP_VERSION_1_1 { 'http/1.1' }
			C.CURL_HTTP_VERSION_2_0 { 'h2' }
			C.CURL_HTTP_VERSION_3 { 'h3' }
			else { '' }
		}
	}
}

fn (mut request CurlRequest) notify_fetch_complete(result int) {
	if request.finished_ { return }
	if request.adblock_blocked_ { request.stop(); return }
	if result == C.CURLE_OK {
		if !request.transfer_headers_to_client_if_needed() { request.stop(); return }
		mut timing := request.params_.timing_info
		timing.update_final_timings(request.acquire_timing_info(), request.params_.cross_origin_isolated)
		request.receiver_.handle_network_data(fetch.NetworkResponseData.from_bytes([]), .complete)
	} else {
		description := curl_network_error_description(result)
		mut stream := request.body_.stream()
		if stream.is_readable() { stream.error('TypeError: Load failed: ${description}') }
		if !request.pending_.is_resolved() { request.pending_.resolve(fetch.Response.network_error('Load failed: ${description}')) }
	}
	request.stop()
}

pub fn (mut request CurlRequest) stop() {
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	if request.finished_ || request.stop_requested_ { return }
	request.stop_requested_ = true
	// LibRequests::stop sends IPC; the server never removes its easy handle
	// recursively from a libcurl body callback. Defer the same server boundary.
	if request.connection_.in_curl_call_ {
		mut plugin := request.connection_.deferred_
		plugin.deferred_invoke(fn [mut request] () { request.free_curl_structs() })
		return
	}
	request.free_curl_structs()
}

fn (mut request CurlRequest) free_curl_structs() {
	if request.finished_ { return }
	request.finished_ = true
	if request.in_multi_ {
		check_curl_result(C.curl_multi_remove_handle(request.connection_.multi_, request.easy_), C.CURLM_OK)
		request.in_multi_ = false
	}
	C.curl_easy_cleanup(request.easy_)
	request.easy_ = unsafe { nil }
	if request.headers_ != unsafe { nil } { C.curl_slist_free_all(request.headers_); request.headers_ = unsafe { nil } }
	mut owner := unsafe { &CurlConnection(request.connection_) }
	owner.requests_.delete(request.id_)
}

// CURL.cpp: curl_code_to_network_error; LibRequests/NetworkError.h text.
fn curl_network_error_description(code int) string {
	return match code {
		C.CURLE_COULDNT_RESOLVE_PROXY { 'Unable to resolve proxy' }
		C.CURLE_COULDNT_RESOLVE_HOST { 'Unable to resolve host' }
		C.CURLE_COULDNT_CONNECT { 'Unable to connect' }
		C.CURLE_OPERATION_TIMEDOUT { 'Timeout reached' }
		C.CURLE_TOO_MANY_REDIRECTS { 'Too many redirects' }
		C.CURLE_SSL_CONNECT_ERROR { 'SSL handshake failed' }
		C.CURLE_PEER_FAILED_VERIFICATION { 'SSL verification failed' }
		C.CURLE_URL_MALFORMAT { 'The URL is not formatted properly' }
		C.CURLE_PARTIAL_FILE { 'Connection was closed before entire response was received' }
		C.CURLE_BAD_CONTENT_ENCODING { 'Response could not be decoded with its Content-Encoding' }
		else { 'An unexpected network error occurred' }
	}
}
