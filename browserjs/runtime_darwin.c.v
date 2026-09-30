module browserjs

import libjs

#flag darwin -framework JavaScriptCore
#include <JavaScriptCore/JavaScriptCore.h>

fn C.JSGlobalContextCreate(global_object_class voidptr) voidptr
fn C.JSGlobalContextRelease(context voidptr)
fn C.JSStringCreateWithUTF8CString(value &char) voidptr
fn C.JSStringCreateWithCharacters(characters &u16, count usize) voidptr
fn C.JSStringRelease(value voidptr)
fn C.JSEvaluateScript(context voidptr, script voidptr, this_object voidptr, source_url voidptr, starting_line_number int, exception &voidptr) voidptr
fn C.JSValueToStringCopy(context voidptr, value voidptr, exception &voidptr) voidptr
fn C.JSValueIsObject(context voidptr, value voidptr) bool
fn C.JSValueIsString(context voidptr, value voidptr) bool
fn C.JSObjectGetProperty(context voidptr, object voidptr, property_name voidptr, exception &voidptr) voidptr
fn C.JSStringGetMaximumUTF8CStringSize(value voidptr) usize
fn C.JSStringGetUTF8CString(value voidptr, buffer &char, buffer_size usize) usize

fn js_string_to_v(context voidptr, value voidptr) !string {
	mut exception := unsafe { nil }
	string_value := C.JSValueToStringCopy(context, value, &exception)
	if string_value == unsafe { nil } {
		return error('JavaScript value could not be converted to a string')
	}
	defer {
		C.JSStringRelease(string_value)
	}
	capacity := C.JSStringGetMaximumUTF8CStringSize(string_value)
	if capacity == 0 {
		return ''
	}
	mut bytes := []u8{len: int(capacity)}
	written := unsafe { C.JSStringGetUTF8CString(string_value, &char(bytes.data), capacity) }
	if written == 0 {
		return error('JavaScript string conversion failed')
	}
	return bytes[..int(written) - 1].bytestr()
}

fn js_exception_message(context voidptr, exception voidptr) string {
	message := js_string_to_v(context, exception) or { 'unknown JavaScript exception' }
	if !C.JSValueIsObject(context, exception) {
		return message
	}
	stack_name := C.JSStringCreateWithUTF8CString(c'stack')
	if stack_name == unsafe { nil } {
		return message
	}
	defer { C.JSStringRelease(stack_name) }
	mut ignored_exception := unsafe { nil }
	stack := C.JSObjectGetProperty(context, exception, stack_name, &ignored_exception)
	if ignored_exception != unsafe { nil } || stack == unsafe { nil }
		|| !C.JSValueIsString(context, stack) {
		return message
	}
	trace := js_string_to_v(context, stack) or { return message }
	return if trace == '' { message } else { message + '\n' + trace }
}

fn create_javascript_core_context() voidptr {
	return C.JSGlobalContextCreate(unsafe { nil })
}

fn release_javascript_core_context(context voidptr) {
	C.JSGlobalContextRelease(context)
}

fn js_source_string(source string) voidptr {
	mut characters := libjs.utf16(source)
	defer {
		unsafe { characters.free() }
	}
	return C.JSStringCreateWithCharacters(characters.data, usize(characters.len))
}

fn evaluate_with_javascript_core(context voidptr, source ScriptSource, stringify_result bool) !string {
	// Both engines must consume the entire same UTF-16 input, including NULs.
	script := js_source_string(source.code)
	if script == unsafe { nil } {
		return error('JavaScriptCore source-string creation failed')
	}
	defer {
		C.JSStringRelease(script)
	}
	source_url := js_source_string(source.url)
	if source_url == unsafe { nil } {
		return error('JavaScriptCore source-URL creation failed')
	}
	defer {
		C.JSStringRelease(source_url)
	}
	mut exception := unsafe { nil }
	value := C.JSEvaluateScript(context, script, unsafe { nil }, source_url, source.starting_line,
		&exception)
	if exception != unsafe { nil } {
		return error(js_exception_message(context, exception))
	}
	if value == unsafe { nil } || !stringify_result {
		return ''
	}
	return js_string_to_v(context, value)
}
