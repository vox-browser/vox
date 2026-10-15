module adblock

import json
import compress.gzip

#flag darwin -framework JavaScriptCore
#include <JavaScriptCore/JavaScriptCore.h>
#include "@DIR/runtime.h"

fn C.JSGlobalContextCreate(voidptr) voidptr
fn C.JSGlobalContextRelease(voidptr)
fn C.JSStringCreateWithCharacters(&u16, usize) voidptr
fn C.JSStringRelease(voidptr)
fn C.JSEvaluateScript(voidptr, voidptr, voidptr, voidptr, int, &voidptr) voidptr
fn C.JSValueToStringCopy(voidptr, voidptr, &voidptr) voidptr
fn C.JSStringGetMaximumUTF8CStringSize(voidptr) usize
fn C.JSStringGetUTF8CString(voidptr, &char, usize) usize
fn C.vox_adblock_lock()
fn C.vox_adblock_unlock()
fn C.vox_adblock_get_context() voidptr
fn C.vox_adblock_get_error() &char
fn C.vox_adblock_set_error(&char)
fn C.vox_adblock_set_context(voidptr)
fn C.vox_adblock_get_enabled() int
fn C.vox_adblock_set_enabled(int)

const compressed_engine_source = $embed_file('engine.js.gz')

fn evaluate_context(context voidptr, source string) !string {
	if context == unsafe { nil } {
		return error('Adblock engine is closed')
	}
	characters := source_utf16(source)
	script := C.JSStringCreateWithCharacters(characters.data, usize(characters.len))
	defer { C.JSStringRelease(script) }
	mut exception := unsafe { nil }
	value := C.JSEvaluateScript(context, script, unsafe { nil }, unsafe { nil }, 1, &exception)
	if exception != unsafe { nil } {
		return error('Adblock JavaScriptCore: ${value_string(context, exception)!}')
	}
	return value_string(context, value)
}

fn value_string(context voidptr, value voidptr) !string {
	mut exception := unsafe { nil }
	js_string := C.JSValueToStringCopy(context, value, &exception)
	if js_string == unsafe { nil } {
		return error('Adblock result cannot be converted to a string')
	}
	defer { C.JSStringRelease(js_string) }
	capacity := C.JSStringGetMaximumUTF8CStringSize(js_string)
	mut bytes := []u8{len: int(capacity)}
	written := unsafe { C.JSStringGetUTF8CString(js_string, &char(bytes.data), capacity) }
	if written == 0 {
		return error('Adblock result UTF-8 conversion failed')
	}
	return bytes[..int(written) - 1].bytestr()
}

fn create_context(custom_filters ?string) !voidptr {
	context := C.JSGlobalContextCreate(unsafe { nil })
	if context == unsafe { nil } {
		return error('Cannot create isolated adblock JavaScriptCore context')
	}
	source := gzip.decompress(compressed_engine_source.to_bytes()) or {
		C.JSGlobalContextRelease(context)
		return error('Cannot decompress bundled adblock engine: ${err}')
	}
	evaluate_context(context, source.bytestr()) or {
		C.JSGlobalContextRelease(context)
		return err
	}
	argument := if raw := custom_filters { json.encode(raw) } else { '' }
	evaluate_context(context, 'voxAdblockInitialize(${argument})') or {
		C.JSGlobalContextRelease(context)
		return err
	}
	return context
}

// evaluate_engine is also used by cosmetic/scriptlet filtering in this module.
// All entry points share the lock because a JSC context must not run concurrently.
pub fn evaluate_engine(source string) !string {
	C.vox_adblock_lock()
	defer { C.vox_adblock_unlock() }
	mut context := C.vox_adblock_get_context()
	if context == unsafe { nil } {
		previous_error := C.vox_adblock_get_error()
        if previous_error != unsafe { nil } {
            return error(unsafe { cstring_to_vstring(previous_error) })
        }
        context = create_context(none) or {
            C.vox_adblock_set_error(err.msg().str)
            return err
        }
		C.vox_adblock_set_context(context)
	}
	return evaluate_context(context, source)
}

fn evaluate_custom_engine(context voidptr, source string) !string {
	C.vox_adblock_lock()
	defer { C.vox_adblock_unlock() }
	return evaluate_context(context, source)
}

pub fn new_engine(filters string) !&Engine {
	C.vox_adblock_lock()
	defer { C.vox_adblock_unlock() }
	return &Engine{context: create_context(filters)!}
}

pub fn (mut engine Engine) close() {
	C.vox_adblock_lock()
	defer { C.vox_adblock_unlock() }
	if engine.context != unsafe { nil } {
		C.JSGlobalContextRelease(engine.context)
		engine.context = unsafe { nil }
	}
}

pub fn is_enabled() bool {
	C.vox_adblock_lock()
	defer { C.vox_adblock_unlock() }
	return C.vox_adblock_get_enabled() != 0
}

pub fn set_enabled(enabled bool) {
	C.vox_adblock_lock()
	defer { C.vox_adblock_unlock() }
	C.vox_adblock_set_enabled(int(enabled))
}

fn source_utf16(source string) []u16 {
	mut result := []u16{cap: source.len}
	for point in source.runes() {
		if point <= 0xffff {
			result << u16(point)
		} else {
			value := u32(point) - 0x10000
			result << u16(0xd800 + (value >> 10))
			result << u16(0xdc00 + (value & 0x3ff))
		}
	}
	return result
}
