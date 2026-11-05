module browserjs

import platform

// Keep an independent copy of the old conversion to compare JSC's exact UTF-8
// behavior, including embedded NULs, lone surrogates and conversion failures.
fn heap_jsc_string_conversion(context voidptr, value voidptr) !string {
	mut exception := unsafe { nil }
	text := C.vox_jsc_JSValueToStringCopy(context, value, &exception)
	if text == unsafe { nil } { return error('JavaScript value could not be converted to a string') }
	defer { C.JSStringRelease(text) }
	capacity := C.JSStringGetMaximumUTF8CStringSize(text)
	if capacity == 0 { return '' }
	mut bytes := []u8{len: int(capacity)}
	written := unsafe { C.JSStringGetUTF8CString(text, &char(bytes.data), capacity) }
	if written == 0 { return error('JavaScript string conversion failed') }
	return bytes[..int(written) - 1].bytestr()
}

fn assert_jsc_string_buffer_equivalence(context voidptr, units []u16) {
	text := C.JSStringCreateWithCharacters(units.data, uint(units.len))
	defer { C.JSStringRelease(text) }
	value := C.vox_jsc_JSValueMakeString(context, text)
	mut expected_error := ''
	expected := heap_jsc_string_conversion(context, value) or { expected_error = err.msg(); '' }
	mut actual_error := ''
	actual := js_string_to_v(context, value) or { actual_error = err.msg(); '' }
	assert actual_error == expected_error
	assert actual == expected
}

fn test_jsc_string_buffer_matches_the_heap_path_for_every_utf16_unit_and_size_boundary() {
	context := create_javascript_core_context(false)
	defer { release_javascript_core_context(context) }
	for count in [0, 1, 84, 85, 86, 255, 256, 1024, 100000] {
		assert_jsc_string_buffer_equivalence(context, []u16{len: count, init: u16(`a`)})
		assert_jsc_string_buffer_equivalence(context, []u16{len: count, init: u16(0)})
	}
	for start := 0; start < 65536; start += 63 {
		count := if start + 63 <= 65536 { 63 } else { 65536 - start }
		assert_jsc_string_buffer_equivalence(context, []u16{len: count, init: u16(start + index)})
	}
	assert_jsc_string_buffer_equivalence(context, [u16(0), 0xd83d, 0xde00, 0xd800, 0, 0xdc00, 0xffff])
	assert_jsc_string_buffer_equivalence(context, [u16(0xd83d), 0xde00].repeat(60))
}

fn test_jsc_string_buffer_result_owns_exact_bytes_after_stack_reuse_and_context_release() {
	context := create_javascript_core_context(false)
	mut saved := []string{}
	for source in ['""', '"A\\u0000😀B"', '"λ雪"', '"x".repeat(85)', '"x".repeat(86)'] {
		script := js_source_string(source)
		mut exception := unsafe { nil }
		value := C.vox_jsc_JSEvaluateScript(context, script, unsafe { nil }, unsafe { nil }, 1, &exception)
		C.JSStringRelease(script)
		assert exception == unsafe { nil }
		saved << js_string_to_v(context, value)!
		for _ in 0 .. 32 { _ = js_string_to_v(context, C.vox_jsc_JSValueMakeNumber(context, 123456789))! }
	}
	release_javascript_core_context(context)
	assert saved == ['', 'A\x00😀B', 'λ雪', 'x'.repeat(85), 'x'.repeat(86)]
}

fn test_jsc_string_buffer_uses_the_callers_arena_without_a_temporary_heap_array() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	value := runtime.evaluate_host_value('"short host transport"')!
	mut owner := platform.new_retained_arena('JSC string result owner')
	mut entered := owner.enter()
	before := owner.arena.usage().used
	actual := js_string_to_v(runtime.context, value)!
	after := owner.arena.usage().used
	entered.finish()
	defer { owner.release() }
	assert actual == 'short host transport'
	$if prealloc {
		assert owner.arena.contains(actual.str)
		if !retain_heap_jsc_string_buffer { assert after - before < 64 }
		else { assert after - before >= 64 }
	}
}
