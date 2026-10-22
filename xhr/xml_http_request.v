// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of XHR/XMLHttpRequest.{h,cpp}. Real settings objects bind send
// to Fetch; manual response entry points remain available for focused fixtures.
module xhr

import fileapi
import dom
import encoding
import mimesniff
import url as liburl
import x.json2
import time
import fetch
import platform

fn xhr_monotonic_now() i64 {
	return time.sys_mono_now()
}

pub enum State {
	unsent
	opened
	headers_received
	loading
	done
}

pub enum ResponseType {
	empty
	arraybuffer
	blob
	document
	json
	text
}

pub enum GlobalKind {
	window
	worker
}

@[heap]
pub struct XMLHttpRequestGlobal {
pub:
	kind     GlobalKind
	base_url string
	origin ?dom.Origin
	associated_document ?&dom.Document
	monotonic_now fn () i64 = xhr_monotonic_now
	event_timestamp fn () f64 = dom.current_event_timestamp
	fetch_client ?fetch.RequestClient
	fetch_host ?&fetch.FetchHost
pub mut:
	document_destroyed bool
}

__global live_xml_http_requests_ []&XMLHttpRequest

pub struct ResponseHeader {
pub:
	name  string
	value string
}

pub struct MockResponse {
pub:
	url           string
	status        u16
	status_text   string
	headers       []ResponseHeader
	body          []u8
	network_error ?string
	aborted       bool
	body_is_null bool
}

pub struct XHRResponse {
pub:
	type_         ResponseType
	text          string
	bytes         []u8
	blob          ?&fileapi.Blob
	document_text ?string
	document ?&dom.Document
	json_text     ?string
}

pub struct XHRDocumentResult {
pub:
	document ?&dom.Document
	document_text ?string
}

@[heap]
pub struct XMLHttpRequest {
	XMLHttpRequestEventTarget
pub:
	global_kind    GlobalKind
	base_url       string
	global_object_ &XMLHttpRequestGlobal = unsafe { nil }
pub mut:
	window_fully_active      bool = true
	upload_object            &XMLHttpRequestUpload
	state                    State
	request_method           string
	request_url              string
	author_request_headers   []ResponseHeader
	request_body             []u8
	request_body_present     bool
	request_body_transmitted u64
	send_flag                bool
	synchronous              bool
	timeout_ms               u32
	with_credentials_        bool
	response_type_           ResponseType
	override_mime_type_      ?string
	response_                MockResponse
	received_bytes           []u8
	response_cache           ?XHRResponse
	timed_out                bool
	upload_complete          bool
	upload_listener          bool
	onreadystatechange_      bool
	activity_root_            bool
	timeout_timer_active      bool
	response_object_failed_   bool
	last_upload_progress_timestamp_ ?i64
	last_download_progress_timestamp_ ?i64
	fetch_controller_ &fetch.FetchController = fetch.FetchController.create()
	fetch_request_ ?&fetch.Request
	fetch_response_ ?&fetch.Response
	timeout_timer_ ?&platform.Timer
}

pub fn XMLHttpRequest.construct(global_kind GlobalKind, base_url string) &XMLHttpRequest {
	global_object := &XMLHttpRequestGlobal{
		kind: global_kind
		base_url: base_url
	}
	return XMLHttpRequest.create(global_object)
}

pub fn live_xml_http_requests() []&XMLHttpRequest {
	return live_xml_http_requests_.filter(voidptr(it) != unsafe { nil }).clone()
}

pub fn prune_live_xml_http_requests() {
	live_xml_http_requests_ = live_xml_http_requests_.filter(voidptr(it) != unsafe { nil })
}

pub fn XMLHttpRequest.create(global_object &XMLHttpRequestGlobal) &XMLHttpRequest {
	request := &XMLHttpRequest{
		upload_object: &XMLHttpRequestUpload{}
		global_kind:   global_object.kind
		base_url:      global_object.base_url
		global_object_: global_object
		response_:     MockResponse{ body_is_null: true }
	}
	mut target := request.as_event_target()
	target.data.set_listener_list_changed_hook(voidptr(request), xhr_event_listener_list_changed)
	mut mutable_request := unsafe { &XMLHttpRequest(request) }
	mutable_request.event_timestamp = global_object.event_timestamp
	mutable_request.upload_object.event_timestamp = global_object.event_timestamp
	live_xml_http_requests_ << request
	prune_live_xml_http_requests()
	return request
}

pub fn XMLHttpRequest.create_for_constructor(global_object &XMLHttpRequestGlobal) &XMLHttpRequest {
	return XMLHttpRequest.create(global_object)
}

pub fn XMLHttpRequest.construct_impl(global_kind GlobalKind, base_url string) &XMLHttpRequest {
	return XMLHttpRequest.construct(global_kind, base_url)
}

pub fn (request &XMLHttpRequest) relevant_global_impl() &XMLHttpRequestGlobal {
	return request.global_object_
}

pub fn XMLHttpRequest.release_activity_roots_for_relevant_global_object(global_object &XMLHttpRequestGlobal) {
	prune_live_xml_http_requests()
	for request in live_xml_http_requests_ {
		if voidptr(request.global_object_) == voidptr(global_object) {
			mut mutable_request := unsafe { &XMLHttpRequest(request) }
			mutable_request.activity_root_ = false
		}
	}
}

pub fn (request &XMLHttpRequest) relevant_global_object() &XMLHttpRequestGlobal {
	return request.global_object_
}

pub fn (request &XMLHttpRequest) relevant_settings_object() &XMLHttpRequestGlobal {
	return request.global_object_
}

pub fn (request &XMLHttpRequest) create_associated_event(event_name string) &dom.Event {
	mut event := dom.Event.create(event_name, dom.EventInit{})
	event.time_stamp_ = request.global_object_.event_timestamp()
	event.set_is_trusted(true)
	return event
}

pub fn (mut request XMLHttpRequest) stop_timeout_timer() {
	if mut timer := request.timeout_timer_ { timer.stop() }
	request.timeout_timer_ = none
	request.timeout_timer_active = false
}

pub fn (request &XMLHttpRequest) ready_state() u16 {
	return u16(request.state)
}

pub fn (request &XMLHttpRequest) timeout() u32 {
	return request.timeout_ms
}

pub fn (request &XMLHttpRequest) with_credentials() bool {
	return request.with_credentials_
}

pub fn (request &XMLHttpRequest) response_type() ResponseType {
	return request.response_type_
}

pub fn (request &XMLHttpRequest) upload() &XMLHttpRequestUpload {
	return request.upload_object
}

pub fn (mut request XMLHttpRequest) dispatch_state_change() {
	event := request.create_associated_event('readystatechange')
	request.events << ProgressEvent{ Event: *event }
	request.as_event_target().dispatch_event(event)
}

pub fn (mut request XMLHttpRequest) open(method string, input_url string, async bool, username ?string, password ?string) ! {
	fully_active := if document := request.global_object_.associated_document {
		document.is_fully_active()
	} else { request.window_fully_active }
	if request.global_kind == .window && !fully_active {
		return error("InvalidStateError: Window's associated document is not fully active")
	}
	if !is_http_method(method) {
		return error('SyntaxError: An invalid or illegal string was specified')
	}
	if method.to_upper() in ['CONNECT', 'TRACE', 'TRACK'] {
		return error("SecurityError: Forbidden method, must not be 'CONNECT', 'TRACE', or 'TRACK'")
	}
	base_url := if client := request.global_object_.fetch_client {
		client.fetch_request_client_api_base_url().serialize()
	} else { request.base_url }
	mut parsed := resolve_url_record(input_url, base_url)!
	if parsed.host != none {
		if username_value := username {
			parsed = parsed.with_username(username_value)
		}
		if password_value := password {
			parsed = parsed.with_password(password_value)
		}
	}
	if !async && request.global_kind == .window
		&& (request.timeout_ms != 0 || request.response_type_ != .empty) {
		return error('InvalidAccessError: Synchronous XMLHttpRequests in a Window context do not support timeout or a non-empty responseType')
	}
	request.fetch_controller_.terminate()
	request.fetch_request_ = none
	request.fetch_response_ = none
	request.send_flag = false
	request.stop_timeout_timer()
	request.update_activity_root()
	request.request_method = normalize_method(method)
	request.request_url = parsed.serialize(false)
	request.author_request_headers.clear()
	request.request_body.clear()
	request.request_body_present = false
	request.request_body_transmitted = 0
	request.synchronous = !async
	request.upload_listener = false
	request.response_ = MockResponse{ body_is_null: true }
	request.received_bytes.clear()
	request.response_cache = none
	request.response_object_failed_ = false
	if request.state != .opened {
		request.state = .opened
		request.dispatch_state_change()
	}
}

fn is_http_method(method string) bool {
	if method == '' {
		return false
	}
	for character in method.bytes() {
		if character <= 0x20 || character >= 0x7f
			|| character in [`(`, `)`, `<`, `>`, `@`, `,`, `;`, `:`, `\\`, `"`, `/`, `[`, `]`, `?`, `=`, `{`, `}`] {
			return false
		}
	}
	return true
}

fn normalize_method(method string) string {
	upper := method.to_upper()
	return if upper in ['DELETE', 'GET', 'HEAD', 'OPTIONS', 'POST', 'PUT'] { upper } else { method }
}

fn resolve_url_record(input string, base string) !liburl.URL {
	base_url := liburl.parse(base) or { return error('SyntaxError: Invalid URL') }
	return liburl.parse_with_base(input, &base_url) or { return error('SyntaxError: Invalid URL') }
}

pub fn (mut request XMLHttpRequest) set_request_header(name string, value string) ! {
	if request.state != .opened || request.send_flag {
		return error('InvalidStateError: XHR is not OPENED or send() flag is set')
	}
	normalized := normalize_header_value(value)
	if !valid_header_name(name) || !valid_header_value(normalized) {
		return error('SyntaxError: Header contains invalid characters')
	}
	if forbidden_request_header(name, normalized) {
		return
	}
	for index, header in request.author_request_headers {
		if header.name.to_lower() == name.to_lower() {
			request.author_request_headers[index] = ResponseHeader{
				name:  header.name
				value: '${header.value}, ${normalized}'
			}
			return
		}
	}
	request.author_request_headers << ResponseHeader{
		name:  name
		value: normalized
	}
}

fn valid_header_name(name string) bool {
	return is_http_method(name)
}

fn normalize_header_value(value string) string {
	return value.trim(' \t')
}

fn valid_header_value(value string) bool {
	for character in value.bytes() {
		if character == 0 || character == 0x7f || (character < 0x20 && character != `\t`) {
			return false
		}
	}
	return true
}

fn forbidden_request_header(name string, value string) bool {
	lower := name.to_lower()
	if lower in ['accept-charset', 'accept-encoding', 'access-control-request-headers', 'access-control-request-method', 'access-control-request-private-network', 'connection', 'content-length', 'cookie', 'cookie2', 'date', 'dnt', 'expect', 'host', 'keep-alive', 'origin', 'referer', 'te', 'trailer', 'transfer-encoding', 'upgrade', 'via']
		|| lower.starts_with('proxy-') || lower.starts_with('sec-') {
		return true
	}
	if lower in ['x-http-method', 'x-http-method-override', 'x-method-override'] {
		return value.split(',').any(it.trim_space().to_upper() in ['CONNECT', 'TRACE', 'TRACK'])
	}
	return false
}

pub fn (mut request XMLHttpRequest) send() ! {
	request.send_bytes([]u8{}, none, false, false)!
}

pub fn (mut request XMLHttpRequest) send_text(body string) ! {
	request.send_bytes(body.bytes(), 'text/plain;charset=UTF-8', true, true)!
}

pub fn (mut request XMLHttpRequest) send_blob(blob &fileapi.Blob) ! {
	content_type := blob.type_()
	request.send_bytes(blob.raw_bytes(), if content_type == '' { none } else { ?string(content_type) },
		true, false)!
}

pub fn (mut request XMLHttpRequest) send_raw(body []u8) ! {
	request.send_bytes(body, none, true, false)!
}

fn (mut request XMLHttpRequest) send_bytes(body []u8, content_type ?string, body_present bool, rewrite_charset bool) ! {
	if request.state != .opened || request.send_flag {
		return error('InvalidStateError: XHR readyState is not OPENED or send flag is already set')
	}
	request.request_body_present = body_present && request.request_method !in ['GET', 'HEAD']
	request.request_body = if !request.request_body_present {
		[]u8{}
	} else {
		body.clone()
	}
	if request.request_body_present && request.header('content-type') == none {
		if type_ := content_type {
			request.author_request_headers << ResponseHeader{
				name:  'Content-Type'
				value: type_
			}
		}
	}
	if request.request_body_present && rewrite_charset {
		request.ensure_utf8_content_type()
	}
	request.upload_listener = request.upload_object.listeners.len > 0
		|| request.upload_object.as_event_target().has_event_listeners()
	request.upload_complete = !request.request_body_present
	request.request_body_transmitted = 0
	request.timed_out = false
	request.send_flag = true
	request.timeout_timer_active = request.timeout_ms != 0
	request.update_activity_root()
	if !request.synchronous {
		request.dispatch('loadstart', 0, 0)
		request.last_upload_progress_timestamp_ = none
		request.last_download_progress_timestamp_ = none
		if !request.upload_complete && request.upload_listener {
			request.upload_object.dispatch('loadstart', 0, u64(request.request_body.len))
		}
		if request.state != .opened || !request.send_flag { return }
		request.start_async_fetch_if_bound()!
	} else {
		request.start_synchronous_fetch_if_bound()!
	}
}

fn (mut request XMLHttpRequest) ensure_utf8_content_type() {
	for index, header in request.author_request_headers {
		if header.name.to_lower() != 'content-type' {
			continue
		}
		parsed := mimesniff.MimeType.parse(header.value) or { return }
		charset := parsed.parameters()['charset'] or { return }
		if charset.to_upper() == 'UTF-8' {
			return
		}
		mut updated := parsed
		updated.set_parameter('charset', 'UTF-8')
		request.author_request_headers[index] = ResponseHeader{
			name:  header.name
			value: updated.serialized()
		}
		return
	}
}

// Typed callbacks for the Fetch request-body boundary.
pub fn (mut request XMLHttpRequest) receive_upload_chunk_length(length u64) {
	if request.upload_complete || !request.send_flag {
		return
	}
	request.request_body_transmitted += length
	// XMLHttpRequest.cpp: processRequestBodyChunkLength, steps 1–2.
	// Accumulate every chunk; only progress notification is throttled.
	now := request.global_object_.monotonic_now()
	if previous := request.last_upload_progress_timestamp_ {
		if now - previous < 50_000_000 {
			return
		}
	}
	request.last_upload_progress_timestamp_ = now
	if request.upload_listener {
		request.upload_object.dispatch('progress', request.request_body_transmitted,
			u64(request.request_body.len))
	}
}

pub fn (mut request XMLHttpRequest) complete_upload() {
	if request.upload_complete || !request.send_flag {
		return
	}
	request.upload_complete = true
	if !request.upload_listener {
		return
	}
	length := u64(request.request_body.len)
	request.upload_object.dispatch('progress', request.request_body_transmitted, length)
	request.upload_object.dispatch('load', request.request_body_transmitted, length)
	request.upload_object.dispatch('loadend', request.request_body_transmitted, length)
}

fn (request &XMLHttpRequest) header(name string) ?string {
	for header in request.author_request_headers {
		if header.name.to_lower() == name.to_lower() {
			return header.value
		}
	}
	return none
}

pub fn (mut request XMLHttpRequest) receive_headers(response MockResponse) ! {
	if !request.send_flag {
		return error('InvalidStateError: no active XMLHttpRequest')
	}
	request.response_ = response
	if request.timed_out {
		request.request_error_steps('timeout', 'TimeoutError: Timed out')!
		return
	}
	if request.response_.aborted {
		request.request_error_steps('abort', 'AbortError: Aborted')!
		return
	}
	if request.response_.network_error != none {
		message := request.response_.network_error or { 'Unknown error' }
		request.request_error_steps('error', 'NetworkError: ${message}')!
		return
	}
	request.state = .headers_received
	request.update_activity_root()
	request.dispatch_state_change()
}

pub fn (mut request XMLHttpRequest) receive_chunk(bytes []u8) {
	if request.state !in [.headers_received, .loading] {
		return
	}
	request.received_bytes << bytes
	request.response_cache = none
	// XMLHttpRequest.cpp: processBodyChunk, steps 1–5. Preserve the bytes
	// even when the LOADING/readystatechange/progress work is throttled.
	if !request.synchronous {
		now := request.global_object_.monotonic_now()
		if previous := request.last_download_progress_timestamp_ {
			if now - previous < 50_000_000 {
				return
			}
		}
		request.last_download_progress_timestamp_ = now
	}
	request.state = .loading
	request.update_activity_root()
	request.dispatch_state_change()
	if !request.synchronous {
		request.dispatch('progress', u64(request.received_bytes.len), request.content_length())
	}
}

pub fn (mut request XMLHttpRequest) complete_response() ! {
	if !request.send_flag {
		return
	}
	if request.response_.body.len > request.received_bytes.len {
		request.received_bytes = request.response_.body.clone()
	}
	request.handle_response_end_of_body()!
}

pub fn (mut request XMLHttpRequest) handle_response_end_of_body() ! {
	request.stop_timeout_timer()
	request.handle_errors()!
	if request.response_.network_error != none || request.response_.aborted || request.timed_out {
		return
	}
	transmitted := u64(request.received_bytes.len)
	length := request.content_length()
	if !request.synchronous {
		request.dispatch('progress', transmitted, length)
	}
	request.state = .done
	request.send_flag = false
	request.update_activity_root()
	request.dispatch_state_change()
	request.dispatch('load', transmitted, length)
	request.dispatch('loadend', transmitted, length)
}

pub fn (mut request XMLHttpRequest) handle_errors() ! {
	if !request.send_flag {
		return
	}
	if request.timed_out {
		request.request_error_steps('timeout', 'TimeoutError: Timed out')!
		return
	}
	if request.response_.aborted {
		request.request_error_steps('abort', 'AbortError: Aborted')!
		return
	}
	if request.response_.network_error != none {
		message := request.response_.network_error or { 'Unknown error' }
		request.request_error_steps('error', 'NetworkError: ${message}')!
	}
}

fn (request &XMLHttpRequest) content_length() u64 {
	value := request.get_response_header('content-length') or { return 0 }
	return value.u64()
}

pub fn (mut request XMLHttpRequest) timeout_request() ! {
	if request.send_flag {
		request.timed_out = true
		request.fetch_controller_.terminate()
		request.request_error_steps('timeout', 'TimeoutError: Timed out')!
	}
}

fn (mut request XMLHttpRequest) request_error_steps(event string, exception_message string) ! {
	request.stop_timeout_timer()
	request.state = .done
	request.send_flag = false
	request.update_activity_root()
	request.response_ = MockResponse{
		network_error: 'Failed to load'
		body_is_null: true
	}
	request.response_cache = none
	if request.synchronous {
		return error(exception_message)
	}
	request.dispatch_state_change()
	if !request.upload_complete {
		request.upload_complete = true
		if request.upload_listener {
			request.upload_object.dispatch(event, 0, 0)
			request.upload_object.dispatch('loadend', 0, 0)
		}
	}
	request.dispatch(event, 0, 0)
	request.dispatch('loadend', 0, 0)
}

pub fn (mut request XMLHttpRequest) abort() {
	request.stop_timeout_timer()
	request.fetch_controller_.abort(none)
	if (request.state == .opened && request.send_flag)
		|| request.state in [.headers_received, .loading] {
		request.request_error_steps('abort', '') or {}
	}
	if request.state == .done {
		request.state = .unsent
		request.response_ = MockResponse{ network_error: 'Not yet sent', body_is_null: true }
		request.update_activity_root()
	}
}

pub fn (mut request XMLHttpRequest) set_response_type(type_ ResponseType) ! {
	if request.global_kind == .worker && type_ == .document {
		return
	}
	if request.state in [.loading, .done] {
		return error('InvalidStateError: Cannot set responseType when loading or done')
	}
	if request.global_kind == .window && request.synchronous {
		return error('InvalidAccessError: Cannot set responseType on synchronous window XHR')
	}
	request.response_type_ = type_
}

pub fn (mut request XMLHttpRequest) set_timeout(timeout u32) ! {
	if request.global_kind == .window && request.synchronous {
		return error('InvalidAccessError: timeout is not supported in synchronous window XHR')
	}
	request.timeout_ms = timeout
}

pub fn (mut request XMLHttpRequest) set_with_credentials(value bool) ! {
	if request.state !in [.unsent, .opened] || request.send_flag {
		return error('InvalidStateError: withCredentials cannot be changed now')
	}
	request.with_credentials_ = value
}

pub fn (request &XMLHttpRequest) get_response_header(name string) ?string {
	mut values := []string{}
	for header in request.response_.headers {
		if header.name.to_lower() == name.to_lower() {
			values << header.value
		}
	}
	if values.len == 0 {
		return none
	}
	return values.join(', ')
}

pub fn (request &XMLHttpRequest) get_all_response_headers() string {
	mut combined := map[string][]string{}
	mut original := map[string]string{}
	for header in request.response_.headers {
		lower := header.name.to_lower()
		combined[lower] << header.value
		if lower !in original { original[lower] = header.name }
	}
	mut names := combined.keys()
	names.sort_with_compare(fn (a &string, b &string) int {
		return if is_legacy_uppercased_byte_less_than(*a, *b) {
			-1
		} else if is_legacy_uppercased_byte_less_than(*b, *a) {
			1
		} else {
			0
		}
	})
	mut output := ''
	for name in names {
		output += '${original[name]}: ${combined[name].join(', ')}\r\n'
	}
	return output
}

fn compare_strings(a string, b string) int {
	return if a < b {
		-1
	} else if a > b {
		1
	} else {
		0
	}
}

pub fn (mut request XMLHttpRequest) override_mime_type(value string) ! {
	if request.state in [.loading, .done] {
		return error('InvalidStateError: Cannot override MIME type when state is Loading or Done')
	}
	request.override_mime_type_ = if parsed := mimesniff.MimeType.parse(value) {
		parsed.serialized()
	} else {
		'application/octet-stream'
	}
}

pub fn (request &XMLHttpRequest) response_url() string {
	url := request.response_.url
	return if index := url.index('#') { url[..index] } else { url }
}

pub fn (request &XMLHttpRequest) status() u16 {
	return request.response_.status
}

pub fn (request &XMLHttpRequest) status_text() string {
	return request.response_.status_text
}

pub fn (request &XMLHttpRequest) response_text() !string {
	if request.response_type_ !in [.empty, .text] {
		return error('InvalidStateError: XHR responseText can only be used for responseType empty or text')
	}
	if request.state !in [.loading, .done] {
		return ''
	}
	if request.response_.network_error != none {
		return ''
	}
	return request.get_text_response()
}

pub fn (request &XMLHttpRequest) get_text_response() string {
	if request.received_bytes.len == 0 {
		return ''
	}
	charset := request.get_final_encoding() or { 'UTF-8' }
	decoder := encoding.TextDecoder.construct_impl(charset, encoding.TextDecoderOptions{}) or {
		panic('Unsupported XHR response encoding ${charset}')
	}
	return decoder.decode(request.received_bytes, encoding.TextDecodeOptions{}) or {
		panic('Failed to decode XHR response with ${charset}')
	}
}

pub fn (mut request XMLHttpRequest) set_document_response() {
	request.populate_document_response()
}

pub fn (request &XMLHttpRequest) response_document() ?XHRDocumentResult {
	cached := request.response_cache or { return none }
	document := cached.document or { return none }
	return XHRDocumentResult{
		document: document
		document_text: cached.document_text
	}
}

pub fn (request &XMLHttpRequest) response_blob() ?&fileapi.Blob {
	cached := request.response_cache or { return none }
	return cached.blob
}

pub fn (mut request XMLHttpRequest) set_blob_response_object(blob &fileapi.Blob) {
	request.response_cache = XHRResponse{
		type_: .blob
		blob: blob
	}
	request.response_object_failed_ = false
}

pub fn (request &XMLHttpRequest) response_body_is_null() bool {
	return request.response_.body_is_null
}

pub fn (mut request XMLHttpRequest) reset_response_object() {
	request.response_cache = none
	request.response_object_failed_ = false
}

pub fn (mut request XMLHttpRequest) response_xml() !XHRDocumentResult {
	if request.response_type_ !in [.empty, .document] {
		return error('InvalidStateError: XHR responseXML can only be used for responseType empty or document')
	}
	if request.state != .done || request.response_.network_error != none {
		return XHRDocumentResult{}
	}
	request.set_document_response()
	return request.response_document() or { XHRDocumentResult{} }
}

pub fn (mut request XMLHttpRequest) response() XHRResponse {
	if cached := request.response_cache {
		if request.response_type_ !in [.empty, .text] { return cached }
	}
	mut result := XHRResponse{
		type_: request.response_type_
	}
	if request.response_type_ in [.empty, .text] {
		result = XHRResponse{
			type_: request.response_type_
			text:  request.response_text() or { '' }
		}
	} else if request.state == .done {
		match request.response_type_ {
			.arraybuffer {
				result = XHRResponse{
					type_: .arraybuffer
					bytes: request.received_bytes.clone()
				}
			}
			.blob {
				request.set_blob_response_object(fileapi.Blob.create(request.received_bytes.clone(),
					request.final_mime_type()))
				return request.response_cache or { XHRResponse{ type_: .blob } }
			}
			.document {
				request.set_document_response()
				if document := request.response_cache {
					return document
				}
			}
			.json {
				text := request.received_bytes.bytestr()
				json2.decode[json2.Any](text) or {
					request.response_cache = result
					return result
				}
				result = XHRResponse{
					type_:     .json
					json_text: text
				}
			}
			else {}
		}
	}
	if request.response_type_ !in [.empty, .text] { request.response_cache = result }
	return result
}

fn (request &XMLHttpRequest) final_mime_type() string {
	return request.get_final_mime_type().serialized()
}

fn (request &XMLHttpRequest) response_mime_type_record() ?mimesniff.MimeType {
	return request.get_response_mime_type()
}

pub fn (request &XMLHttpRequest) get_response_mime_type() mimesniff.MimeType {
	mut result := ?mimesniff.MimeType(none)
	for header in request.response_.headers {
		if header.name.to_lower() == 'content-type' {
			if parsed := mimesniff.MimeType.parse(header.value) {
				result = parsed
			}
		}
	}
	return result or { mimesniff.MimeType.parse('text/xml') or { panic('invalid MIME type: text/xml') } }
}

fn (request &XMLHttpRequest) final_mime_type_record() ?mimesniff.MimeType {
	return request.get_final_mime_type()
}

pub fn (request &XMLHttpRequest) get_final_mime_type() mimesniff.MimeType {
	if override := request.override_mime_type_ {
		return mimesniff.MimeType.parse(override) or { panic('invalid MIME type: ${override}') }
	}
	return request.get_response_mime_type()
}

pub fn (request &XMLHttpRequest) get_final_encoding() ?string {
	mut label := ?string(none)
	response_mime := request.get_response_mime_type()
	if charset := response_mime.parameters()['charset'] {
		label = charset
	}
	if override := request.override_mime_type_ {
		if parsed := mimesniff.MimeType.parse(override) {
			if charset := parsed.parameters()['charset'] {
				label = charset
			}
		}
	}
	encoding_label := label or { return none }
	return encoding.get_an_encoding(encoding_label)
}

pub fn (request &XMLHttpRequest) onreadystatechange() bool {
	return request.onreadystatechange_
}

pub fn (mut request XMLHttpRequest) set_onreadystatechange(value bool) {
	request.onreadystatechange_ = value
	request.event_listener_list_changed()
}

pub fn (request &XMLHttpRequest) must_survive_garbage_collection() bool {
	return request.should_be_kept_alive()
}

pub fn (request &XMLHttpRequest) received_bytes() []u8 {
	return request.received_bytes.clone()
}

pub fn (request &XMLHttpRequest) response_object_is_failure() bool {
	return request.response_object_failed_
}

pub fn (request &XMLHttpRequest) has_activity_root() bool {
	return request.activity_root_
}

pub fn (request &XMLHttpRequest) should_be_kept_alive() bool {
	destroyed := if document := request.global_object_.associated_document {
		document.has_been_destroyed()
	} else { request.global_object_.document_destroyed }
	if request.global_kind == .window && destroyed {
		return false
	}
	active := (request.state == .opened && request.send_flag)
		|| request.state in [.headers_received, .loading]
	return active && (request.onreadystatechange() || request.has_relevant_listener())
}

pub fn (mut request XMLHttpRequest) update_activity_root() {
	request.activity_root_ = request.should_be_kept_alive()
}

pub fn (mut request XMLHttpRequest) event_listener_list_changed() {
	request.update_activity_root()
}

fn xhr_event_listener_list_changed(target voidptr) {
	mut request := unsafe { &XMLHttpRequest(target) }
	request.event_listener_list_changed()
}

pub fn is_legacy_uppercased_byte_less_than(a string, b string) bool {
	return a.to_upper() < b.to_upper()
}
