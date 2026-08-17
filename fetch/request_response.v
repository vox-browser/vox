// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the Web-exposed Fetch Request and Response objects.
module fetch

import dom
import http

pub enum RequestDuplex {
	half
}

pub struct RequestInit {
pub:
	method          ?string
	headers         ?[]HeaderPair
	body            ?BodyInit
	referrer        ?string
	referrer_policy ?string
	mode            ?Mode
	credentials     ?CredentialsMode
	cache           ?CacheMode
	redirect        ?RedirectMode
	integrity       ?string
	keepalive       ?bool
	signal          ?&dom.AbortSignal
	duplex          ?RequestDuplex
	priority        ?Priority
	window_non_null bool
}

fn (init RequestInit) is_empty() bool {
	return init.method == none && init.headers == none && init.body == none && init.referrer == none
		&& init.referrer_policy == none && init.mode == none && init.credentials == none
		&& init.cache == none && init.redirect == none && init.integrity == none
		&& init.keepalive == none && init.signal == none && init.duplex == none
		&& init.priority == none && !init.window_non_null
}

pub struct RequestInput {
pub:
	url     ?dom.URL
	request ?&RequestObject
}

@[heap]
pub struct RequestObject {
mut:
	request_ &Request         = unsafe { nil }
	headers_ &Headers         = unsafe { nil }
	signal_  &dom.AbortSignal = unsafe { nil }
	body_    ?&Body
}

pub fn RequestObject.construct(input RequestInput, init RequestInit) !&RequestObject {
	if init.window_non_null {
		return error('TypeError: RequestInit.window must be null')
	}
	init_is_empty := init.is_empty()
	mut request := if source := input.request { source.request_.clone() } else { Request.create() }
	if input.request == none {
		url := input.url or { return error('TypeError: Request input URL is required') }
		if url.username() != '' || url.password() != '' {
			return error('TypeError: Request URL contains credentials')
		}
		request.set_url(url)
		request.mode = .cors
	} else {
		request.destination = none
	}
	request.unsafe_request = true
	request.initiator_type = .fetch
	if !init_is_empty {
		if request.mode == .navigate {
			request.mode = .same_origin
		}
		request.reload_navigation = false
		request.history_navigation = false
		request.origin = RequestOrigin{}
		request.referrer = Referrer{}
		request.referrer_policy = ''
		request.set_url(request.current_url())
	}
	if mode := init.mode {
		if mode == .navigate { return error('TypeError: navigate mode cannot be constructed') }
		request.mode = mode
	}
	if method := init.method {
		if !http.is_method(method) {
			return error('TypeError: Invalid request method')
		}
		if http.is_forbidden_method(method) {
			return error('TypeError: Forbidden request method')
		}
		request.method = http.normalize_method(method)
	}
	if credentials := init.credentials { request.credentials_mode = credentials }
	if cache := init.cache { request.cache_mode = cache }
	if redirect := init.redirect { request.redirect_mode = redirect }
	if integrity := init.integrity { request.integrity_metadata = integrity }
	if keepalive := init.keepalive { request.keepalive = keepalive }
	if priority := init.priority { request.priority = priority }
	if referrer_policy := init.referrer_policy { request.referrer_policy = referrer_policy }
	if referrer := init.referrer {
		if referrer == '' {
			request.referrer = Referrer{
				sentinel: .no_referrer
			}
		} else {
			base := request.url()
			parsed := dom.dom_url_parse(referrer, base, 'UTF-8') or {
				return error('TypeError: Invalid referrer URL')
			}
			if parsed.serialize() == 'about:client' || parsed.origin().value != base.origin().value {
				request.referrer = Referrer{}
			} else {
				request.referrer = Referrer{
					url: parsed
				}
			}
		}
	}
	if request.cache_mode == .only_if_cached && request.mode != .same_origin {
		return error('TypeError: only-if-cached requires same-origin mode')
	}
	if request.mode == .no_cors && request.method !in ['GET', 'HEAD', 'POST'] {
		return error('TypeError: Method is not CORS-safelisted')
	}
	guard := if request.mode == .no_cors {
		HeadersGuard.request_no_cors
	} else {
		HeadersGuard.request
	}
	mut headers := Headers.from_header_list(request.header_list, guard)
	if init_headers := init.headers {
		headers = Headers.construct([])!
		headers.set_guard(guard)
		for pair in init_headers {
			headers.append(pair.name, pair.value)!
		}
		request.header_list = headers.header_list()
	} else if !init_is_empty {
		existing := request.header_list.headers()
		headers = Headers.construct([])!
		headers.set_guard(guard)
		for header in existing {
			headers.append(header.name, header.value)!
		}
		request.header_list = headers.header_list()
	}
	mut body := ?&Body(none)
	if body_init := init.body {
		if request.method in ['GET', 'HEAD'] {
			return error('TypeError: GET/HEAD requests cannot have a body')
		}
		if body_init.kind == .readable_stream && init.duplex == none {
			return error('TypeError: ReadableStream body requires duplex=half')
		}
		if body_init.kind == .readable_stream && request.mode !in [Mode.same_origin, .cors] {
			return error('TypeError: ReadableStream body requires same-origin or cors mode')
		}
		extracted := extract_body(body_init, request.keepalive)!
		body = extracted.body
		request.body = RequestBody{
			kind:  .body_object
			bytes: extracted.body.bytes()
		}
		if content_type := extracted.type_ {
			if !request.header_list.contains('Content-Type') {
				request.header_list.append(http.Header{ name: 'Content-Type', value: content_type })
			}
		}
		if body_init.kind == .readable_stream {
			request.use_cors_preflight = true
		}
	} else if source := input.request {
		body = source.body_
		if source_body := body {
			if source_body.source_kind == .readable_stream
				&& request.mode !in [Mode.same_origin, .cors] {
				return error('TypeError: ReadableStream body requires same-origin or cors mode')
			}
			if source_body.source_kind == .readable_stream {
				request.use_cors_preflight = true
			}
		}
	}
	source_signal := init.signal or {
		if source := input.request { source.signal_ } else { dom.AbortSignal.new() }
	}

	signal := dom.AbortSignal.create_dependent_abort_signal([source_signal])!
	return &RequestObject{
		request_: request
		headers_: headers
		signal_:  signal
		body_:    body
	}
}

pub fn (object &RequestObject) internal_request() &Request {
	return object.request_
}

pub fn (object &RequestObject) method() string {
	return object.request_.method
}

pub fn (object &RequestObject) url() string {
	return object.request_.url().serialize()
}

pub fn (object &RequestObject) headers() &Headers {
	return object.headers_
}

pub fn (object &RequestObject) destination() ?Destination {
	return object.request_.destination
}

pub fn (object &RequestObject) referrer() string {
	if object.request_.referrer.sentinel == .no_referrer { return '' }
	if url := object.request_.referrer.url { return url.serialize() }
	return 'about:client'
}

pub fn (object &RequestObject) referrer_policy() string {
	return object.request_.referrer_policy
}

pub fn (object &RequestObject) mode() Mode {
	return object.request_.mode
}

pub fn (object &RequestObject) credentials() CredentialsMode {
	return object.request_.credentials_mode
}

pub fn (object &RequestObject) cache() CacheMode {
	return object.request_.cache_mode
}

pub fn (object &RequestObject) redirect_mode() RedirectMode {
	return object.request_.redirect_mode
}

pub fn (object &RequestObject) integrity() string {
	return object.request_.integrity_metadata
}

pub fn (object &RequestObject) keepalive() bool {
	return object.request_.keepalive
}

pub fn (object &RequestObject) is_reload_navigation() bool {
	return object.request_.reload_navigation
}

pub fn (object &RequestObject) is_history_navigation() bool {
	return object.request_.history_navigation
}

pub fn (object &RequestObject) signal() &dom.AbortSignal {
	return object.signal_
}

pub fn (object &RequestObject) duplex() RequestDuplex {
	return .half
}

pub fn (object &RequestObject) body_mixin() BodyMixin {
	return BodyMixin{
		body:      object.body_
		mime_type: extract_mime_type(object.request_.header_list)
	}
}

pub fn (object &RequestObject) clone() !&RequestObject {
	if object.body_mixin().is_unusable() {
		return error('TypeError: Body is unusable')
	}
	request := object.request_.clone()
	body := if source_body := object.body_ { ?&Body(source_body.clone()) } else { ?&Body(none) }
	signal := dom.AbortSignal.create_dependent_abort_signal([object.signal_])!
	return &RequestObject{
		request_: request
		headers_: Headers.from_header_list(request.header_list, object.headers_.guard())
		signal_:  signal
		body_:    body
	}
}

pub struct ResponseInit {
pub:
	status      u16 = 200
	status_text string
	headers     []HeaderPair
}

@[heap]
pub struct ResponseObject {
mut:
	response_ &Response = unsafe { nil }
	headers_  &Headers  = unsafe { nil }
	body_     ?&Body
}

fn valid_status_text(value string) bool {
	return value.bytes().all(it == 0x09 || (it >= 0x20 && it <= 0x7e))
}

pub fn ResponseObject.construct(body_init ?BodyInit, init ResponseInit) !&ResponseObject {
	if init.status < 200 || init.status > 599 {
		return error('RangeError: Invalid response status')
	}
	if !valid_status_text(init.status_text) {
		return error('TypeError: Invalid response status text')
	}
	mut response := Response.create()
	response.status = init.status
	response.status_message = init.status_text
	mut headers := Headers.construct(init.headers)!
	headers.set_guard(.response)
	response.header_list = headers.header_list()
	mut body := ?&Body(none)
	if init_body := body_init {
		if is_null_body_status(init.status) {
			return error('TypeError: Null-body status cannot have a body')
		}
		extracted := extract_body(init_body, false)!
		body = extracted.body
		response.body = extracted.body.bytes()
		if content_type := extracted.type_ {
			if !response.header_list.contains('Content-Type') {
				response.header_list.append(http.Header{ name: 'Content-Type', value: content_type })
			}
		}
	}
	return &ResponseObject{
		response_: response
		headers_:  headers
		body_:     body
	}
}

pub fn ResponseObject.error() &ResponseObject {
	response := Response.network_error('Network error')
	return &ResponseObject{
		response_: response
		headers_:  Headers.from_header_list(response.header_list, .immutable)
	}
}

pub fn ResponseObject.redirect(url string, status u16) !&ResponseObject {
	if status !in [u16(301), 302, 303, 307, 308] {
		return error('RangeError: Invalid redirect status')
	}
	parsed := dom.dom_url_parse(url, dom.URL{'about:blank'}, 'UTF-8') or {
		return error('TypeError: Invalid redirect URL')
	}
	mut object := ResponseObject.construct(none, ResponseInit{
		status:  status
		headers: [HeaderPair{ name: 'Location', value: parsed.serialize() }]
	})!
	object.headers_.set_guard(.immutable)
	return object
}

pub fn ResponseObject.json(data string, init ResponseInit) !&ResponseObject {
	mut headers := init.headers.clone()
	if !headers.any(equals_ignoring_ascii_case(it.name, 'content-type')) {
		headers << HeaderPair{
			name:  'Content-Type'
			value: 'application/json'
		}
	}
	return ResponseObject.construct(BodyInit{ kind: .bytes, bytes: data.bytes() }, ResponseInit{
		status:      init.status
		status_text: init.status_text
		headers:     headers
	})
}

pub fn (object &ResponseObject) type_() ResponseType {
	return object.response_.response_type
}

pub fn (object &ResponseObject) url() string {
	mut url := object.response_.url() or { return '' }
	url.set_fragment(none)
	return url.serialize()
}

pub fn (object &ResponseObject) redirected() bool {
	return object.response_.url_list.len > 1
}

pub fn (object &ResponseObject) status() u16 {
	return object.response_.status
}

pub fn (object &ResponseObject) ok() bool {
	return is_ok_status(object.response_.status)
}

pub fn (object &ResponseObject) status_text() string {
	return object.response_.status_message
}

pub fn (object &ResponseObject) headers() &Headers {
	return object.headers_
}

pub fn (object &ResponseObject) body_mixin() BodyMixin {
	return BodyMixin{
		body:      object.body_
		mime_type: extract_mime_type(object.response_.header_list)
	}
}

pub fn (object &ResponseObject) clone() !&ResponseObject {
	if object.body_mixin().is_unusable() { return error('TypeError: Body is unusable') }
	response := object.response_.clone()
	return &ResponseObject{
		response_: response
		headers_:  Headers.from_header_list(response.header_list, object.headers_.guard())
		body_:     if body := object.body_ { body.clone() } else { none }
	}
}

pub fn fetch_request(input RequestInput, init RequestInit, host &FetchHost) !&ResponseObject {
	request_object := RequestObject.construct(input, init)!
	params := FetchParams.create(request_object.internal_request(), FetchTimingInfo.create())
	response := main_fetch(params, host).response() or { return error('NetworkError: No response') }
	if response.is_network_error() { return error(response.network_error_message or {
			'NetworkError'}) }
	body := if bytes := response.body { Body.from_bytes(bytes, .bytes) } else { none }
	return &ResponseObject{
		response_: response
		headers_:  Headers.from_header_list(response.header_list, .immutable)
		body_:     body
	}
}
