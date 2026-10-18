module browserjs

import libjs


#flag darwin -framework JavaScriptCore
#flag darwin -framework CoreFoundation
$if linux {
	#pkgconfig javascriptcoregtk-4.1
}
#include <JavaScriptCore/JavaScript.h>
#include "@DIR/source_string_darwin.h"
#include "@DIR/runtime_agent_context.h"

fn C.JSGlobalContextCreate(global_object_class voidptr) voidptr
fn C.JSGlobalContextRelease(context voidptr)
fn C.JSStringCreateWithUTF8CString(value &char) voidptr
fn C.JSStringCreateWithCharacters(characters &u16, count usize) voidptr
fn C.JSStringRelease(value voidptr)
fn C.JSEvaluateScript(context voidptr, script voidptr, this_object voidptr, source_url voidptr, starting_line_number int, exception &voidptr) voidptr
fn C.JSValueToStringCopy(context voidptr, value voidptr, exception &voidptr) voidptr
fn C.JSValueIsObject(context voidptr, value voidptr) bool
fn C.JSValueIsString(context voidptr, value voidptr) bool
fn C.JSValueIsNumber(context voidptr, value voidptr) bool
fn C.JSObjectGetProperty(context voidptr, object voidptr, property_name voidptr, exception &voidptr) voidptr
fn C.JSStringGetMaximumUTF8CStringSize(value voidptr) usize
fn C.JSStringGetUTF8CString(value voidptr, buffer &char, buffer_size usize) usize
fn C.vox_browserjs_source_utf8_string(bytes &u8, length usize) voidptr
fn C.vox_browserjs_create_agent_context() voidptr

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
	return C.vox_browserjs_create_agent_context()
}

fn release_javascript_core_context(context voidptr) {
	C.JSGlobalContextRelease(context)
}

fn js_source_string(source string) voidptr {
	native := C.vox_browserjs_source_utf8_string(source.str, usize(source.len))
	if native != unsafe { nil } {
		return native
	}
	// Preserve the original decoder for invalid UTF-8 and BOM-prefixed input.
	// Empty input also retains JavaScriptCore's original null-string identity.
	mut characters := libjs.utf16(source)
	defer {
		unsafe { characters.free() }
	}
	return C.JSStringCreateWithCharacters(characters.data, usize(characters.len))
}

fn javascript_core_syntax_position(context voidptr, exception voidptr, property string,
	fallback int) int {
	if exception == unsafe { nil } || !C.JSValueIsObject(context, exception) { return fallback }
	name := js_source_string(property)
	defer { C.JSStringRelease(name) }
	mut ignored := unsafe { nil }
	value := C.JSObjectGetProperty(context, exception, name, &ignored)
	if ignored != unsafe { nil } || value == unsafe { nil } || !C.JSValueIsNumber(context, value) {
		return fallback
	}
	number := C.JSValueToNumber(context, value, &ignored)
	return if ignored == unsafe { nil } && number >= 1 && number <= 2147483647 { int(number) } else { fallback }
}

fn evaluate_with_javascript_core(context voidptr, source ScriptSource, stringify_result bool, positioned_syntax_errors bool) !string {
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
		message := js_exception_message(context, exception)
		// Evaluation validates the entire program before running any statement.
		// Format its own SyntaxError here, inside the embedding Script context,
		// instead of parsing once more solely to obtain positioned diagnostics.
		if positioned_syntax_errors && message.starts_with('SyntaxError:') {
			filename := if source.url == '' { '<script>' } else { source.url }
			line := javascript_core_syntax_position(context, exception, 'line', source.starting_line)
			column := javascript_core_syntax_position(context, exception, 'column', 1)
			return error('SyntaxError: ${filename}:${line}:${column}: ${message.trim_string_left('SyntaxError: ')}')
		}
		return error(message)
	}
	if value == unsafe { nil } || !stringify_result {
		return ''
	}
	return js_string_to_v(context, value)
}
