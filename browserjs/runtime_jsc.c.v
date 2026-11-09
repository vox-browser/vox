module browserjs

import processmetrics

import libjs
import platform


// The experimental compile-time `-d vox_v8` backend builds the same bindings
// against the JavaScriptCore C API implemented on V8 (v8/jsc_on_v8.cpp). Its
// headers shadow the framework's; build-prod-browser.sh builds and links the
// library for VOX_V8=1.
$if vox_v8 ? {
	$if !macos {
		$compile_error('-d vox_v8 is only supported on macOS')
	}
	#flag -I@DIR/v8/include
} $else {
	#flag darwin -framework JavaScriptCore
}
#flag darwin -framework CoreFoundation
#flag windows -lJavaScriptCore
#flag windows -L@DIR/../Build/deps/windows/native
#flag windows -I@DIR/include
$if linux {
	#pkgconfig javascriptcoregtk-4.1
}
#include <JavaScriptCore/JavaScript.h>
#include "@DIR/jsc_abi.h"
#include "@DIR/source_string_darwin.h"
#include "@DIR/runtime_agent_context.h"

fn C.JSGlobalContextCreate(global_object_class voidptr) voidptr
fn C.JSGlobalContextRelease(context voidptr)
fn C.JSStringCreateWithUTF8CString(value &char) voidptr
fn C.JSStringCreateWithCharacters(characters &u16, count uint) voidptr
fn C.JSStringRelease(value voidptr)
fn C.vox_jsc_JSEvaluateScript(context voidptr, script voidptr, this_object voidptr, source_url voidptr, starting_line_number int, exception &voidptr) voidptr
fn C.vox_jsc_JSValueToStringCopy(context voidptr, value voidptr, exception &voidptr) voidptr
fn C.JSValueIsObject(context voidptr, value voidptr) bool
fn C.JSValueIsString(context voidptr, value voidptr) bool
fn C.JSValueIsNumber(context voidptr, value voidptr) bool
fn C.vox_jsc_JSObjectGetProperty(context voidptr, object voidptr, property_name voidptr, exception &voidptr) voidptr
fn C.JSStringGetMaximumUTF8CStringSize(value voidptr) uint
fn C.JSStringGetUTF8CString(value voidptr, buffer &char, buffer_size uint) uint
fn C.vox_browserjs_source_utf8_string(bytes &u8, length uint) voidptr
fn C.vox_browserjs_create_agent_context(worker_global i32) voidptr

fn js_string_to_v(context voidptr, value voidptr) !string {
	mut exception := unsafe { nil }
	string_value := C.vox_jsc_JSValueToStringCopy(context, value, &exception)
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
	if !retain_heap_jsc_string_buffer && capacity <= 256 {
		// JSC writes synchronously. Copy the exact result into the caller's
		// allocation owner before this fixed stack buffer leaves its frame.
		mut buffer := [256]u8{}
		written := unsafe { C.JSStringGetUTF8CString(string_value, &char(&buffer[0]), capacity) }
		if written == 0 { return error('JavaScript string conversion failed') }
		note_inline_jsc_string_buffer()
		return unsafe { tos(&buffer[0], int(written) - 1).clone() }
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
	stack := C.vox_jsc_JSObjectGetProperty(context, exception, stack_name, &ignored_exception)
	if ignored_exception != unsafe { nil } || stack == unsafe { nil }
		|| !C.JSValueIsString(context, stack) {
		return message
	}
	trace := js_string_to_v(context, stack) or { return message }
	return if trace == '' { message } else { message + '\n' + trace }
}

fn create_javascript_core_context(worker_global bool) voidptr {
	return C.vox_browserjs_create_agent_context(i32(worker_global))
}

fn create_javascript_core_shared_context() voidptr {
	return C.vox_browserjs_create_agent_context(2)
}

fn release_javascript_core_context(context voidptr) {
	C.JSGlobalContextRelease(context)
}

fn js_source_string(source string) voidptr {
	native := C.vox_browserjs_source_utf8_string(source.str, uint(source.len))
	if native != unsafe { nil } {
		return native
	}
	// Preserve the original decoder for invalid UTF-8 and BOM-prefixed input.
	// Empty input also retains JavaScriptCore's original null-string identity.
	mut characters := libjs.utf16(source)
	defer {
		unsafe { characters.free() }
	}
	return C.JSStringCreateWithCharacters(characters.data, uint(characters.len))
}

fn javascript_core_syntax_position(context voidptr, exception voidptr, property string,
	fallback int) int {
	if exception == unsafe { nil } || !C.JSValueIsObject(context, exception) { return fallback }
	name := js_source_string(property)
	defer { C.JSStringRelease(name) }
	mut ignored := unsafe { nil }
	value := C.vox_jsc_JSObjectGetProperty(context, exception, name, &ignored)
	if ignored != unsafe { nil } || value == unsafe { nil } || !C.JSValueIsNumber(context, value) {
		return fallback
	}
	number := C.vox_jsc_JSValueToNumber(context, value, &ignored)
	return if ignored == unsafe { nil } && number >= 1 && number <= 2147483647 { int(number) } else { fallback }
}

fn evaluate_with_javascript_core(runtime &Runtime, source ScriptSource, stringify_result bool, positioned_syntax_errors bool) !string {
	result := evaluate_javascript_core_text(runtime.context, source, stringify_result, positioned_syntax_errors, false, runtime)!
	return result.value
}

fn evaluate_javascript_core_text(context voidptr, source ScriptSource, stringify_result bool,
	positioned_syntax_errors bool, temporary bool, owner &Runtime) !TemporaryText {
	load_instruction_stage := processmetrics.begin_javascript_instruction_stage()
	defer { load_instruction_stage.finish() }
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
	value := C.vox_jsc_JSEvaluateScript(context, script, unsafe { nil }, source_url, source.starting_line,
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
		return owner.actual_javascript_exception(exception)
	}
	if value == unsafe { nil } || !stringify_result {
		return TemporaryText{}
	}
	mut workspace := platform.ThreadScratchScope{}
	// Evaluation and author object coercion can publish persistent native state.
	// Only a primitive string's conversion bytes enter the temporary workspace.
	if temporary && C.JSValueIsString(context, value) {
		workspace = platform.begin_thread_scratch('temporary evaluated text')
	}
	text := js_string_to_v(context, value) or {
		workspace.leave()
		message := err.msg().clone()
		workspace.finish()
		return owner.actual_javascript_exception(exception)
	}
	workspace.leave()
	return TemporaryText{value: text, workspace: workspace}
}
