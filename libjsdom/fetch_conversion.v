// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import fetch
import libjs

struct FetchOptionalText { value ?string }
struct FetchBodyValue { value ?fetch.BodyInit }

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

fn fetch_body_init(mut vm libjs.VM, value libjs.Value) !FetchBodyValue {
	if value.is_nullish() { return FetchBodyValue{} }
	if value.is_object() {
		object := value.as_object()
		if buffer := object.array_buffer {
			if buffer.is_detached() { return vm.throw_error(.type_error, 'Detached Fetch body buffer') }
			return FetchBodyValue{value: fetch.BodyInit{kind: .bytes, bytes: buffer.data_block().read_bytes(0, buffer.byte_length())}}
		}
		if array := object.typed_array {
			record := libjs.make_typed_array_with_buffer_witness_record(array, .seq_cst)
			if libjs.is_typed_array_out_of_bounds(record) { return vm.throw_error(.type_error, 'Out of bounds Fetch body view') }
			return FetchBodyValue{value: fetch.BodyInit{kind: .bytes, bytes: array.viewed_buffer.data_block().read_bytes(uint(array.byte_offset), uint(libjs.typed_array_byte_length(record)))}}
		}
		if object.data_view != none { return vm.throw_error(.type_error, 'DataView Fetch bodies are not translated yet') }
	}
	return FetchBodyValue{value: fetch.BodyInit{kind: .string_, text: value.to_primitive_string(mut vm)!.utf16.to_well_formed().str()}}
}

fn (host &Host) fetch_error_value(mut vm libjs.VM, err IError) libjs.Value {
	if libjs.is_throw_completion(err) { return libjs.thrown_value(err) }
	message := err.msg()
	kind := if message.starts_with('RangeError:') { libjs.ErrorKind.range_error } else if message.starts_with('SyntaxError:') { libjs.ErrorKind.syntax_error } else { libjs.ErrorKind.type_error }
	return libjs.Value.from_object(libjs.create_error(mut vm, host.realm, kind, libjs.utf16_string(message.all_after(': '))))
}

fn (host &Host) fetch_request(mut vm libjs.VM, input libjs.Value, options libjs.Value) !&fetch.RequestObject {
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
	body := fetch_body_init(mut vm, body_value)!.value
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
	if !signal.is_nullish() { return vm.throw_error(.type_error, 'AbortSignal Fetch binding is not translated yet') }
	window := fetch_member(mut vm, options, 'window')!
	if source.request == none {
		url := dom.dom_url_parse(address, client.fetch_request_client_api_base_url(), 'UTF-8') or { return vm.throw_error(.type_error, 'Invalid request URL') }
		source = fetch.RequestInput{url: url, environment: client}
	}
	return fetch.RequestObject.construct(source, fetch.RequestInit{
		body: body, body_present: !body_value.is_undefined(), headers: headers,
		cache: if text := cache { ?fetch.CacheMode(match text { 'no-store'{.no_store} 'reload'{.reload} 'no-cache'{.no_cache} 'force-cache'{.force_cache} 'only-if-cached'{.only_if_cached} else{.default} }) } else { none },
		credentials: if text := credentials { ?fetch.CredentialsMode(match text { 'omit'{.omit} 'include'{.include} else{.same_origin} }) } else { none },
		duplex: if duplex != none { ?fetch.RequestDuplex(.half) } else { none },
		integrity: integrity, keepalive: if keepalive_value.is_undefined() { none } else { ?bool(keepalive_value.to_boolean()) }, method: method,
		mode: if text := mode { ?fetch.Mode(match text { 'navigate'{.navigate} 'same-origin'{.same_origin} 'no-cors'{.no_cors} else{.cors} }) } else { none },
		priority: if text := priority { ?fetch.Priority(match text { 'high'{.high} 'low'{.low} else{.auto} }) } else { none },
		redirect: if text := redirect { ?fetch.RedirectMode(match text { 'error'{.error} 'manual'{.manual} else{.follow} }) } else { none },
		referrer: referrer, referrer_policy: referrer_policy, window_present: !window.is_undefined(), window_non_null: !window.is_nullish(),
	})
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
