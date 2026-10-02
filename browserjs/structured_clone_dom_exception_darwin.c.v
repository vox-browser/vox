// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
@[has_globals]
module browserjs

import html
import webidl

struct NativeCloneDOMException {
	value ?&webidl.DOMException
}

fn (runtime &Runtime) native_clone_dom_exception(value voidptr) !NativeCloneDOMException {
	// Source SerializablePlatformObject.interface_name is the primary derived
	// interface. A QuotaExceededError also has a genuine DOMException base,
	// but its extra payload must never be silently serialized as that base.
	if quota := quota_exceeded_error_bindings_[voidptr(runtime)] {
		if _ := quota.by_wrapper[value] {
			return native_clone_unsupported('Source native QuotaExceededError payload is not yet bound')
		}
	}
	binding := dom_exception_bindings_[voidptr(runtime)] or { return NativeCloneDOMException{} }
	native := binding.by_wrapper[value] or { return NativeCloneDOMException{} }
	return NativeCloneDOMException{value: native}
}

fn (runtime &Runtime) native_clone_deserialization_context() html.StructuredDeserializationContext {
	owner := voidptr(runtime)
	return html.StructuredDeserializationContext{
		is_exposed: fn [owner] (interface_name html.StructuredSerializableInterface) bool {
			runtime := unsafe { &Runtime(owner) }
			if runtime.closed || interface_name != .dom_exception { return false }
			// Actual installed platform exposure, independent of author-mutated
			// globals/prototypes. The native factory owns its original prototype.
			if _ := dom_exception_bindings_[owner] { return true }
			return false
		}
	}
}
