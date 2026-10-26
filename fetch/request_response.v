// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the Web-exposed Fetch Request and Response objects.
module fetch

import dom
import http
import infra

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
	// Web IDL dictionaries distinguish an omitted nullable member from a
	// present member whose value is null.
	body_present    bool
	window_present  bool
	window_non_null bool
}

fn (init RequestInit) is_empty() bool {
	return init.method == none && init.headers == none && init.body == none && init.referrer == none
		&& init.referrer_policy == none && init.mode == none && init.credentials == none
		&& init.cache == none && init.redirect == none && init.integrity == none
		&& init.keepalive == none && init.signal == none && init.duplex == none
		&& init.priority == none && !init.body_present && !init.window_present
		&& !init.window_non_null
}

pub struct RequestInput {
pub:
	url     ?dom.URL
	request ?&RequestObject
	// The relevant settings object supplied by the bindings layer. It carries
	// the API base URL, origin, and request client without introducing a Fetch
	// -> HTML import cycle.
	environment ?RequestClient
}

@[heap]
pub struct RequestObject {
mut:
	request_ &Request = unsafe { nil }
	headers_ &Headers = unsafe { nil }
	signal_  &dom.AbortSignal = unsafe { nil }
}

pub fn Request.create_for_constructor(input RequestInput, init RequestInit) !&RequestObject {
	return RequestObject.construct(input, init)
}

pub fn Request.create_with_settings(environment RequestClient, input RequestInput, init RequestInit) !&RequestObject {
	return RequestObject.construct(RequestInput{
		url: input.url
		request: input.request
		environment: environment
	}, init)
}

pub fn RequestObject.construct(input RequestInput, init RequestInit) !&RequestObject {
	if init.window_non_null {
		return error('TypeError: RequestInit.window must be null')
	}

	// Steps 1-6: obtain the input request, fallback mode, base URL, and signal.
	mut fallback_mode := ?Mode(none)
	mut input_request := if source := input.request {
		source.request_
	} else {
		url := input.url or { return error('TypeError: Request input URL is required') }
		if url.username() != '' || url.password() != '' {
			return error('TypeError: Request URL contains credentials')
		}
		mut created := Request.create()
		created.set_url(url)
		fallback_mode = .cors
		created
	}
	base_url := if environment := input.environment {
		environment.fetch_request_client_api_base_url()
	} else {
		input_request.url()
	}
	relevant_origin := if environment := input.environment {
		environment.fetch_request_client_origin()
	} else {
		base_url.origin()
	}

	// Steps 8-12: construct the new infrastructure request by copying only the
	// fields listed by Fetch. In particular this is deliberately not Request::clone().
	mut traversable_for_user_prompts := TraversableForUserPrompts.client
	if init.window_present || init.window_non_null {
		traversable_for_user_prompts = .no_traversable
	}
	mut copied_headers := http.HeaderList.create()
	for header in input_request.header_list.headers() {
		copied_headers.append(header)
	}
	mut request := Request.create()
	request.set_url(input_request.url())
	request.method = input_request.method
	request.header_list = copied_headers
	request.unsafe_request = true
	if environment := input.environment {
		request.set_client(environment)
	}
	request.traversable_for_user_prompts = traversable_for_user_prompts
	request.priority = input_request.priority
	request.origin = input_request.origin
	request.referrer = input_request.referrer
	request.referrer_policy = input_request.referrer_policy
	request.mode = input_request.mode
	request.credentials_mode = input_request.credentials_mode
	request.cache_mode = input_request.cache_mode
	request.redirect_mode = input_request.redirect_mode
	request.integrity_metadata = input_request.integrity_metadata
	request.keepalive = input_request.keepalive
	request.reload_navigation = input_request.reload_navigation
	request.history_navigation = input_request.history_navigation
	request.url_list = input_request.url_list.clone()
	request.initiator_type = .fetch

	init_is_empty := init.is_empty()
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
	mut mode := fallback_mode
	if init_mode := init.mode {
		mode = init_mode
	}
	if selected_mode := mode {
		if selected_mode == .navigate {
			return error('TypeError: navigate mode cannot be constructed')
		}
		request.mode = selected_mode
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
	if credentials := init.credentials {
		request.credentials_mode = credentials
	}
	if cache := init.cache {
		request.cache_mode = cache
	}
	if redirect := init.redirect {
		request.redirect_mode = redirect
	}
	if integrity := init.integrity {
		request.integrity_metadata = integrity
	}
	if keepalive := init.keepalive {
		request.keepalive = keepalive
	}
	if priority := init.priority {
		request.priority = priority
	}
	if referrer_policy := init.referrer_policy {
		request.referrer_policy = referrer_policy
	}
	if referrer := init.referrer {
		if referrer == '' {
			request.referrer = Referrer{
				sentinel: .no_referrer
			}
		} else {
			parsed := dom.dom_url_parse(referrer, base_url, 'UTF-8') or {
				return error('TypeError: Invalid referrer URL')
			}
			if (parsed.scheme() == 'about' && parsed.serialize_path() == 'client')
				|| !parsed.origin().is_same_origin(relevant_origin) {
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
	input_body_present := input_request.body.kind != .empty
	if (init.body != none || input_body_present) && request.method in ['GET', 'HEAD'] {
		return error('TypeError: GET/HEAD requests cannot have a body')
	}
	if body_init := init.body {
		if body_init.kind == .readable_stream && init.duplex == none {
			return error('TypeError: ReadableStream body requires duplex=half')
		}
		if body_init.kind == .readable_stream && request.mode !in [Mode.same_origin, .cors] {
			return error('TypeError: ReadableStream body requires same-origin or cors mode')
		}
		extracted := extract_body(body_init, request.keepalive)!
		body = extracted.body
		request.body = RequestBody{
			kind: .body_object
			body_object: extracted.body
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
		body = source.request_.body.body_object
		if source_body := body {
			if source_body.source_kind == .readable_stream
				&& request.mode !in [Mode.same_origin, .cors] {
				return error('TypeError: ReadableStream body requires same-origin or cors mode')
			}
			if source_body.source_kind == .readable_stream {
				request.use_cors_preflight = true
			}
		}
		if source.body_mixin().is_unusable() {
			return error('TypeError: Request is unusable')
		}
		request.body = RequestBody{
			kind: source.request_.body.kind
			bytes: source.request_.body.bytes.clone()
			body_object: source.request_.body.body_object
		}
	}
	mut signals := []&dom.AbortSignal{}
	if source_signal := init.signal {
		signals << source_signal
	} else if source := input.request {
		signals << source.signal_
	}
	signal := dom.AbortSignal.create_dependent_abort_signal(signals)!
	return &RequestObject{
		request_: request
		headers_: headers
		signal_: signal
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
	if object.request_.referrer.sentinel == .no_referrer {
		return ''
	}
	if url := object.request_.referrer.url {
		return url.serialize()
	}
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
		body: object.request_.body.body_object
		mime_type: extract_mime_type(object.request_.header_list)
	}
}

pub fn (object &RequestObject) clone() !&RequestObject {
	if object.body_mixin().is_unusable() {
		return error('TypeError: Body is unusable')
	}
	request := object.request_.clone()
	signal := dom.AbortSignal.create_dependent_abort_signal([object.signal_])!
	return &RequestObject{
		request_: request
		headers_: Headers.from_header_list(request.header_list, object.headers_.guard())
		signal_: signal
	}
}

pub struct ResponseInit {
pub:
	status          u16 = 200
	status_text     string
	headers         []HeaderPair
	headers_present bool
}

@[heap]
pub struct ResponseObject {
mut:
	response_ &Response = unsafe { nil }
	headers_  &Headers = unsafe { nil }
}

// Response.cpp::create(response, guard): retain the filtered infrastructure
// response and its live body instead of reconstructing a buffered response.
pub fn ResponseObject.from_response(response &Response, guard HeadersGuard) &ResponseObject {
	return &ResponseObject{
		response_: response
		headers_: Headers.from_header_list(response.header_list, guard)
	}
}

pub fn Response.create_with_body(init ResponseInit, body_with_type ?BodyWithType) !&ResponseObject {
	mut response := Response.create()
	mut object := &ResponseObject{
		response_: response
		headers_: Headers.from_header_list(response.header_list, .response)
	}
	object.initialize_response(init, body_with_type)!
	return object
}

pub fn Response.create_for_constructor(body_init ?BodyInit, init ResponseInit) !&ResponseObject {
	mut body_with_type := ?BodyWithType(none)
	if init_body := body_init {
		body_with_type = extract_body(init_body, false)!
	}
	return Response.create_with_body(init, body_with_type)
}

pub fn ResponseObject.construct(body_init ?BodyInit, init ResponseInit) !&ResponseObject {
	return Response.create_for_constructor(body_init, init)
}

pub fn ResponseObject.error() &ResponseObject {
	response := Response.network_error('Response created via `Response.error()`')
	return &ResponseObject{
		response_: response
		headers_: Headers.from_header_list(response.header_list, .immutable)
	}
}

pub fn ResponseObject.redirect(url string, status u16, api_base_url dom.URL) !&ResponseObject {
	parsed := dom.dom_url_parse(url, api_base_url, 'UTF-8') or {
		return error('TypeError: Invalid redirect URL')
	}
	if !is_redirect_status(status) {
		return error('RangeError: Invalid redirect status')
	}
	mut response := Response.create()
	response.status = status
	response.header_list.append(http.Header{ name: 'Location', value: parsed.serialize() })
	return &ResponseObject{
		response_: response
		headers_: Headers.from_header_list(response.header_list, .immutable)
	}
}

pub fn ResponseObject.json(data infra.JSONValue, init ResponseInit) !&ResponseObject {
	bytes := infra.serialize_javascript_value_to_json_bytes(data)!
	extracted := extract_body(BodyInit{ kind: .bytes, bytes: bytes }, false)!
	return Response.create_with_body(init, BodyWithType{
		body: extracted.body
		type_: 'application/json'
	})
}

pub fn (object &ResponseObject) type_() ResponseType {
	return object.response_.fetch_response_type()
}

pub fn (object &ResponseObject) url() string {
	mut url := object.response_.url() or { return '' }
	url.set_fragment(none)
	return url.serialize()
}

pub fn (object &ResponseObject) redirected() bool {
	return object.response_.fetch_response_url_list().len > 1
}

pub fn (object &ResponseObject) status() u16 {
	return object.response_.fetch_response_status()
}

pub fn (object &ResponseObject) ok() bool {
	return is_ok_status(object.response_.fetch_response_status())
}

pub fn (object &ResponseObject) status_text() string {
	return object.response_.fetch_response_status_message()
}

pub fn (object &ResponseObject) headers() &Headers {
	return object.headers_
}

pub fn (object &ResponseObject) body_mixin() BodyMixin {
	return BodyMixin{
		body: object.response_.fetch_response_body()
		mime_type: extract_mime_type(object.response_.header_list)
	}
}

pub fn (object &ResponseObject) clone() !&ResponseObject {
	if object.body_mixin().is_unusable() {
		return error('TypeError: Body is unusable')
	}
	response := object.response_.clone()
	return &ResponseObject{
		response_: response
		headers_: Headers.from_header_list(response.header_list, object.headers_.guard())
	}
}

pub fn fetch_request(input RequestInput, init RequestInit, host &FetchHost) !&ResponseObject {
	request_object := RequestObject.construct(input, init)!
	params := FetchParams.create(request_object.internal_request(), FetchTimingInfo.create())
	response := main_fetch(params, host).response() or { return error('NetworkError: No response') }
	if response.is_network_error() {
		return error(response.network_error_message or {
			'NetworkError'
		})
	}
	return &ResponseObject{
		response_: response
		headers_: Headers.from_header_list(response.header_list, .immutable)
	}
}
