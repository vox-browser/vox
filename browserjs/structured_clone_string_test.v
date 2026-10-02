module browserjs

import dom
import html
import libjs

fn test_actual_engine_clone_string_projection_preserves_utf16_and_source_ipc_payload() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	actual := runtime.evaluate_host_value(r'String.fromCharCode(65,0xd800,0,0xdc00,0xd83d,0xdc1e)')!
	text := runtime.native_utf16_string(actual)!
	assert text.code_units() == [u16(65), 0xd800, 0, 0xdc00, 0xd83d, 0xdc1e]
	record := html.structured_serialize(dom.js_utf16_string(text))!
	assert record.data == [u8(5), 0, 6, 0, 0, 0, 65, 0, 0, 216, 0, 0, 0, 220, 61, 216, 30, 220]
	cloned := html.structured_deserialize_ipc(record)!
	reconstructed := runtime.javascript_utf16_string(cloned.string_utf16_?)!
	runtime.define_value_host_function('__actualUtf16Clone', fn [reconstructed] (_ voidptr, _ []voidptr) !voidptr { return reconstructed })!
	assert runtime.evaluate_host(r'__actualUtf16Clone()===String.fromCharCode(65,0xd800,0,0xdc00,0xd83d,0xdc1e)')! == 'true'
	assert runtime.native_utf16_string(reconstructed)!.code_units() == text.code_units()
}

fn test_actual_engine_clone_string_projection_compresses_ascii_and_guards_primitive_conversion() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	actual := runtime.evaluate_host_value(r'"A".repeat(32)')!
	assert runtime.native_utf16_string(actual)!.has_ascii_storage()
	empty := runtime.javascript_utf16_string(libjs.utf16_string_from_code_units([]))!
	assert runtime.native_utf16_string(empty)!.code_units().len == 0
	object := runtime.evaluate_host_value(r'globalThis.__stringProjectionCalls=0;({toString(){++__stringProjectionCalls;throw new Error("must not convert")}})')!
	if _ := runtime.native_utf16_string(object) { assert false } else { assert err.msg().contains('string primitive') }
	assert runtime.evaluate_host('__stringProjectionCalls')! == '0'
	runtime.close()
	if _ := runtime.native_utf16_string(actual) { assert false } else { assert err.msg().contains('closed') }
	if _ := runtime.javascript_utf16_string(libjs.utf16_string_from_code_units([u16(65)])) { assert false } else { assert err.msg().contains('closed') }
}
