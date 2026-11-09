module browserjs

import indexeddb

// IndexedDB keys use their own conversion algorithm, not structured clone.
// Only an array's indexed own properties participate; internal Date/buffer
// slots are read through the bridge's captured engine intrinsics.
fn (mut runtime Runtime) indexed_db_key(value voidptr) !indexeddb.Key {
	binding := indexed_db_bindings_[voidptr(&runtime)] or { return error('Missing IndexedDB binding') }
	mut ancestors := map[voidptr]bool{}
	key := runtime.indexed_db_key_value(binding.clone, value, mut ancestors)!
	if !key.is_valid() { return error('DataError: invalid IndexedDB key') }
	return key
}

fn (mut runtime Runtime) indexed_db_key_value(bridge &StructuredCloneBridge, value voidptr, mut ancestors map[voidptr]bool) !indexeddb.Key {
	if C.JSValueIsNumber(runtime.context, value) {
		return indexeddb.number_key(bridge.number(value)!)
	}
	if C.JSValueIsString(runtime.context, value) {
		return indexeddb.string_key(runtime.native_utf16_string(value)!.str())
	}
	if !C.JSValueIsObject(runtime.context, value) { return indexeddb.invalid_key() }
	if ancestors[value] { return indexeddb.invalid_key() }
	if C.JSValueIsArray(runtime.context, value) {
		length := int(bridge.number(bridge.engine('array_length', [value])!)!)
		ancestors[value] = true
		defer { ancestors.delete(value) }
		mut items := []indexeddb.Key{}
		for index in 0 .. length {
			name := runtime.indexed_db_string(index.str())
			if !C.JSValueToBoolean(runtime.context, bridge.engine('has_own', [value, name])!) {
				return indexeddb.invalid_key()
			}
			item := runtime.retain_javascript_value(bridge.engine('get', [value, name])!)!
			defer { runtime.release_javascript_value(item) }
			key := runtime.indexed_db_key_value(bridge, item, mut ancestors)!
			if !key.is_valid() { return key }
			items << key
		}
		return indexeddb.array_key(items)
	}
	tag := int(bridge.number(bridge.engine('classify', [value])!)!)
	if tag == 11 {
		return indexeddb.date_key(bridge.number(bridge.engine('date_value', [value])!)!)
	}
	if tag in [22, 23] { return runtime.indexed_db_binary_key(bridge, value, tag == 23) }
	return indexeddb.invalid_key()
}

fn (mut runtime Runtime) indexed_db_binary_key(bridge &StructuredCloneBridge, value voidptr, view bool) !indexeddb.Key {
	mut buffer := value
	mut offset := 0
	mut length := 0
	if view {
		metadata := runtime.retain_javascript_value(bridge.engine('view_metadata', [value])!)!
		defer { runtime.release_javascript_value(metadata) }
		if C.JSValueIsNull(runtime.context, metadata) { return indexeddb.invalid_key() }
		buffer = bridge.engine('list_item', [metadata, C.vox_jsc_JSValueMakeNumber(runtime.context, 0)])!
		length = int(bridge.number(bridge.engine('list_item', [metadata,
			C.vox_jsc_JSValueMakeNumber(runtime.context, 2)])!)!)
		offset = int(bridge.number(bridge.engine('list_item', [metadata,
			C.vox_jsc_JSValueMakeNumber(runtime.context, 3)])!)!)
	}
	if C.JSValueToBoolean(runtime.context, bridge.engine('is_shared_buffer', [buffer])!) {
		return indexeddb.invalid_key()
	}
	metadata := runtime.retain_javascript_value(bridge.engine('buffer_metadata', [buffer])!)!
	defer { runtime.release_javascript_value(metadata) }
	if C.JSValueIsUndefined(runtime.context, metadata) {
		return error('DataError: Native ArrayBuffer slot getters are unavailable')
	}
	if C.JSValueToBoolean(runtime.context, bridge.engine('list_item', [metadata,
		C.vox_jsc_JSValueMakeNumber(runtime.context, 0)])!) {
		return indexeddb.invalid_key()
	}
	mut exception := unsafe { nil }
	buffer_length := C.vox_jsc_JSObjectGetArrayBufferByteLength(runtime.context, buffer, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	if buffer_length > uint(2147483647) {
		return error('DataError: Binary key exceeds translated byte-array capacity')
	}
	if !view { length = int(buffer_length) }
	// Copy before borrowing a C pointer: JSC pins buffers crossing that API,
	// whereas using a key must leave the author's buffer transferable.
	copy := runtime.retain_javascript_value(bridge.engine('copy_buffer', [buffer])!)!
	defer { runtime.release_javascript_value(copy) }
	pointer := C.vox_jsc_JSObjectGetTypedArrayBytesPtr(runtime.context, copy, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	if offset < 0 || length < 0 || offset > int(buffer_length) - length {
		return indexeddb.invalid_key()
	}
	if length == 0 { return indexeddb.binary_key([]u8{}) }
	if pointer == unsafe { nil } { return indexeddb.invalid_key() }
	bytes := unsafe { (&u8(pointer)).vbytes(int(buffer_length))[offset..offset + length].clone() }
	return indexeddb.binary_key(bytes)
}
