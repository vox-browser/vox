module adblock

import json2
import os
$if prealloc {
	import platform
}
import time


$if !vox_v8 ? {
	#flag darwin -framework JavaScriptCore
}
#flag darwin -framework CoreFoundation
#flag darwin -lz
$if linux {
	#pkgconfig javascriptcoregtk-4.1
}
#flag linux -lz
#include "@DIR/../browserjs/jsc_abi.h"
#include "@DIR/runtime.h"

fn C.vox_adblock_utf8_string(&u8, uint) voidptr
fn C.vox_adblock_gunzip(&u8, uint, &u8, uint) int

fn C.JSGlobalContextCreate(voidptr) voidptr
fn C.JSGlobalContextRelease(voidptr)
fn C.JSStringCreateWithCharacters(&u16, uint) voidptr
fn C.JSStringRelease(voidptr)
fn C.vox_jsc_JSEvaluateScript(voidptr, voidptr, voidptr, voidptr, int, &voidptr) voidptr
fn C.vox_jsc_JSValueToStringCopy(voidptr, voidptr, &voidptr) voidptr
fn C.JSStringGetMaximumUTF8CStringSize(voidptr) uint
fn C.JSStringGetUTF8CString(voidptr, &char, uint) uint
fn C.vox_adblock_lock()
fn C.vox_adblock_try_lock() int
fn C.vox_adblock_unlock()
fn C.vox_adblock_get_context() voidptr
fn C.vox_adblock_get_error() &char
fn C.vox_adblock_set_error(&char)
fn C.vox_adblock_set_context(voidptr)
fn C.vox_adblock_get_enabled() int
fn C.vox_adblock_set_enabled(int)

const compressed_engine_source = $embed_file('engine.js.gz')

// Protected by the same lock as the default engine. Cache hits that require
// no VM evaluation do not postpone releasing that VM.
__global default_engine_last_used_ns i64

fn evaluate_context(context voidptr, source string) !string {
	if context == unsafe { nil } {
		return error('Adblock engine is closed')
	}
	script := script_string(source)
	defer { C.JSStringRelease(script) }
	mut exception := unsafe { nil }
	value := C.vox_jsc_JSEvaluateScript(context, script, unsafe { nil }, unsafe { nil }, 1, &exception)
	if exception != unsafe { nil } {
		return error('Adblock JavaScriptCore: ${value_string(context, exception)!}')
	}
	return value_string(context, value)
}

fn value_string(context voidptr, value voidptr) !string {
	mut exception := unsafe { nil }
	js_string := C.vox_jsc_JSValueToStringCopy(context, value, &exception)
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
	$if prealloc {
		// JSC copies script text and the snapshot bridge owns its native buffers.
		// Keep decompression, encoding and initialization-result temporaries out
		// of the request thread's retained base arena.
		if _ := custom_filters { return create_context_in_current_arena(custom_filters) }
		persistent := platform.enter_persistent()
		if snapshot_asset_path('engine.js.gz') == none { _ = compressed_engine_source.data() }
		warm_snapshot_sources()
		platform.leave_persistent(persistent)
		mut scratch := platform.begin_thread_scratch('adblock initialization')
		context := create_context_in_current_arena(custom_filters) or {
			scratch.leave()
			message := err.msg().clone()
			scratch.finish()
			return error(message)
		}
		scratch.finish()
		return context
	}
	return create_context_in_current_arena(custom_filters)
}

fn create_context_in_current_arena(custom_filters ?string) !voidptr {
	context := C.JSGlobalContextCreate(unsafe { nil })
	if context == unsafe { nil } {
		return error('Cannot create isolated adblock JavaScriptCore context')
	}
	install_snapshot(context) or {
		C.JSGlobalContextRelease(context)
		return err
	}
	compressed_source := if path := snapshot_asset_path('engine.js.gz') {
		os.read_bytes(path) or {
			C.JSGlobalContextRelease(context)
			kind := if snapshot_asset_directory() != none { 'diagnostic' } else { 'bundled' }
			return error('Cannot read ${kind} adblock source: ${err}')
		}
	} else { compressed_engine_source.to_bytes() }
	source := decompress_engine_source(compressed_source) or {
		C.JSGlobalContextRelease(context)
		return error('Cannot decompress bundled adblock engine: ${err}')
	}
	evaluate_context(context, source) or {
		C.JSGlobalContextRelease(context)
		return err
	}
	argument := if raw := custom_filters { json2.encode(raw, escape_unicode: true) } else { '' }
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
	defer {
		default_engine_last_used_ns = time.sys_mono_now()
		C.vox_adblock_unlock()
	}
	$if macos {
		if C.vox_adblock_worker_is_configured() != 0 {
			previous_error := C.vox_adblock_get_error()
			if previous_error != unsafe { nil } {
				return error(unsafe { cstring_to_vstring(previous_error) })
			}
			return evaluate_default_worker(source)
		}
	}
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

// Idle static pages keep their filtering results in the document, so the
// isolated default engine need not retain its JavaScriptCore VM between
// requests. A later check restores the complete bundled engine on demand.
// The lock also covers result conversion in evaluate_engine(), so no borrowed
// JavaScript value can outlive the context being released here.
pub fn release_unused_engine() bool {
	C.vox_adblock_lock()
	defer { C.vox_adblock_unlock() }
	return release_default_engine_locked()
}

// A host may poll this on its event loop even while page JavaScript runs.
// A busy filtering request wins immediately; no evaluation is interrupted.
pub fn release_default_engine_if_idle(idle_ms int) bool {
	if C.vox_adblock_try_lock() == 0 { return false }
	defer { C.vox_adblock_unlock() }
	now := time.sys_mono_now()
	if idle_ms < 0 || now < default_engine_last_used_ns
		|| now - default_engine_last_used_ns < i64(idle_ms) * 1_000_000 {
		return false
	}
	return release_default_engine_locked()
}

fn release_default_engine_locked() bool {
	$if macos {
		if C.vox_adblock_worker_is_configured() != 0 {
			return C.vox_adblock_worker_release() != 0
		}
	}
	context := C.vox_adblock_get_context()
	if context == unsafe { nil } {
		return false
	}
	C.vox_adblock_set_context(unsafe { nil })
	C.JSGlobalContextRelease(context)
	return true
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

// CoreFoundation accepts an explicit byte length, preserving embedded NULs. Invalid
// UTF-8 retains the existing V rune decoder behavior instead of being discarded.
fn script_string(source string) voidptr {
 script := C.vox_adblock_utf8_string(source.str, uint(source.len))
 if script != unsafe { nil } { return script }
 characters := source_utf16(source)
 return C.JSStringCreateWithCharacters(characters.data, uint(characters.len))
}

// The bundled asset is one gzip member produced by tools/build_adblock.mjs.
// zlib validates its CRC and exact input/output sizes before we evaluate it.
fn decompress_engine_source(data []u8) !string {
 if data.len < 18 { return error('Truncated gzip source') }
 n := data.len
 size := u32(data[n-4]) | (u32(data[n-3]) << 8) | (u32(data[n-2]) << 16) | (u32(data[n-1]) << 24)
 if size > u32(max_int) { return error('Bundled source exceeds string capacity') }
 mut output := []u8{len: int(size)}
 status := C.vox_adblock_gunzip(data.data, uint(data.len), output.data, uint(output.len))
 if status != 0 { return error('Invalid gzip source (${status})') }
 return output.bytestr()
}
