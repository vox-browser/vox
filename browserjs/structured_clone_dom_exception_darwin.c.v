// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
@[has_globals]
module browserjs

import html
import webidl

struct NativeCloneDOMException {
	value ?&webidl.DOMException
	quota ?&webidl.QuotaExceededError
}

fn (runtime &Runtime) native_clone_dom_exception(value voidptr) !NativeCloneDOMException {
	// Source SerializablePlatformObject.interface_name is the primary derived
	// interface. A QuotaExceededError also has a genuine DOMException base,
	// but its extra payload must never be silently serialized as that base.
	if quota := quota_exceeded_error_bindings_[voidptr(runtime)] {
		if native := quota.by_wrapper[value] {
			return NativeCloneDOMException{quota: native}
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
			if runtime.closed { return false }
			// Actual installed platform exposure, independent of author-mutated
			// globals/prototypes. The native factory owns its original prototype.
			if interface_name == .dom_exception {
				if _ := dom_exception_bindings_[owner] { return true }
			} else if interface_name == .quota_exceeded_error {
				if _ := quota_exceeded_error_bindings_[owner] { return true }
			} else if interface_name == .crypto_key {
				if host := crypto_bindings_[owner] {
					if host.closed { return false }
					if _ := host.prototypes[.key] { return true }
				}
			} else if interface_name == .file {
				if host := file_bindings_[owner] {
					return !host.closed && host.constructor != unsafe { nil } && host.prototype != unsafe { nil }
				}
			} else if interface_name == .blob {
				if host := blob_bindings_[owner] {
					return !host.closed && host.constructor != unsafe { nil } && host.prototype != unsafe { nil }
				}
			}
			return false
		}
	}
}
