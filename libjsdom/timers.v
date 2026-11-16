// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform
import trustedtypes
import webidl

@[heap]
struct TimerBinding {
mut:
	id i32
	callback libjs.Value
	callback_closure voidptr
	conversions []voidptr
}

fn (mut host Host) release_retired_timers() {
	if host.timer_callback_depth != 0 { return }
	for callback in host.retired_timer_closures { platform.release_closure(callback) }
	host.retired_timer_closures = []
}

fn (mut host Host) release_timer(mut record TimerBinding) {
	record.callback = libjs.js_undefined()
	for callback in record.conversions { platform.release_closure(callback) }
	record.conversions = []
	if record.callback_closure != unsafe { nil } {
		if host.timer_callback_depth > 0 { host.retired_timer_closures << record.callback_closure }
		else { platform.release_closure(record.callback_closure) }
		record.callback_closure = unsafe { nil }
	}
}

fn (mut host Host) remove_timer(id i32) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if mut record := host.timers[id] {
		host.timers.delete(id)
		host.release_timer(mut record)
	}
}

fn (mut host Host) timer_argument(mut record TimerBinding, value libjs.Value) dom.JSValue {
	boxed := &libjs.Value{...value}
	stringify := fn [host, boxed] () !string {
		mut owner := unsafe { &Host(host) }
		return owner.native_value_string(*boxed)
	}
	record.conversions << voidptr(stringify)
	return dom.js_webidl_value(webidl.runtime_value(webidl.RuntimeValue{context: voidptr(&host), value: voidptr(boxed), is_undefined: value.is_undefined(), number_primitive: if value.is_number() { ?f64(value.number) } else { none }, string_conversion: stringify}))
}

// The native scope owns clocks, tasks, nesting, clamping, cancellation, CSP and
// ClassicScript base URLs. The adapter only supplies VM entry and value roots.
fn (mut host Host) timer_scope(mut vm libjs.VM) !&html.WindowOrWorkerGlobalScopeMixin {
	if scope := host.timer_scope_ { return scope }
	window := host.frame_window(mut vm)!
	mut scope := window.window_or_worker_global_scope()
	host.timer_scope_ = scope
	removed := fn [host] (id i32) {
		mut owner := unsafe { &Host(host) }
		owner.remove_timer(id)
	}
	host.closures << voidptr(removed)
	scope.set_timer_removed_handler(removed)
	evaluate := fn [host] (source string, realm &html.ScriptingRealm) !dom.JSValue {
		mut owner := unsafe { &Host(host) }
		return owner.evaluate_timer_source(source, realm)
	}
	host.closures << voidptr(evaluate)
	scope.set_timer_classic_script_evaluator(evaluate)
	convert_error := fn [host] (err IError) webidl.Value {
		mut owner := unsafe { &Host(host) }
		return owner.timer_exception_value(err)
	}
	host.closures << voidptr(convert_error)
	scope.set_timer_compilation_exception_value_converter(convert_error)
	return scope
}
fn (mut host Host) evaluate_timer_source(source string, realm &html.ScriptingRealm) !dom.JSValue {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if host.closed { return dom.js_undefined() }
	classic := realm.active_classic_script_ or { return error('Timer source requires its native ClassicScript') }
	address := (classic.base_url() or { return error('Timer source requires its native base URL') }).serialize()
	host.callback_entry(fn [host, source, address] (mut vm libjs.VM) !libjs.Value {
		mut script := libjs.Script.parse(source, host.realm, address, unsafe { nil }) or { return libjs.throw_completion(host.fetch_error_value(mut vm, err)) }
		return vm.run_with_limits(mut script, host.hooks.execution_limits)
	}) or {
		if report := host.hooks.exception { report(exception_message_with_stack(err)) }
		return webidl.throw_value(host.native_abort_reason(host.fetch_error_value(mut host.vm, err)).as_webidl_value()!)
	}
	return dom.js_undefined()
}

fn (mut host Host) timer_exception_value(err IError) webidl.Value {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return host.native_abort_reason(host.fetch_error_value(mut host.vm, err)).as_webidl_value() or { webidl.exception_value(err) }
}

fn (mut host Host) fire_timer(record &TimerBinding, arguments []webidl.Value) !webidl.Value {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	host.release_retired_timers()
	host.timer_callback_depth++
	defer { host.timer_callback_depth-- }
	if host.closed { return webidl.undefined_value() }
	callback := record.callback
	mut values := []libjs.Value{cap: arguments.len}
	for argument in arguments { values << host.abort_reason_value(mut host.vm, argument)! }
	receiver := libjs.Value.from_object(host.realm.global_object_record())
	host.callback_entry(fn [callback, receiver, values] (mut vm libjs.VM) !libjs.Value {
		return libjs.call(mut vm, callback, receiver, values)
	}) or {
		if report := host.hooks.exception { report(exception_message_with_stack(err)) }
		return webidl.throw_value(host.native_abort_reason(host.fetch_error_value(mut host.vm, err)).as_webidl_value()!)
	}
	// Timer callback return values are ignored; in particular no thenable adoption.
	return webidl.undefined_value()
}

fn (mut host Host) install_timers() {
	mut global := host.realm.global_object_record()
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	for name in ['setTimeout', 'setInterval'] {
		host.method_attributes(mut global, name, 1, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.window_receiver(mut vm)!
			if vm.argument_count() == 0 { return vm.throw_error(.type_error, name + ' requires a handler') }
			callback := vm.argument(0)
			mut source := if callback.is_function() { ?string(none) } else { ?string(callback.to_primitive_string(mut vm)!.str()) }
			delay := vm.argument(1).to_i32(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			owner.release_retired_timers()
			mut scope := owner.timer_scope(mut vm)!
			if code := source {
				mut factory := unsafe { &trustedtypes.TrustedTypePolicyFactory(scope.trusted_types()) }
				sink := if name == 'setInterval' { trustedtypes.InjectionSink.window_set_interval } else { trustedtypes.InjectionSink.window_set_timeout }
				source = trustedtypes.get_trusted_type_compliant_string(mut factory, .trusted_script, code, sink, "'script'", true) or { return owner.dom_error(mut vm, err) }
			}
			mut record := &TimerBinding{callback: if callback.is_function() { callback } else { libjs.js_undefined() }}
			mut installed := false
			defer { if !installed { owner.release_timer(mut record) } }
			mut arguments := []dom.JSValue{}
			for index := u32(2); index < vm.argument_count(); index++ { arguments << owner.timer_argument(mut record, vm.argument(index)) }
			mut handler := html.TimerHandler{}
			if code := source { handler = html.timer_source_handler(code) }
			else {
				call := fn [host, record] (_ webidl.Value, arguments []webidl.Value) !webidl.Value {
					mut owner := unsafe { &Host(host) }
					return owner.fire_timer(record, arguments)
				}
				record.callback_closure = voidptr(call)
				handler = html.timer_webidl_callback_handler(webidl.CallbackType{callback: call}, webidl.undefined_value())
			}
			record.id = if name == 'setInterval' { scope.set_interval(handler, delay, arguments) } else { scope.set_timeout(handler, delay, arguments) }
			if record.id != 0 { owner.timers[record.id] = record; installed = true }
			return libjs.Value.from_f64(f64(record.id))
		}, attributes)
	}
	for name in ['clearTimeout', 'clearInterval'] {
		host.method_attributes(mut global, name, 0, fn [host] (mut vm libjs.VM) !libjs.Value {
			host.window_receiver(mut vm)!
			id := vm.argument(0).to_i32(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			owner.release_retired_timers()
			mut scope := owner.timer_scope(mut vm)!
			scope.clear_timeout(id)
			return libjs.js_undefined()
		}, attributes)
	}
}

fn (mut host Host) close_timers() {
	if mut scope := host.timer_scope_ {
		for id in host.timers.keys() { scope.clear_timeout(id) }
		scope.set_timer_removed_handler(none)
		scope.set_timer_classic_script_evaluator(none)
		scope.set_timer_compilation_exception_value_converter(none)
	}
	host.release_retired_timers()
	host.timer_scope_ = none
}
