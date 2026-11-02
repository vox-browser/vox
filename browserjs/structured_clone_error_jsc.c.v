// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html


fn source_native_error_type(name string) html.StructuredErrorType {
	return match name {
		'EvalError' { .eval_error }
		'InternalError' { .internal_error }
		'RangeError' { .range_error }
		'ReferenceError' { .reference_error }
		'SyntaxError' { .syntax_error }
		'TypeError' { .type_error }
		'URIError' { .uri_error }
		else { .error }
	}
}

fn (mut projection NativeCloneProjection) project_error(value voidptr, mut object html.StructuredObject) ! {
	bridge := projection.bridge
	// Source Get(name), own message descriptor/ToString, then own cause
	// descriptor/ToString. Metadata retains actual engine values.
	metadata := projection.root(bridge.engine('error_metadata', [value])!)!
	name := bridge.engine('list_item', [metadata, C.vox_jsc_JSValueMakeNumber(bridge.runtime.context, 0)])!
	if C.JSValueIsString(bridge.runtime.context, name) {
		object.error_type = source_native_error_type(bridge.runtime.native_utf16_string(name)!.str())
	}
	message := bridge.engine('list_item', [metadata, C.vox_jsc_JSValueMakeNumber(bridge.runtime.context, 1)])!
	if !C.JSValueIsUndefined(bridge.runtime.context, message) {
		object.has_message = true
		object.string_utf16_ = bridge.runtime.native_utf16_string(message)!
	}
	cause := bridge.engine('list_item', [metadata, C.vox_jsc_JSValueMakeNumber(bridge.runtime.context, 2)])!
	if !C.JSValueIsUndefined(bridge.runtime.context, cause) {
		object.has_cause = true
		object.cause_utf16_ = bridge.runtime.native_utf16_string(cause)!
	}
}

fn (mut projection NativeCloneProjection) reconstruct_error(object &html.StructuredObject) !voidptr {
	bridge := projection.bridge
	mut owner := unsafe { &Runtime(bridge.runtime) }
	mut message := C.vox_jsc_JSValueMakeUndefined(owner.context)
	mut cause := C.vox_jsc_JSValueMakeUndefined(owner.context)
	if object.has_message {
		text := object.string_utf16_ or { return native_clone_unsupported('Missing source Error message string') }
		message = projection.adopt_root(owner.javascript_utf16_string(text)!)
	}
	if object.has_cause {
		text := object.cause_utf16_ or { return native_clone_unsupported('Missing source Error cause string') }
		cause = projection.adopt_root(owner.javascript_utf16_string(text)!)
	}
	actual := bridge.engine('create_error', [C.vox_jsc_JSValueMakeNumber(owner.context, f64(u8(object.error_type))), message, cause])!
	if C.JSValueIsUndefined(owner.context, actual) {
		// JSC has no native InternalError; do not fabricate another named Error.
		return native_clone_unsupported('Source InternalError constructor is unavailable in this native engine')
	}
	return actual
}
