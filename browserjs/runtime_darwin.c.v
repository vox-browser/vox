module browserjs

#flag darwin -framework JavaScriptCore
#include <JavaScriptCore/JavaScriptCore.h>

fn C.JSGlobalContextCreate(global_object_class voidptr) voidptr
fn C.JSGlobalContextRelease(context voidptr)
fn C.JSStringCreateWithUTF8CString(value &char) voidptr
fn C.JSStringRelease(value voidptr)
fn C.JSEvaluateScript(context voidptr, script voidptr, this_object voidptr, source_url voidptr, starting_line_number int, exception &voidptr) voidptr
fn C.JSValueToStringCopy(context voidptr, value voidptr, exception &voidptr) voidptr
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

fn create_javascript_core_context() voidptr {
	return C.JSGlobalContextCreate(unsafe { nil })
}

fn release_javascript_core_context(context voidptr) {
	C.JSGlobalContextRelease(context)
}

fn evaluate_with_javascript_core(context voidptr, source string) !string {
	script := C.JSStringCreateWithUTF8CString(source.str)
	if script == unsafe { nil } {
		return error('JavaScriptCore source-string creation failed')
	}
	defer {
		C.JSStringRelease(script)
	}
	mut exception := unsafe { nil }
	value := C.JSEvaluateScript(context, script, unsafe { nil }, unsafe { nil }, 1, &exception)
	if exception != unsafe { nil } {
		message := js_string_to_v(context, exception) or { 'unknown JavaScript exception' }
		return error(message)
	}
	if value == unsafe { nil } {
		return ''
	}
	return js_string_to_v(context, value)
}
