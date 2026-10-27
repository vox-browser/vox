// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of UniversalGlobalScope.{h,cpp}.
@[has_globals]
module html

import dom
import encoding.base64

__global html_experimental_interfaces_exposed = false

@[heap]
pub struct UniversalGlobalScopeMixin {
pub:
	event_target &dom.EventTarget
	realm        &ScriptingRealm
mut:
	import_map_                             ImportMap
	outstanding_rejected_promises_weak_set_ []&dom.Promise
	about_to_be_notified_rejected_promises_ []&dom.Promise
	queuing_strategy_size_functions_ &GlobalQueuingStrategySizeFunctions = unsafe { nil }
}

pub struct QueuingStrategyChunk {
pub:
	byte_length f64
}

pub type QueuingStrategySizeFunction = fn (QueuingStrategyChunk) f64

pub fn UniversalGlobalScopeMixin.create(event_target &dom.EventTarget, realm &ScriptingRealm) &UniversalGlobalScopeMixin {
	return &UniversalGlobalScopeMixin{
		event_target: event_target
		realm:        realm
	}
}

pub fn (scope &UniversalGlobalScopeMixin) btoa(data string) !string {
	mut bytes := []u8{cap: data.len}
	for code_point in data.runes() {
		if code_point > 0xff {
			return error('InvalidCharacterError: Data contains characters outside U+0000 to U+00FF')
		}
		bytes << u8(code_point)
	}
	return base64.encode(bytes)
}

pub fn (scope &UniversalGlobalScopeMixin) atob(data string) !string {
	mut stripped := []u8{cap: data.len}
	for character in data.bytes() {
		if character !in [` `, `\t`, `\n`, `\x0c`, `\r`] {
			stripped << character
		}
	}
	// Forgiving-base64 removes at most two trailing padding characters, and
	// only from an input whose original length is divisible by four.
	if stripped.len % 4 == 0 && stripped.len > 0 && stripped.last() == `=` {
		stripped.delete_last()
		if stripped.len > 0 && stripped.last() == `=` {
			stripped.delete_last()
		}
	}
	if stripped.len % 4 == 1 {
		return error('InvalidCharacterError: Input is not valid base64 data')
	}
	for character in stripped {
		if !((character >= `A` && character <= `Z`)
			|| (character >= `a` && character <= `z`)
			|| (character >= `0` && character <= `9`) || character in [`+`, `/`]) {
			return error('InvalidCharacterError: Input is not valid base64 data')
		}
	}
	decoded := base64.decode(stripped.bytestr())
	mut output := []rune{cap: decoded.len}
	for byte in decoded {
		output << rune(byte)
	}
	return output.string()
}

// Source Window globals use their current associated Document; worker and
// other globals have no document. Tasks capture this association when queued.
fn (scope &UniversalGlobalScopeMixin) task_document() ?&dom.Document {
	if scope.event_target.data.kind != .window {
		return none
	}
	window := unsafe { &dom.Window(scope.event_target) }
	return window.associated_document()
}

pub fn (scope &UniversalGlobalScopeMixin) queue_microtask(callback fn ()) {
	queue_a_microtask(scope.task_document(), callback)
}

pub fn (scope &UniversalGlobalScopeMixin) structured_clone(value dom.JSValue, options StructuredSerializeOptions) !dom.JSValue {
	serialized := structured_serialize_with_transfer(value, options.transfer)!
	deserialized := structured_deserialize_with_transfer(serialized)!
	return deserialized.deserialized
}

pub fn (scope &UniversalGlobalScopeMixin) count_queuing_strategy_size() f64 {
	return 1.0
}

pub fn (scope &UniversalGlobalScopeMixin) byte_length_queuing_strategy_size(byte_length uint) f64 {
	return f64(byte_length)
}

pub fn (_ &UniversalGlobalScopeMixin) count_queuing_strategy_size_function() QueuingStrategySizeFunction {
	return fn (_ QueuingStrategyChunk) f64 {
		return 1.0
	}
}

pub fn (_ &UniversalGlobalScopeMixin) byte_length_queuing_strategy_size_function() QueuingStrategySizeFunction {
	return fn (chunk QueuingStrategyChunk) f64 {
		return chunk.byte_length
	}
}

pub fn (mut scope UniversalGlobalScopeMixin) push_onto_outstanding_rejected_promises_weak_set(promise &dom.Promise) {
	for existing in scope.outstanding_rejected_promises_weak_set_ {
		if existing == promise {
			return
		}
	}
	scope.outstanding_rejected_promises_weak_set_ << promise
}

pub fn (mut scope UniversalGlobalScopeMixin) remove_from_outstanding_rejected_promises_weak_set(promise &dom.Promise) bool {
	for index, existing in scope.outstanding_rejected_promises_weak_set_ {
		if existing == promise {
			scope.outstanding_rejected_promises_weak_set_.delete(index)
			return true
		}
	}
	return false
}

pub fn (mut scope UniversalGlobalScopeMixin) push_onto_about_to_be_notified_rejected_promises_list(promise &dom.Promise) {
	scope.about_to_be_notified_rejected_promises_ << promise
}

pub fn (mut scope UniversalGlobalScopeMixin) remove_from_about_to_be_notified_rejected_promises_list(promise &dom.Promise) bool {
	for index, existing in scope.about_to_be_notified_rejected_promises_ {
		if existing == promise {
			scope.about_to_be_notified_rejected_promises_.delete(index)
			return true
		}
	}
	return false
}

pub fn (mut scope UniversalGlobalScopeMixin) notify_about_rejected_promises() {
	list := scope.about_to_be_notified_rejected_promises_.clone()
	if list.len == 0 {
		return
	}
	scope.about_to_be_notified_rejected_promises_.clear()
	scope_pointer := voidptr(&scope)
	responsible_event_loop := if settings := settings_object_of_realm(scope.realm) {
		settings.responsible_event_loop()
	} else {
		main_thread_event_loop()
	}
	queue_a_task(.dom_manipulation, responsible_event_loop, scope.task_document(), fn [scope_pointer, list] () {
		mut scope := unsafe { &UniversalGlobalScopeMixin(scope_pointer) }
		for promise in list {
			if promise.is_handled() {
				continue
			}
			event := dom.PromiseRejectionEvent.create('unhandledrejection', dom.PromiseRejectionEventInit{
				EventInit: dom.EventInit{
					cancelable: true
				}
				promise:   dom.js_object(voidptr(promise))
				reason:    promise.result()
			})
			not_handled := scope.event_target.dispatch_event(unsafe { &dom.Event(event) })
			if !promise.is_handled() {
				scope.push_onto_outstanding_rejected_promises_weak_set(promise)
			}
			if not_handled {
				mut realm := unsafe { &ScriptingRealm(scope.realm) }
				report_exception_to_console(promise.result(), mut realm, .yes)
			}
		}
	})
}

pub fn (scope &UniversalGlobalScopeMixin) import_map() &ImportMap {
	return &scope.import_map_
}

pub fn (mut scope UniversalGlobalScopeMixin) set_import_map(import_map &ImportMap) {
	scope.import_map_ = ImportMap{
		imports:   import_map.imports
		scopes:    import_map.scopes.clone()
		integrity: import_map.integrity.clone()
	}
}

pub fn set_experimental_interfaces_exposed(exposed bool) {
	UniversalGlobalScopeMixin.set_experimental_interfaces_exposed(exposed)
}

pub fn expose_experimental_interfaces() bool {
	return UniversalGlobalScopeMixin.expose_experimental_interfaces()
}

pub fn UniversalGlobalScopeMixin.set_experimental_interfaces_exposed(exposed bool) {
	html_experimental_interfaces_exposed = exposed
}

pub fn UniversalGlobalScopeMixin.expose_experimental_interfaces() bool {
	return html_experimental_interfaces_exposed
}
