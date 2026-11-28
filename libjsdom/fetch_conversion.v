// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import domurl
import fetch
import fileapi
import libjs
import streams
import webidl
import xhr

struct FetchOptionalText { value ?string }
struct FetchBodyValue {
	value ?fetch.BodyInit
	blob ?&fileapi.Blob
	query ?&domurl.URLSearchParams
	buffer ?&libjs.Object
	stream ?&streams.ReadableStream
	form ?&xhr.FormData
}

fn fetch_dictionary(mut vm libjs.VM, value libjs.Value) ! {
	if !value.is_nullish() && !value.is_object() { return vm.throw_error(.type_error, 'Fetch dictionary must be an object') }
}

fn fetch_member(mut vm libjs.VM, dictionary libjs.Value, key string) !libjs.Value {
	return if dictionary.is_object() { dictionary.as_object().get(mut vm, libjs.PropertyName.from_str(key))! } else { libjs.js_undefined() }
}

fn fetch_text(mut vm libjs.VM, value libjs.Value, kind int) !FetchOptionalText {
	if value.is_undefined() { return FetchOptionalText{} }
	if kind == 2 { return FetchOptionalText{value: headers_byte_string(mut vm, value)!} }
	text := value.to_primitive_string(mut vm)!.utf16
	return FetchOptionalText{value: if kind == 1 { text.to_well_formed().str() } else { text.str() }}
}

fn fetch_enum(mut vm libjs.VM, value libjs.Value, allowed []string) !FetchOptionalText {
	text := fetch_text(mut vm, value, 0)!.value
	if actual := text { if actual !in allowed { return vm.throw_error(.type_error, 'Invalid Fetch enum value: ' + actual) } }
	return FetchOptionalText{value: text}
}

fn (host &Host) fetch_body_init(mut vm libjs.VM, value libjs.Value) !FetchBodyValue {
	if value.is_nullish() { return FetchBodyValue{} }
	if value.is_object() {
		object := value.as_object()
		if stream := host.readable_streams[voidptr(object)] { return FetchBodyValue{stream: stream} }
		if blob := host.blobs[voidptr(object)] { return FetchBodyValue{blob: blob} }
		if form := host.form_data[voidptr(object)] { return FetchBodyValue{form: form} }
		if query := host.queries[voidptr(object)] { return FetchBodyValue{query: query} }
		if object.array_buffer != none || object.typed_array != none || object.slots.data_view != none {
			return FetchBodyValue{buffer: native_buffer_source(mut vm, value, false)!}
		}
	}
	return FetchBodyValue{value: fetch.BodyInit{kind: .string_, text: value.to_primitive_string(mut vm)!.utf16.to_well_formed_utf8()}}
}

fn (body FetchBodyValue) materialize(mut vm libjs.VM) !FetchBodyValue {
	if form := body.form { return materialize_form_data_body(mut vm, form) }
	if stream := body.stream {
		return FetchBodyValue{value: fetch.BodyInit{kind: .readable_stream, stream: stream, stream_locked: stream.locked(), stream_disturbed: stream.is_disturbed()}}
	}
	if blob := body.blob {
		charge_buffer_source_work(mut vm, blob.size())!
		return FetchBodyValue{value: fetch.BodyInit{kind: .blob, bytes: blob.raw_bytes(), type_: blob.type_()}}
	}
	if query := body.query {
		text := query.to_string()
		charge_buffer_source_work(mut vm, u64(text.len))!
		return FetchBodyValue{value: fetch.BodyInit{kind: .url_search_params, text: text}}
	}
	if buffer := body.buffer { return FetchBodyValue{value: fetch.BodyInit{kind: .bytes, bytes: copy_native_buffer_source(mut vm, buffer)!}} }
	return body
}

fn (host &Host) fetch_error_value(mut vm libjs.VM, err IError) libjs.Value {
	if libjs.is_throw_completion(err) { return libjs.thrown_value(err) }
	if err is webidl.ValueException {
		mut owner := unsafe { &Host(host) }
		return owner.abort_reason_value(mut vm, err.value) or {
			libjs.Value.from_object(libjs.create_error(mut vm, host.realm, .type_error, libjs.utf16_string(err.msg())))
		}
	}
	message := err.msg()
	kind := if message.starts_with('RangeError:') { libjs.ErrorKind.range_error } else if message.starts_with('SyntaxError:') { libjs.ErrorKind.syntax_error } else { libjs.ErrorKind.type_error }
	return libjs.Value.from_object(libjs.create_error(mut vm, host.realm, kind, libjs.utf16_string(message.all_after(': '))))
}

fn (host &Host) fetch_request(mut vm libjs.VM, input libjs.Value, options libjs.Value, new_target ?&libjs.Object) !(&fetch.RequestObject, ?&libjs.Object) {
	client := host.fetch_client or { return vm.throw_error(.type_error, 'Fetch has no owning environment') }
	mut source := fetch.RequestInput{environment: client}
	if input.is_object() {
		if native := host.fetch_requests[voidptr(input.as_object())] { source = fetch.RequestInput{request: native, environment: client} }
	}
	mut address := ''
	if source.request == none { address = input.to_primitive_string(mut vm)!.utf16.to_well_formed().str() }
	fetch_dictionary(mut vm, options)!
	// WebIDL converts dictionary members in lexicographic order, before the
	// native Request constructor validates and applies the resulting snapshot.
	body_value := fetch_member(mut vm, options, 'body')!
	converted_body := host.fetch_body_init(mut vm, body_value)!
	cache := fetch_enum(mut vm, fetch_member(mut vm, options, 'cache')!, ['default','no-store','reload','no-cache','force-cache','only-if-cached'])!.value
	credentials := fetch_enum(mut vm, fetch_member(mut vm, options, 'credentials')!, ['omit','same-origin','include'])!.value
	duplex := fetch_enum(mut vm, fetch_member(mut vm, options, 'duplex')!, ['half'])!.value
	header_value := fetch_member(mut vm, options, 'headers')!
	headers := if header_value.is_undefined() { ?[]fetch.HeaderPair(none) } else { ?[]fetch.HeaderPair(headers_init(mut vm, header_value)!) }
	integrity := fetch_text(mut vm, fetch_member(mut vm, options, 'integrity')!, 0)!.value
	keepalive_value := fetch_member(mut vm, options, 'keepalive')!
	method := fetch_text(mut vm, fetch_member(mut vm, options, 'method')!, 2)!.value
	mode := fetch_enum(mut vm, fetch_member(mut vm, options, 'mode')!, ['navigate','same-origin','no-cors','cors'])!.value
	priority := fetch_enum(mut vm, fetch_member(mut vm, options, 'priority')!, ['high','low','auto'])!.value
	redirect := fetch_enum(mut vm, fetch_member(mut vm, options, 'redirect')!, ['follow','error','manual'])!.value
	referrer := fetch_text(mut vm, fetch_member(mut vm, options, 'referrer')!, 1)!.value
	referrer_policy := fetch_enum(mut vm, fetch_member(mut vm, options, 'referrerPolicy')!, ['', 'no-referrer','no-referrer-when-downgrade','same-origin','origin','strict-origin','origin-when-cross-origin','strict-origin-when-cross-origin','unsafe-url'])!.value
	signal := fetch_member(mut vm, options, 'signal')!
	native_signal := if signal.is_nullish() { ?&dom.AbortSignal(none) } else { ?&dom.AbortSignal(host.signal_value(mut vm, signal)!) }
	window := fetch_member(mut vm, options, 'window')!
	mut prototype := ?&libjs.Object(none)
	if target := new_target {
		parent := target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		if parent.is_object() { prototype = parent.as_object() }
	}
	if source.request == none {
		url := dom.dom_url_parse(address, client.fetch_request_client_api_base_url(), 'UTF-8') or { return vm.throw_error(.type_error, 'Invalid request URL') }
		source = fetch.RequestInput{url: url, environment: client}
	}
	body := converted_body.materialize(mut vm)!.value
	return fetch.RequestObject.construct(source, fetch.RequestInit{
		body: body, body_present: !body_value.is_undefined(), headers: headers,
		signal: native_signal, signal_present: !signal.is_undefined(),
		cache: if text := cache { ?fetch.CacheMode(match text { 'no-store'{.no_store} 'reload'{.reload} 'no-cache'{.no_cache} 'force-cache'{.force_cache} 'only-if-cached'{.only_if_cached} else{.default} }) } else { none },
		credentials: if text := credentials { ?fetch.CredentialsMode(match text { 'omit'{.omit} 'include'{.include} else{.same_origin} }) } else { none },
		duplex: if duplex != none { ?fetch.RequestDuplex(.half) } else { none },
		integrity: integrity, keepalive: if keepalive_value.is_undefined() { none } else { ?bool(keepalive_value.to_boolean()) }, method: method,
		mode: if text := mode { ?fetch.Mode(match text { 'navigate'{.navigate} 'same-origin'{.same_origin} 'no-cors'{.no_cors} else{.cors} }) } else { none },
		priority: if text := priority { ?fetch.Priority(match text { 'high'{.high} 'low'{.low} else{.auto} }) } else { none },
		redirect: if text := redirect { ?fetch.RedirectMode(match text { 'error'{.error} 'manual'{.manual} else{.follow} }) } else { none },
		referrer: referrer, referrer_policy: referrer_policy, window_present: !window.is_undefined(), window_non_null: !window.is_nullish(),
	})!, prototype
}

fn fetch_response_init(mut vm libjs.VM, dictionary libjs.Value) !fetch.ResponseInit {
	fetch_dictionary(mut vm, dictionary)!
	header_value := fetch_member(mut vm, dictionary, 'headers')!
	headers := if header_value.is_undefined() { []fetch.HeaderPair{} } else { headers_init(mut vm, header_value)! }
	status := fetch_member(mut vm, dictionary, 'status')!
	code := if status.is_undefined() { u16(200) } else { u16(status.to_u32(mut vm)!) }
	text := fetch_text(mut vm, fetch_member(mut vm, dictionary, 'statusText')!, 2)!.value
	return fetch.ResponseInit{headers: headers, headers_present: !header_value.is_undefined(), status: code, status_text: text or { '' }}
}
