// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of XHR/XMLHttpRequest.{h,cpp}. Fetch is an explicit typed
// boundary: send records the request and complete_response/error/timeout feed
// the same observable XHR state machine used by the native callback.
module xhr

import fileapi
import encoding
import mimesniff
import url as liburl
import x.json2

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
}

pub struct XHRResponse {
pub:
	type_         ResponseType
	text          string
	bytes         []u8
	blob          ?&fileapi.Blob
	document_text ?string
	json_text     ?string
}

pub struct XHRDocumentResult {
pub:
	document_text ?string
}

@[heap]
pub struct XMLHttpRequest {
	XMLHttpRequestEventTarget
pub:
	global_kind GlobalKind
	base_url    string
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
}

pub fn XMLHttpRequest.construct(global_kind GlobalKind, base_url string) &XMLHttpRequest {
	return &XMLHttpRequest{
		upload_object: &XMLHttpRequestUpload{}
		global_kind:   global_kind
		base_url:      base_url
		response_:     MockResponse{}
	}
}

pub fn XMLHttpRequest.construct_impl(global_kind GlobalKind, base_url string) &XMLHttpRequest {
	return XMLHttpRequest.construct(global_kind, base_url)
}

pub fn (request &XMLHttpRequest) ready_state() u16 {
	return u16(request.state)
}

pub fn (mut request XMLHttpRequest) dispatch_state_change() {
	request.dispatch('readystatechange', 0, 0)
}

pub fn (mut request XMLHttpRequest) open(method string, input_url string, async bool, username ?string, password ?string) ! {
	if request.global_kind == .window && !request.window_fully_active {
		return error("InvalidStateError: Window's associated document is not fully active")
	}
	if !is_http_method(method) {
		return error('SyntaxError: An invalid or illegal string was specified')
	}
	if method.to_upper() in ['CONNECT', 'TRACE', 'TRACK'] {
		return error("SecurityError: Forbidden method, must not be 'CONNECT', 'TRACE', or 'TRACK'")
	}
	mut parsed := resolve_url_record(input_url, request.base_url)!
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
	request.send_flag = false
	request.request_method = normalize_method(method)
	request.request_url = parsed.serialize(false)
	request.author_request_headers.clear()
	request.request_body.clear()
	request.request_body_present = false
	request.request_body_transmitted = 0
	request.synchronous = !async
	request.upload_listener = false
	request.response_ = MockResponse{}
	request.received_bytes.clear()
	request.response_cache = none
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
	request.send_bytes(blob.raw_bytes(), if blob.type_() == '' { none } else { blob.type_() },
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
	request.upload_complete = !request.request_body_present
	request.request_body_transmitted = 0
	request.timed_out = false
	request.send_flag = true
	if !request.synchronous {
		request.dispatch('loadstart', 0, 0)
		if !request.upload_complete && request.upload_listener {
			request.upload_object.dispatch('loadstart', 0, u64(request.request_body.len))
		}
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
	request.dispatch_state_change()
}

pub fn (mut request XMLHttpRequest) receive_chunk(bytes []u8) {
	if request.state !in [.headers_received, .loading] {
		return
	}
	request.state = .loading
	request.received_bytes << bytes
	request.response_cache = none
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
	request.handle_errors()!
	if request.response_.network_error != none || request.response_.aborted || request.timed_out {
		return
	}
	request.complete_upload()
	transmitted := u64(request.received_bytes.len)
	length := request.content_length()
	if !request.synchronous {
		request.dispatch('progress', transmitted, length)
	}
	request.state = .done
	request.send_flag = false
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
		request.request_error_steps('timeout', 'TimeoutError: Timed out')!
	}
}

fn (mut request XMLHttpRequest) request_error_steps(event string, exception_message string) ! {
	request.state = .done
	request.send_flag = false
	request.response_ = MockResponse{
		network_error: 'Failed to load'
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
	if (request.state == .opened && request.send_flag)
		|| request.state in [.headers_received, .loading] {
		request.request_error_steps('abort', '') or {}
	}
	if request.state == .done {
		request.state = .unsent
		request.response_ = MockResponse{}
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
	if request.received_bytes.len == 0 {
		return
	}
	final_mime := request.get_final_mime_type()
	if !final_mime.is_html() && !final_mime.is_xml() {
		return
	}
	if request.response_type_ == .empty && final_mime.is_html() {
		return
	}
	request.response_cache = XHRResponse{
		type_:         .document
		document_text: request.get_text_response()
	}
}

pub fn (mut request XMLHttpRequest) response_xml() !XHRDocumentResult {
	if request.response_type_ !in [.empty, .document] {
		return error('InvalidStateError: XHR responseXML can only be used for responseType empty or document')
	}
	if request.state != .done || request.response_.network_error != none {
		return XHRDocumentResult{}
	}
	parsed := request.final_mime_type_record() or { return XHRDocumentResult{} }
	if !parsed.is_html() && !parsed.is_xml() {
		return XHRDocumentResult{}
	}
	if request.response_type_ == .empty && parsed.is_html() {
		return XHRDocumentResult{}
	}
	return XHRDocumentResult{
		document_text: request.received_bytes.bytestr()
	}
}

pub fn (mut request XMLHttpRequest) response() XHRResponse {
	if cached := request.response_cache {
		return cached
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
				result = XHRResponse{
					type_: .blob
					blob:  fileapi.Blob.create(request.received_bytes.clone(),
						request.final_mime_type())
				}
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
	request.response_cache = result
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
	return result or { mimesniff.MimeType.parse('text/xml') or { panic(err) } }
}

fn (request &XMLHttpRequest) final_mime_type_record() ?mimesniff.MimeType {
	return request.get_final_mime_type()
}

pub fn (request &XMLHttpRequest) get_final_mime_type() mimesniff.MimeType {
	if override := request.override_mime_type_ {
		return mimesniff.MimeType.parse(override) or { panic(err) }
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
}

pub fn (request &XMLHttpRequest) must_survive_garbage_collection() bool {
	active := (request.state == .opened && request.send_flag)
		|| request.state in [.headers_received, .loading]
	return active && (request.onreadystatechange() || request.has_relevant_listener())
}

pub fn is_legacy_uppercased_byte_less_than(a string, b string) bool {
	return a.to_upper() < b.to_upper()
}
