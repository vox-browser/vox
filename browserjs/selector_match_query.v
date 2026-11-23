module browserjs

import os
import platform

// Same-binary control: copy both arguments into a scratch workspace, as before.
const retain_selector_argument_scratch = os.getenv('VOX_RETAIN_SELECTOR_ARGUMENT_SCRATCH') != ''

pub struct SelectorMatchReply {
pub:
	handled bool
	matched bool
	// __ladybirdSelectorFirstState only: the root is the document or connected,
	// and whether the document's local name history proves the selector has no
	// match below such a root (absent) or cannot (unproven).
	connected_root bool
	absent_by_names bool
	unproven_by_names bool
}

pub type SelectorMatchQuery = fn (key string, selector string) !SelectorMatchReply

// The third argument asks for the local name history's verdict.
pub type SelectorFirstStateQuery = fn (key string, selector string, check_names bool) !SelectorMatchReply

// Keys and selectors are borrowed only for the synchronous callback. An
// unhandled owner asks the facade to use the ordinary DOM query transport.
pub fn (mut runtime Runtime) install_selector_match_query(callback SelectorMatchQuery) ! {
	runtime.install_selector_boolean_query('__ladybirdSelectorMatches', callback)!
}

// A false reply completes querySelector with null. A positive or unhandled
// reply lets the facade obtain the element and synchronize its full state.
pub fn (mut runtime Runtime) install_selector_first_query(callback SelectorMatchQuery) ! {
	runtime.install_selector_boolean_query('__ladybirdSelectorFirst', callback)!
}

// __ladybirdSelectorFirstState(key, selector, checkNames): querySelector's
// first-match answer with facts the facade may reuse, as bits: 1 matched, 2 the
// root is the document or connected (until the tree version changes), 4 the
// local name history proves no match below such a root, 8 it cannot (both
// until the history gains a name). Undefined when the owner did not handle
// the query.
pub fn (mut runtime Runtime) install_selector_first_state_query(callback SelectorFirstStateQuery) ! {
	runtime.require_javascript_value_context()!
	$if darwin || linux || windows {
		owner := &runtime
		runtime.define_value_host_function('__ladybirdSelectorFirstState', fn [owner, callback] (_ voidptr, args []voidptr) !voidptr {
			if args.len != 3 || !C.JSValueIsString(owner.context, args[0])
				|| !C.JSValueIsString(owner.context, args[1]) {
				return C.vox_jsc_JSValueMakeUndefined(owner.context)
			}
			check_names := C.JSValueToBoolean(owner.context, args[2])
			mut key_bytes := [96]u8{}
			mut selector_bytes := [416]u8{}
			key_length := owner.binding_dom_string_into(args[0], &key_bytes[0], 96)
			selector_length := if key_length < 0 { -1 } else {
				owner.binding_dom_string_into(args[1], &selector_bytes[0], 416)
			}
			reply := if selector_length >= 0 {
				callback(unsafe { tos(&key_bytes[0], key_length) }, unsafe { tos(&selector_bytes[0],
					selector_length) }, check_names)!
			} else {
				work := platform.begin_thread_scratch('selector state arguments')
				defer { work.finish() }
				key := owner.binding_dom_string(args[0])!
				selector := owner.binding_dom_string(args[1])!
				work.leave()
				callback(key, selector, check_names)!
			}
			if !reply.handled { return C.vox_jsc_JSValueMakeUndefined(owner.context) }
			bits := (if reply.matched { 1 } else { 0 }) | (if reply.connected_root { 2 } else { 0 })
				| (if reply.absent_by_names { 4 } else { 0 }) | (if reply.unproven_by_names { 8 } else { 0 })
			return C.vox_jsc_JSValueMakeNumber(owner.context, f64(bits))
		})!
		runtime.own_closure(voidptr(callback))
	}
}

fn (mut runtime Runtime) install_selector_boolean_query(name string, callback SelectorMatchQuery) ! {
	runtime.require_javascript_value_context()!
	$if darwin || linux || windows {
		owner := &runtime
		runtime.define_value_host_function(name, fn [owner, callback] (_ voidptr, args []voidptr) !voidptr {
			if args.len != 2 || !C.JSValueIsString(owner.context, args[0])
				|| !C.JSValueIsString(owner.context, args[1]) {
				return C.vox_jsc_JSValueMakeUndefined(owner.context)
			}
			// Short arguments are converted into this frame: the callback only
			// borrows them, and a scratch workspace costs more than the match.
			if !retain_selector_argument_scratch {
				mut key_bytes := [96]u8{}
				mut selector_bytes := [416]u8{}
				key_length := owner.binding_dom_string_into(args[0], &key_bytes[0], 96)
				selector_length := if key_length < 0 { -1 } else {
					owner.binding_dom_string_into(args[1], &selector_bytes[0], 416)
				}
				if selector_length >= 0 {
					reply := callback(unsafe { tos(&key_bytes[0], key_length) }, unsafe { tos(&selector_bytes[0],
						selector_length) })!
					if !reply.handled { return C.vox_jsc_JSValueMakeUndefined(owner.context) }
					return C.vox_jsc_JSValueMakeBoolean(owner.context, reply.matched)
				}
			}
			work := platform.begin_thread_scratch('selector match arguments')
			defer { work.finish() }
			key := owner.binding_dom_string(args[0])!
			selector := owner.binding_dom_string(args[1])!
			// DOM reactions may allocate retained state while reading the owner.
			// Retire only the argument copies with this scratch scope.
			work.leave()
			reply := callback(key, selector)!
			if !reply.handled { return C.vox_jsc_JSValueMakeUndefined(owner.context) }
			return C.vox_jsc_JSValueMakeBoolean(owner.context, reply.matched)
		})!
		runtime.own_closure(voidptr(callback))
	}
}

// binding_dom_string() into a caller's buffer. Returns the length without
// the terminator, or -1 when the conversion fails or may not fit.
fn (runtime &Runtime) binding_dom_string_into(value voidptr, buffer &u8, capacity int) int {
	$if darwin || linux || windows {
		mut exception := unsafe { nil }
		text := C.vox_jsc_JSValueToStringCopy(runtime.context, value, &exception)
		if exception != unsafe { nil } || text == unsafe { nil } { return -1 }
		defer { C.JSStringRelease(text) }
		if int(C.JSStringGetMaximumUTF8CStringSize(text)) > capacity { return -1 }
		length := unsafe { C.JSStringGetUTF8CString(text, &char(buffer), uint(capacity)) }
		if length == 0 { return -1 }
		return int(length) - 1
	}
	return -1
}
