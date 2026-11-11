// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
@[has_globals]
module browserjs

import dom
import encoding
import fetch
import fileapi
import libjs
import streams
import webidl

__global fetch_bindings_ = map[voidptr]&FetchHost{}

// A page's module loader can share the Fetch transport's connection pool.
// The Fetch binding owns its lifetime; each consumer still creates its own
// policy-bearing requests and cancels its own operations when it closes.
pub fn (runtime &Runtime) installed_fetch_transport() ?&fetch.FetchHost {
	host := fetch_bindings_[voidptr(runtime)] or { return none }
	if host.closed { return none }
	return host.transport
}

pub fn (mut host FetchHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner := voidptr(&runtime)
	if previous := fetch_bindings_[owner] {
		if voidptr(previous) == voidptr(&host) { return }
		return error('Fetch binding already belongs to another native owner')
	}
	readable := runtime.readable_stream_host() or { return error('Fetch requires its native ReadableStream binding') }
	if readable.closed || voidptr(readable.settings) != voidptr(host.settings) {
		return error('Fetch requires its owning relevant-realm ReadableStream binding')
	}
	host.runtime = &runtime
	host.to_string = runtime.evaluate_host_value(r'(function(value){return `${value}`})')!
	host.json_parse = runtime.evaluate_host_value(r'JSON.parse')!
	host.json_serialize = runtime.evaluate_host_value(r'JSON.stringify')!
	handle := voidptr(&host)
	operate := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &FetchHost(handle) }
		name := host.runtime.binding_dom_string(host.argument(args, 0))!
		return host.operate(name, args) or {
			reason := host.runtime.binding_exception_value(err)
			if name == 'fetch' || name.starts_with('body.') && name !in ['body.body', 'body.bodyUsed', 'body.textStream'] {
				capability := host.runtime.create_javascript_promise()!
				host.runtime.reject_javascript_promise(capability, reason)!
				host.runtime.release_javascript_promise(capability)
				return capability.promise
			}
			return host.runtime.actual_javascript_exception(reason)
		}
	})!
	convert := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		host := unsafe { &FetchHost(handle) }
		text := host.byte_string(host.argument(args, 0)) or { return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err)) }
		return host.byte_value(text)
	})!
	factory := runtime.evaluate_host_value(fetch_native_factory)!
	defer { runtime.release_javascript_value(factory) }
	installed := runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		operate,
		convert,
		C.JSContextGetGlobalObject(runtime.context),
	])!
	runtime.retain_javascript_value(installed)!
	defer { runtime.release_javascript_value(installed) }
	for kind, name in {
		FetchWrapperKind.headers: 'headers'
		.request:                 'request'
		.response:                'response'
	} {
		host.prototypes[kind] = runtime.retain_javascript_value(runtime.binding_property(installed, name)!)!
	}
	host.header_pairs = runtime.retain_javascript_value(runtime.binding_property(installed, 'pairs')!)!
	register_runtime_binding(mut fetch_bindings_, owner, &host)
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &FetchHost(handle) }
		host.close()
		unregister_runtime_binding(mut fetch_bindings_, owner)
	})
}

fn (host &FetchHost) argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (host &FetchHost) dom_string(value voidptr) !libjs.Utf16String {
	actual := host.runtime.call_javascript_function(host.to_string, C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [value])!
	return host.runtime.native_utf16_string(actual)
}

fn (host &FetchHost) usv_string(value voidptr) !string {
	return host.dom_string(value)!.to_well_formed().str()
}

fn (host &FetchHost) byte_string(value voidptr) !string {
	units := host.dom_string(value)!.code_units()
	mut bytes := []u8{cap: units.len}
	for unit in units {
		if unit > 255 {
			return error('TypeError: ByteString contains a character greater than 255')
		}
		bytes << u8(unit)
	}
	return bytes.bytestr()
}

// Fetch's ByteString values contain Latin-1 code units, not UTF-8 bytes.
fn (host &FetchHost) byte_value(value string) !voidptr {
	mut units := []u16{cap: value.len}
	for byte in value.bytes() { units << u16(byte) }
	return host.runtime.binding_utf16_string(libjs.utf16_string_from_code_units(units))
}

fn (host &FetchHost) array(items []voidptr) !voidptr {
	mut exception := unsafe { nil }
	result := C.vox_jsc_JSObjectMakeArray(host.runtime.context, uint(items.len), items.data, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	return result
}

fn (host &FetchHost) index(value voidptr, index int) !voidptr {
	mut exception := unsafe { nil }
	result := C.vox_jsc_JSObjectGetPropertyAtIndex(host.runtime.context, value, u32(index), &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	return result
}

fn (host &FetchHost) pairs(value voidptr) ![]fetch.HeaderPair {
	array := host.runtime.call_javascript_function(host.header_pairs, C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [value])!
	host.runtime.retain_javascript_value(array)!
	defer { host.runtime.release_javascript_value(array) }
	length := host.runtime.binding_property(array, 'length')!
	mut exception := unsafe { nil }
	count := int(C.vox_jsc_JSValueToNumber(host.runtime.context, length, &exception))
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	mut pairs := []fetch.HeaderPair{cap: count}
	for i in 0 .. count {
		pair := host.index(array, i)!
		pairs << fetch.HeaderPair{ name: host.byte_string(host.index(pair, 0)!)!, value: host.byte_string(host.index(pair, 1)!)! }
	}
	return pairs
}

fn (host &FetchHost) record(value voidptr, kind FetchWrapperKind) !&FetchHostRecord {
	if host.closed { return error('TypeError: Fetch binding is closed') }
	record := host.by_wrapper[value] or { return error('TypeError: Illegal Fetch interface receiver') }
	if record.kind != kind { return error('TypeError: Illegal Fetch interface receiver') }
	return record
}

fn (mut host FetchHost) wrap(kind FetchWrapperKind, native voidptr, prototype voidptr) !voidptr {
	if object := host.by_native[native] { return object }
	object := C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
	base := host.prototypes[kind] or { return error('Fetch prototype is unavailable') }
	C.JSObjectSetPrototype(host.runtime.context, object, if C.JSValueIsObject(host.runtime.context, prototype) {
		prototype
	} else {
		base
	})
	host.runtime.retain_javascript_value(object)!
	host.by_wrapper[object] = &FetchHostRecord{ kind: kind, native: native, object: object }
	host.by_native[native] = object
	return object
}

pub fn (runtime &Runtime) native_fetch_response(value voidptr) !&fetch.ResponseObject {
	host := fetch_bindings_[voidptr(runtime)] or { return error('Fetch binding is unavailable') }
	record := host.record(value, .response)!
	return unsafe { &fetch.ResponseObject(record.native) }
}

fn (mut host FetchHost) body_init(value voidptr) !FetchOptionalBody {
	if C.JSValueIsNull(host.runtime.context, value) || C.JSValueIsUndefined(host.runtime.context, value) {
		return FetchOptionalBody{}
	}
	if data := host.runtime.native_form_data(value) {
		serialized := serialize_native_form_data(data)
		return FetchOptionalBody{ value: fetch.BodyInit{ kind: .form_data, bytes: serialized.serialized_data, type_: 'multipart/form-data; boundary=${serialized.boundary}' } }
	}
	if blob := host.runtime.native_blob(value) {
		return FetchOptionalBody{ value: fetch.BodyInit{ kind: .blob, bytes: blob.raw_bytes(), type_: blob.type_() } }
	}
	if params := host.runtime.native_url_search_params(value) {
		return FetchOptionalBody{ value: fetch.BodyInit{ kind: .url_search_params, text: params.to_string() } }
	}
	if stream := host.runtime.native_readable_stream(value) {
		return FetchOptionalBody{ value: fetch.BodyInit{ kind: .readable_stream, stream: stream, stream_locked: stream.locked(), stream_disturbed: stream.disturbed() } }
	}
	if blobs := blob_bindings_[voidptr(host.runtime)] {
		if blobs.is_buffer_part(value)! {
			host.runtime.call_javascript_function(blobs.buffer_validation, C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [
				value,
				C.vox_jsc_JSValueMakeBoolean(host.runtime.context, true),
			])!
			mut owner := unsafe { &BlobHost(blobs) }
			return FetchOptionalBody{ value: fetch.BodyInit{ kind: .bytes, bytes: owner.copy_part_buffer(value)! } }
		}
	}
	return FetchOptionalBody{ value: fetch.BodyInit{ kind: .string_, text: host.usv_string(value)! } }
}

fn (host &FetchHost) dictionary(value voidptr) !bool {
	if C.JSValueIsNull(host.runtime.context, value) || C.JSValueIsUndefined(host.runtime.context, value) {
		return false
	}
	if !C.JSValueIsObject(host.runtime.context, value) {
		return error('TypeError: Dictionary argument is not an object')
	}
	return true
}

fn (host &FetchHost) member(value voidptr, key string) !voidptr {
	if C.JSValueIsObject(host.runtime.context, value) {
		return host.runtime.binding_property(value, key)
	}
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (host &FetchHost) optional_string(value voidptr, usv bool, bytes bool) !FetchOptionalString {
	if C.JSValueIsUndefined(host.runtime.context, value) { return FetchOptionalString{} }
	if bytes { return FetchOptionalString{ value: host.byte_string(value)! } }
	if usv { return FetchOptionalString{ value: host.usv_string(value)! } }
	return FetchOptionalString{ value: host.dom_string(value)!.str() }
}

fn (host &FetchHost) enum_string(value voidptr, values []string) !FetchOptionalString {
	if C.JSValueIsUndefined(host.runtime.context, value) { return FetchOptionalString{} }
	text := host.dom_string(value)!.str()
	if text !in values { return error('TypeError: Invalid Fetch enumeration value') }
	return FetchOptionalString{ value: text }
}

fn (mut host FetchHost) request(input voidptr, options voidptr) !&fetch.RequestObject {
	// RequestInfo conversion precedes RequestInit's lexicographically ordered members.
	mut source := fetch.RequestInput{ environment: fetch.RequestClient(host.settings) }
	mut input_url := ?string(none)
	if record := host.by_wrapper[input] {
		if record.kind == .request {
			source = fetch.RequestInput{ request: unsafe { &fetch.RequestObject(record.native) }, environment: fetch.RequestClient(host.settings) }
		}
	}
	if source.request == none {
		input_url = host.usv_string(input)!
	}
	_ := host.dictionary(options)!
	body_value := host.member(options, 'body')!
	body := host.body_init(body_value)!.value
	cache := host.enum_string(host.member(options, 'cache')!, ['default', 'no-store', 'reload',
		'no-cache', 'force-cache', 'only-if-cached'])!.value
	credentials := host.enum_string(host.member(options, 'credentials')!, ['omit', 'same-origin',
		'include'])!.value
	duplex := host.enum_string(host.member(options, 'duplex')!, ['half'])!.value
	header_value := host.member(options, 'headers')!
	headers := if C.JSValueIsUndefined(host.runtime.context, header_value) {
		?[]fetch.HeaderPair(none)
	} else {
		?[]fetch.HeaderPair(host.pairs(header_value)!)
	}
	integrity := host.optional_string(host.member(options, 'integrity')!, false, false)!.value
	keepalive_value := host.member(options, 'keepalive')!
	keepalive := if C.JSValueIsUndefined(host.runtime.context, keepalive_value) {
		?bool(none)
	} else {
		?bool(C.JSValueToBoolean(host.runtime.context, keepalive_value))
	}
	method := host.optional_string(host.member(options, 'method')!, false, true)!.value
	mode := host.enum_string(host.member(options, 'mode')!, ['navigate', 'same-origin', 'no-cors',
		'cors'])!.value
	priority := host.enum_string(host.member(options, 'priority')!, ['high', 'low', 'auto'])!.value
	redirect := host.enum_string(host.member(options, 'redirect')!, ['follow', 'error', 'manual'])!.value
	referrer := host.optional_string(host.member(options, 'referrer')!, true, false)!.value
	policy := host.enum_string(host.member(options, 'referrerPolicy')!, ['', 'no-referrer',
		'no-referrer-when-downgrade', 'same-origin', 'origin', 'strict-origin',
		'origin-when-cross-origin', 'strict-origin-when-cross-origin', 'unsafe-url'])!.value
	signal_value := host.member(options, 'signal')!
	mut signal := ?&dom.AbortSignal(none)
	if !C.JSValueIsUndefined(host.runtime.context, signal_value) && !C.JSValueIsNull(host.runtime.context, signal_value) {
		signal = host.runtime.native_abort_signal(signal_value)!
	}
	window_value := host.member(options, 'window')!
	// URL parsing is part of the constructor algorithm, after IDL conversion.
	if text := input_url {
		url := dom.dom_url_parse(text, host.settings.fetch_request_client_api_base_url(), 'UTF-8') or { return error('TypeError: Invalid request URL') }
		source = fetch.RequestInput{ url: url, environment: fetch.RequestClient(host.settings) }
	}
	return fetch.RequestObject.construct(source, fetch.RequestInit{
		body:            body
		body_present:    !C.JSValueIsUndefined(host.runtime.context, body_value)
		cache:           if text := cache { ?fetch.CacheMode(fetch_cache_mode(text)) } else { none }
		credentials:     if text := credentials {
			?fetch.CredentialsMode(match text {
				'omit' { fetch.CredentialsMode.omit }
				'include' { .include }
				else { .same_origin }
			})
		} else {
			none
		}
		duplex:          if duplex != none { ?fetch.RequestDuplex(.half) } else { none }
		headers:         headers
		integrity:       integrity
		keepalive:       keepalive
		method:          method
		mode:            if text := mode {
			?fetch.Mode(match text {
				'navigate' { fetch.Mode.navigate }
				'no-cors' { .no_cors }
				'same-origin' { .same_origin }
				else { .cors }
			})
		} else {
			none
		}
		priority:        if text := priority {
			?fetch.Priority(match text {
				'high' { fetch.Priority.high }
				'low' { .low }
				else { .auto }
			})
		} else {
			none
		}
		redirect:        if text := redirect {
			?fetch.RedirectMode(match text {
				'manual' { fetch.RedirectMode.manual }
				'error' { .error }
				else { .follow }
			})
		} else {
			none
		}
		referrer:        referrer
		referrer_policy: policy
		signal:          signal
		window_present:  !C.JSValueIsUndefined(host.runtime.context, window_value)
		window_non_null: !C.JSValueIsUndefined(host.runtime.context, window_value) && !C.JSValueIsNull(host.runtime.context, window_value)
	})
}

fn fetch_cache_mode(text string) fetch.CacheMode {
	return match text {
		'no-store' { .no_store }
		'reload' { .reload }
		'no-cache' { .no_cache }
		'force-cache' { .force_cache }
		'only-if-cached' { .only_if_cached }
		else { .default }
	}
}

fn (mut host FetchHost) response_init(value voidptr) !fetch.ResponseInit {
	_ := host.dictionary(value)!
	header_value := host.member(value, 'headers')!
	headers := if C.JSValueIsUndefined(host.runtime.context, header_value) {
		[]fetch.HeaderPair{}
	} else {
		host.pairs(header_value)!
	}
	status_value := host.member(value, 'status')!
	mut status := u16(200)
	if !C.JSValueIsUndefined(host.runtime.context, status_value) {
		mut exception := unsafe { nil }
		number := C.vox_jsc_JSValueToNumber(host.runtime.context, status_value, &exception)
		if exception != unsafe { nil } {
			return host.runtime.actual_javascript_exception(exception)
		}
		status = u16(webidl.convert_to_int(webidl.number_value(number), 16, false, .no, .no)!)
	}
	status_text := host.optional_string(host.member(value, 'statusText')!, false, true)!.value or { '' }
	return fetch.ResponseInit{ status: status, status_text: status_text, headers: headers, headers_present: !C.JSValueIsUndefined(host.runtime.context, header_value) }
}

fn (mut host FetchHost) operate(name string, args []voidptr) !voidptr {
	if host.closed { return error('TypeError: Fetch binding is closed') }
	context := host.runtime.context
	receiver := host.argument(args, 1)
	value := host.argument(args, 2)
	other := host.argument(args, 3)
	undefined := C.vox_jsc_JSValueMakeUndefined(context)
	match name {
		'fetch', 'constructRequest' {
			if args.len < 5 || !C.JSValueToBoolean(context, host.argument(args, 4)) {
				return error('TypeError: Request input is required')
			}
			request := host.request(value, other)!
			if name == 'fetch' { return host.start_fetch(request) }
			return host.wrap(.request, voidptr(request), receiver)
		}
		'constructResponse' {
			body := host.body_init(value)!.value
			init := host.response_init(other)!
			return host.wrap(.response, voidptr(fetch.ResponseObject.construct(body, init)!), receiver)
		}
		'constructHeaders' {
			pairs := if C.JSValueIsUndefined(context, value) {
				[]fetch.HeaderPair{}
			} else {
				host.pairs(value)!
			}
			return host.wrap(.headers, voidptr(fetch.Headers.construct(pairs)!), receiver)
		}
		'response.error' {
			return host.wrap(.response, voidptr(fetch.ResponseObject.error()), undefined)
		}
		'response.redirect' {
			url := host.usv_string(value)!
			mut status := u16(302)
			if !C.JSValueIsUndefined(context, other) {
				mut exception := unsafe { nil }
				number := C.vox_jsc_JSValueToNumber(context, other, &exception)
				if exception != unsafe { nil } {
					return host.runtime.actual_javascript_exception(exception)
				}
				status = u16(webidl.convert_to_int(webidl.number_value(number), 16, false, .no, .no)!)
			}
			return host.wrap(.response, voidptr(fetch.ResponseObject.redirect(url, status, host.settings.fetch_request_client_api_base_url())!), undefined)
		}
		'response.json' {
			init := host.response_init(other)!
			text := host.runtime.call_javascript_function(host.json_serialize, undefined, [value])!
			if C.JSValueIsUndefined(context, text) {
				return error('TypeError: Value cannot be serialized to JSON')
			}
			body := fetch.BodyWithType{ body: fetch.Body.from_bytes(host.usv_string(text)!.bytes(), .bytes), type_: 'application/json' }
			return host.wrap(.response, voidptr(fetch.Response.create_with_body(init, body)!), undefined)
		}
		else {}
	}
	if name.starts_with('headers.') {
		record := host.record(receiver, .headers)!
		mut headers := unsafe { &fetch.Headers(record.native) }
		method := name[8..]
		if method == 'entries' {
			mut pairs := []voidptr{}
			for pair in headers.sorted_and_combined() {
				pairs << host.array([host.byte_value(pair.name)!, host.byte_value(pair.value)!])!
			}
			return host.array(pairs)
		}
		if method == 'getSetCookie' {
			mut values := []voidptr{}
			for cookie in headers.get_set_cookie() { values << host.byte_value(cookie)! }
			return host.array(values)
		}
		if args.len < 4 || !C.JSValueToBoolean(context, host.argument(args, 4)) {
			return error('TypeError: Header name is required')
		}
		key := host.byte_string(value)!
		match method {
			'get' {
				_ := headers.has(key)!
				if result := headers.get(key) { return host.byte_value(result) }
				return C.vox_jsc_JSValueMakeNull(context)
			}
			'has' { return C.vox_jsc_JSValueMakeBoolean(context, headers.has(key)!) }
			'delete' { headers.delete(key)! }
			'append', 'set' {
				mut exception := unsafe { nil }
				count := C.vox_jsc_JSValueToNumber(context, host.argument(args, 4), &exception)
				if count < 2 { return error('TypeError: Header value is required') }
				text := host.byte_string(other)!
				if method == 'append' {
					headers.append(key, text)!
				} else {
					headers.set(key, text)!
				}
			}
			else { return error('Unknown Headers operation') }
		}
		return undefined
	}
	if name.starts_with('request.') {
		record := host.record(receiver, .request)!
		request := unsafe { &fetch.RequestObject(record.native) }
		text := match name[8..] {
			'method' { request.method() }
			'url' { request.url() }
			'destination' {
				if destination := request.destination() {
					destination.str().replace('_', '')
				} else {
					''
				}
			}
			'referrer' { request.referrer() }
			'referrerPolicy' { request.referrer_policy() }
			'mode' { request.mode().str().replace('_', '-') }
			'credentials' { request.credentials().str().replace('_', '-') }
			'cache' { request.cache().str().replace('_', '-') }
			'redirect' { request.redirect_mode().str() }
			'integrity' { request.integrity() }
			'duplex' { 'half' }
			'headers' { return host.wrap(.headers, voidptr(request.headers()), undefined) }
			'signal' { return host.runtime.javascript_abort_signal(request.signal()) }
			'keepalive' { return C.vox_jsc_JSValueMakeBoolean(context, request.keepalive()) }
			'isReloadNavigation' {
				return C.vox_jsc_JSValueMakeBoolean(context, request.is_reload_navigation())
			}
			'isHistoryNavigation' {
				return C.vox_jsc_JSValueMakeBoolean(context, request.is_history_navigation())
			}
			'clone' { return host.wrap(.request, voidptr(request.clone()!), undefined) }
			else { return error('Unknown Request operation') }
		}
		return host.runtime.binding_string(text)
	}
	if name.starts_with('response.') {
		record := host.record(receiver, .response)!
		response := unsafe { &fetch.ResponseObject(record.native) }
		match name[9..] {
			'type' { return host.runtime.binding_string(response.type_().str().replace('_', '')) }
			'url' { return host.runtime.binding_string(response.url()) }
			'redirected' { return C.vox_jsc_JSValueMakeBoolean(context, response.redirected()) }
			'status' { return C.vox_jsc_JSValueMakeNumber(context, response.status()) }
			'ok' { return C.vox_jsc_JSValueMakeBoolean(context, response.ok()) }
			'statusText' { return host.byte_value(response.status_text()) }
			'headers' { return host.wrap(.headers, voidptr(response.headers()), undefined) }
			'clone' { return host.wrap(.response, voidptr(response.clone()!), undefined) }
			else { return error('Unknown Response operation') }
		}
	}
	if name.starts_with('body.') {
		if name == 'body.textStream' { return host.body_text_stream(receiver) }
		record := host.by_wrapper[receiver] or { return error('TypeError: Illegal Body receiver') }
		mixin := match record.kind {
			.request { unsafe { &fetch.RequestObject(record.native) }.body_mixin() }
			.response { unsafe { &fetch.ResponseObject(record.native) }.body_mixin() }
			else { return error('TypeError: Illegal Body receiver') }
		}
		if name == 'body.bodyUsed' { return C.vox_jsc_JSValueMakeBoolean(context, mixin.body_used()) }
		if name == 'body.body' {
			if body := mixin.body { return host.runtime.javascript_readable_stream(body.stream()) }
			return C.vox_jsc_JSValueMakeNull(context)
		}
		return host.consume_body(name[5..], mixin)
	}
	return error('Unknown Fetch operation')
}

fn (host &FetchHost) body_text_stream(receiver voidptr) !voidptr {
	mut owner := unsafe { &FetchHost(host) }
	if receiver !in owner.by_wrapper {
		// Resolve the native receiver across same-agent Window realms without
		// consulting author-visible properties or allocating in the method realm.
		group := C.JSContextGetGroup(host.runtime.context)
		for _, candidate in fetch_bindings_ {
			if candidate.closed || candidate.runtime.closed || candidate.runtime.context == unsafe { nil }
				|| C.JSContextGetGroup(candidate.runtime.context) != group { continue }
			if receiver in candidate.by_wrapper { owner = candidate; break }
		}
	}
	record := owner.by_wrapper[receiver] or { return error('TypeError: Illegal Body receiver') }
	mixin := match record.kind {
		.request { unsafe { &fetch.RequestObject(record.native) }.body_mixin() }
		.response { unsafe { &fetch.ResponseObject(record.native) }.body_mixin() }
		else { return error('TypeError: Illegal Body receiver') }
	}
	readable := owner.runtime.readable_stream_host() or { return error('Fetch ReadableStream binding is unavailable') }
	stream := owner.settings.body_text_stream_in_realm(mixin, readable.read_loop_realm())!
	return owner.runtime.javascript_readable_stream(stream)
}

fn (mut host FetchHost) body_result(method string, bytes []u8, mime string) !voidptr {
	match method {
		'arrayBuffer' {
			return host.runtime.actual_webidl_value(host.runtime.source_array_buffer(bytes)!)
		}
		'bytes' {
			return host.runtime.actual_webidl_value(host.runtime.source_uint8_array(host.runtime.source_array_buffer(bytes)!)!)
		}
		'blob' { return host.runtime.javascript_blob(fileapi.Blob.create(bytes, mime)) }
		'text', 'json' {
			decoder := encoding.TextDecoder.create()
			text := host.runtime.binding_string(decoder.decode(bytes, encoding.TextDecodeOptions{})!)
			if method == 'text' { return text }
			return host.runtime.call_javascript_function(host.json_parse, C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [text])
		}
		else { return error('TypeError: Unknown Body operation') }
	}
}

fn (mut host FetchHost) consume_body(method string, mixin fetch.BodyMixin) !voidptr {
	if mixin.is_unusable() { return error('TypeError: Body is unusable') }
	capability := host.runtime.create_javascript_promise()!
	mut stream := if body := mixin.body {
		body.stream()
	} else {
		fetch.Body.from_bytes([], .bytes).stream()
	}
	readable := host.runtime.readable_stream_host() or { return error('Fetch ReadableStream binding is unavailable') }
	stream.set_realm(readable.read_loop_realm())
	mut reader := stream.get_default_reader() or {
		host.runtime.release_javascript_promise(capability)
		return err
	}
	mime := if type_ := mixin.mime_type { type_.serialized() } else { '' }
	handle := voidptr(&host)
	reader.read_all_bytes_with_steps(fn [handle, capability, method, mime] (bytes []u8) {
		mut host := unsafe { &FetchHost(handle) }
		if host.closed { return }
		defer {
			host.runtime.release_javascript_promise(capability)
			host.runtime.mark_document_state_dirty()
		}
		value := host.body_result(method, bytes, mime) or {
			host.runtime.reject_javascript_promise(capability, host.runtime.binding_exception_value(err)) or {}
			return
		}
		host.runtime.resolve_javascript_promise(capability, value) or {}
	}, fn [handle, capability] (reason webidl.Value) {
		mut host := unsafe { &FetchHost(handle) }
		if host.closed { return }
		defer {
			host.runtime.release_javascript_promise(capability)
			host.runtime.mark_document_state_dirty()
		}
		value := host.runtime.binding_exception_value(webidl.ValueException{ value: reason })
		host.runtime.reject_javascript_promise(capability, value) or {}
	})
	return capability.promise
}

fn (mut host FetchHost) start_fetch(request &fetch.RequestObject) !voidptr {
	capability := host.runtime.create_javascript_promise()!
	mut operation := &FetchHostOperation{ host: host, request: request, capability: capability }
	host.operations << operation
	mut signal := request.signal()
	if signal.aborted() {
		operation.abort()
		return capability.promise
	}
	algorithms := fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{
		process_response:             fn [mut operation] (response &fetch.Response) {
			if operation.finished || operation.host.closed { return }
			mut host := unsafe { &FetchHost(operation.host) }
			if response.fetch_response_aborted() {
				operation.abort()
				return
			}
			if response.is_network_error() {
				operation.reject(host.runtime.binding_exception_value(error('TypeError: ' + (response.network_error_message or { 'Failed to fetch' }))))
				operation.finish()
				return
			}
			object := fetch.ResponseObject.from_response(response, .immutable)
			operation.response = object
			wrapper := host.wrap(.response, voidptr(object), C.vox_jsc_JSValueMakeUndefined(host.runtime.context)) or {
				operation.reject(host.runtime.binding_exception_value(err))
				operation.finish()
				return
			}
			host.runtime.resolve_javascript_promise(operation.capability, wrapper) or {}
			operation.settled = true
			host.runtime.release_javascript_promise(operation.capability)
			host.runtime.mark_document_state_dirty()
		}
		process_response_end_of_body: fn [mut operation] (_ &fetch.Response) { operation.finish() }
	})
	operation.controller = fetch.fetch(request.internal_request(), algorithms, host.transport, .no)
	operation.abort_algorithm = signal.add_abort_algorithm(fn [mut operation] () {
		operation.abort()
	})
	return capability.promise
}

fn (mut operation FetchHostOperation) reject(reason voidptr) {
	if operation.settled { return }
	mut host := unsafe { &FetchHost(operation.host) }
	host.runtime.reject_javascript_promise(operation.capability, reason) or {}
	operation.settled = true
	host.runtime.release_javascript_promise(operation.capability)
	host.runtime.mark_document_state_dirty()
}

fn (mut operation FetchHostOperation) abort() {
	if operation.finished || operation.host.closed { return }
	mut host := unsafe { &FetchHost(operation.host) }
	reason := operation.request.signal().reason()
	actual := if reason.is_undefined() {
		host.runtime.javascript_dom_exception(webidl.dom_exception_value(webidl.DOMException.create('AbortError', 'Fetch was aborted'))) or { host.runtime.binding_exception_value(err) }
	} else {
		host.runtime.event_callback_argument(reason) or { host.runtime.binding_exception_value(err) }
	}
	operation.reject(actual)
	if body := operation.request.body_mixin().body {
		mut stream := body.stream()
		if stream.state() == .readable {
			_ := streams.readable_stream_cancel(mut stream, streams.runtime_value(host.runtime.webidl_value(actual) or { webidl.undefined_value() }))
		}
	}
	if response := operation.response {
		if body := response.body_mixin().body {
			mut stream := body.stream()
			if stream.state() == .readable {
				stream.error_value(host.runtime.webidl_value(actual) or { webidl.undefined_value() })
			}
		}
	}
	if operation.controller != unsafe { nil } {
		operation.controller.stop_fetch()
		operation.controller.abort(none)
	}
	operation.finish()
}

fn (mut operation FetchHostOperation) finish() {
	if operation.finished { return }
	operation.finished = true
	mut signal := operation.request.signal()
	if id := operation.abort_algorithm {
		signal.remove_abort_algorithm(id)
		operation.abort_algorithm = none
	}
	mut host := unsafe { &FetchHost(operation.host) }
	for i, active in host.operations {
		if voidptr(active) == voidptr(&operation) {
			host.operations.delete(i)
			break
		}
	}
}

const fetch_native_factory = r'(function(operate,byteString,global){
 const define=Object.defineProperty,create=Object.create,descriptor=Object.getOwnPropertyDescriptor,
       keys=Reflect.ownKeys,apply=Reflect.apply,iterator=Symbol.iterator,tag=Symbol.toStringTag;
 const typeError=TypeError;
 function property(object,name,value){define(object,name,{value,writable:true,enumerable:true,configurable:true})}
 function getter(object,name,operation){const get=descriptor({get [name](){return operate(operation,this)}},name).get;define(object,name,{get,enumerable:true,configurable:true})}
 function prototype(constructor,name){const result=constructor.prototype;define(constructor,"prototype",{writable:false});define(result,tag,{value:name,configurable:true});return result}
 function pairs(value){
  if(value===null||(typeof value!=="object"&&typeof value!=="function"))throw new typeError("HeadersInit must be an object");
  const result=[],method=value[iterator];
  if(method!==undefined&&method!==null){
   if(typeof method!=="function")throw new typeError("HeadersInit iterator is not callable");
   const iterable={[iterator](){return apply(method,value,[])}};
   for(const pair of iterable){
    if(pair===null||(typeof pair!=="object"&&typeof pair!=="function"))throw new typeError("Header pair must be an object");
    const converted=[];for(const item of pair)converted[converted.length]=byteString(item);
    if(converted.length!==2)throw new typeError("Header pair must contain two items");
    result[result.length]=converted;
   }
  }else{
   for(const key of keys(value)){if(typeof key!=="string")continue;const entry=descriptor(value,key);if(entry&&entry.enumerable)result[result.length]=[byteString(key),byteString(value[key])]}
  }
  return result;
 }
 function Headers(){if(!new.target)throw new typeError("Headers requires new");return operate("constructHeaders",new.target.prototype,arguments[0])}
 function Request(input){if(!new.target)throw new typeError("Request requires new");return operate("constructRequest",new.target.prototype,input,arguments[1],arguments.length)}
 function Response(){if(!new.target)throw new typeError("Response requires new");return operate("constructResponse",new.target.prototype,arguments[0],arguments[1])}
 const headers=prototype(Headers,"Headers"),request=prototype(Request,"Request"),response=prototype(Response,"Response");
 for(const operation of ["append","set"]){const method=({[operation](name,value){return operate("headers."+operation,this,name,value,arguments.length)}})[operation];property(headers,operation,method)}
 for(const operation of ["delete","get","has"]){const method=({[operation](name){return operate("headers."+operation,this,name,undefined,arguments.length)}})[operation];property(headers,operation,method)}
 property(headers,"getSetCookie",({getSetCookie(){return operate("headers.getSetCookie",this)}}).getSetCookie);
 const iteratorPrototype=create(Object.getPrototypeOf(Object.getPrototypeOf([][iterator]())));
 define(iteratorPrototype,tag,{value:"Headers Iterator",configurable:true});
 const iteratorRecords=new WeakMap(),weakGet=WeakMap.prototype.get,weakSet=WeakMap.prototype.set;
 property(iteratorPrototype,"next",({next(){
  const record=apply(weakGet,iteratorRecords,[this]);if(!record)throw new typeError("Illegal Headers iterator receiver");
  const values=operate("headers.entries",record.owner);
  if(record.index>=values.length)return {value:undefined,done:true};
  const pair=values[record.index++];return {value:record.kind==="keys"?pair[0]:record.kind==="values"?pair[1]:pair,done:false};
 }}).next);
 for(const name of ["keys","values","entries"]){const method=({[name](){
  operate("headers.entries",this);const result=create(iteratorPrototype);apply(weakSet,iteratorRecords,[result,{owner:this,index:0,kind:name}]);return result;
 }})[name];property(headers,name,method)}
 define(headers,iterator,{value:headers.entries,writable:true,configurable:true});
 property(headers,"forEach",({forEach(callback){
  let values=operate("headers.entries",this);if(typeof callback!=="function")throw new typeError("Headers callback is not callable");
  for(let index=0;index<values.length;index++){const pair=values[index];apply(callback,arguments[1],[pair[1],pair[0],this]);values=operate("headers.entries",this)}
 }}).forEach);
 for(const name of ["method","url","headers","destination","referrer","referrerPolicy","mode","credentials","cache","redirect","integrity","keepalive","isReloadNavigation","isHistoryNavigation","signal","duplex"])getter(request,name,"request."+name);
 for(const name of ["type","url","redirected","status","ok","statusText","headers"])getter(response,name,"response."+name);
 // https://fetch.spec.whatwg.org/#dom-body-formdata
 function percentDecode(bytes){
  const result=[];
  for(let index=0;index<bytes.length;index++){
   const byte=bytes[index];
   if(byte===0x25&&index+2<bytes.length){
    const hex=String.fromCharCode(bytes[index+1],bytes[index+2]);
    if(/^[0-9A-Fa-f]{2}$/.test(hex)){result.push(parseInt(hex,16));index+=2;continue;}
   }
   result.push(byte);
  }
  return new Uint8Array(result);
 }
 function utf8(bytes){return new TextDecoder("utf-8",{ignoreBOM:true}).decode(bytes);}
 // https://url.spec.whatwg.org/#concept-urlencoded-parser
 function urlencoded(bytes){
  const form=new FormData();
  let start=0;
  for(let index=0;index<=bytes.length;index++){
   if(index<bytes.length&&bytes[index]!==0x26)continue;
   const sequence=bytes.slice(start,index);start=index+1;
   if(!sequence.length)continue;
   const equals=sequence.indexOf(0x3D);
   const name=(equals<0?sequence:sequence.slice(0,equals)).map(byte=>byte===0x2B?0x20:byte);
   const value=(equals<0?new Uint8Array(0):sequence.slice(equals+1)).map(byte=>byte===0x2B?0x20:byte);
   form.append(utf8(percentDecode(name)),utf8(percentDecode(value)));
  }
  return form;
 }
 function latin1(bytes){let text="";for(let index=0;index<bytes.length;index++)text+=String.fromCharCode(bytes[index]);return text;}
 function multipart(bytes,boundary){
  const form=new FormData(),text=latin1(bytes),delimiter="--"+boundary;
  let position=text.indexOf(delimiter);
  if(position<0)throw new typeError("Invalid multipart/form-data body");
  for(;;){
   position+=delimiter.length;
   if(text.startsWith("--",position))return form;
   if(!text.startsWith("\r\n",position))throw new typeError("Invalid multipart/form-data body");
   position+=2;
   const headerEnd=text.indexOf("\r\n\r\n",position);
   if(headerEnd<0)throw new typeError("Invalid multipart/form-data body");
   let name=null,filename=null,contentType="text/plain";
   for(const line of text.slice(position,headerEnd).split("\r\n")){
    const colon=line.indexOf(":");if(colon<0)throw new typeError("Invalid multipart/form-data header");
    const field=line.slice(0,colon).trim().toLowerCase(),value=line.slice(colon+1).trim();
    if(field==="content-disposition"){
     if(!/^form-data\s*(;|$)/i.test(value))throw new typeError("Invalid multipart/form-data disposition");
     const nameMatch=/;\s*name="([^"]*)"/i.exec(value),fileMatch=/;\s*filename="([^"]*)"/i.exec(value);
     if(nameMatch)name=utf8(Uint8Array.from(nameMatch[1],character=>character.charCodeAt(0)));
     if(fileMatch)filename=utf8(Uint8Array.from(fileMatch[1],character=>character.charCodeAt(0)));
    }else if(field==="content-type")contentType=value;
   }
   if(name===null)throw new typeError("multipart/form-data part has no name");
   const bodyStart=headerEnd+4,next=text.indexOf("\r\n"+delimiter,bodyStart);
   if(next<0)throw new typeError("Invalid multipart/form-data body");
   const part=bytes.slice(bodyStart,next);
   if(filename!==null)form.append(name,new File([part],filename,{type:contentType}));
   else form.append(name,utf8(part));
   position=next+2;
  }
 }
 function parseFormData(bytes,type){
  const essence=type.split(";")[0].trim().toLowerCase();
  if(essence==="application/x-www-form-urlencoded")return urlencoded(bytes);
  if(essence==="multipart/form-data"){
   const boundary=/;\s*boundary=(?:"([^"]*)"|([^;\s]*))/i.exec(type);
   if(!boundary||!(boundary[1]||boundary[2]))throw new typeError("multipart/form-data has no boundary");
   return multipart(bytes,boundary[1]||boundary[2]);
  }
  throw new typeError("Body is not form data");
 }
 for(const [target,kind] of [[request,"request"],[response,"response"]]){
  property(target,"formData",({formData(){
   const type=String(operate(kind+".headers",this).get("Content-Type")||"");
   return operate("body.bytes",this).then(bytes=>parseFormData(bytes,type));
  }}).formData);
  property(target,"clone",({clone(){return operate(kind+".clone",this)}}).clone);
  for(const name of ["body","bodyUsed"])getter(target,name,"body."+name);
  for(const name of ["text","json","arrayBuffer","bytes","blob","textStream"]){const method=({[name](){return operate("body."+name,this)}})[name];property(target,name,method)}
 }
 property(Response,"error",({error(){return operate("response.error")}}).error);
 property(Response,"redirect",({redirect(url){if(!arguments.length)throw new typeError("URL is required");return operate("response.redirect",undefined,url,arguments[1])}}).redirect);
 property(Response,"json",({json(data){if(!arguments.length)throw new typeError("Data is required");return operate("response.json",undefined,data,arguments[1])}}).json);
 const fetch=({fetch(input){return operate("fetch",undefined,input,arguments[1],arguments.length)}}).fetch;
 for(const [name,value] of [["Headers",Headers],["Request",Request],["Response",Response],["fetch",fetch]])property(global,name,value);
 return {headers,request,response,pairs};
})'
