// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform
import webidl

fn (host &Host) signal_value(mut vm libjs.VM, value libjs.Value) !&dom.AbortSignal {
	host.require_open(mut vm)!
	if value.is_object() { if signal := host.abort_signals[voidptr(value.as_object())] { return signal } }
	return vm.throw_error(.type_error, 'Expected an AbortSignal')
}

fn (host &Host) controller_receiver(mut vm libjs.VM) !&dom.AbortController {
	host.require_open(mut vm)!
	if vm.this_value().is_object() { if controller := host.abort_controllers[voidptr(vm.this_value().as_object())] { return controller } }
	return vm.throw_error(.type_error, 'AbortController member called on incompatible receiver')
}

fn (mut host Host) wrap_abort_signal(native &dom.AbortSignal) libjs.Value {
	if object := host.abort_signal_wrappers[voidptr(native)] { return libjs.Value.from_object(object) }
	object := libjs.Object.create(host.realm, host.abort_signal_prototype)
	host.abort_signals[voidptr(object)] = native
	host.abort_signal_wrappers[voidptr(native)] = object
	host.event_targets[voidptr(object)] = unsafe { &dom.EventTarget(native) }
	host.event_target_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

// Retain the actual engine value through the native WebIDL boundary. In
// particular, symbols, BigInts and object reasons are never stringified here.
fn (mut host Host) native_abort_reason(value libjs.Value) dom.JSValue {
	if value.is_undefined() { return dom.js_undefined() }
	boxed := &libjs.Value{...value}
	stringify := fn [host, boxed] () !string {
		mut owner := unsafe { &Host(host) }
		return owner.native_value_string(*boxed)
	}
	host.closures << voidptr(stringify)
	return dom.js_webidl_value(webidl.runtime_value(webidl.RuntimeValue{
		context: voidptr(&host), value: voidptr(boxed), string_conversion: stringify
	}))
}

fn (mut host Host) abort_reason_value(mut vm libjs.VM, value webidl.Value) !libjs.Value {
	if actual := value.runtime_value_ {
		if actual.context != voidptr(&host) || actual.value == unsafe { nil } { return vm.throw_error(.type_error, 'Abort reason belongs to another runtime') }
		return unsafe { *(&libjs.Value(actual.value)) }
	}
	if native := value.dom_exception_ { return host.wrap_dom_exception(native, host.dom_exception_prototype) }
	return match value.kind {
		.undefined { libjs.js_undefined() }
		.null_ { libjs.js_null() }
		.boolean { libjs.Value.from_bool(value.boolean_value) }
		.number { libjs.Value.from_f64(value.number_value) }
		.string_ { libjs.Value.from_string(vm.create_string(libjs.utf16_string_from_utf8_without_validation(value.string_value))) }
		else { return vm.throw_error(.type_error, 'Abort reason requires its actual engine value') }
	}
}

fn (mut host Host) install_abort_signals() ! {
	mut vm := host.vm
	mut controller_prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	mut signal_prototype := libjs.Object.create(host.realm, host.event_target_prototype)
	host.abort_controller_prototype, host.abort_signal_prototype = controller_prototype, signal_prototype
	for name, prototype in {'AbortController': controller_prototype, 'AbortSignal': signal_prototype} {
		mut object := prototype
		object.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str(name)), libjs.attribute_configurable)
	}
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else { host.abort_controller_prototype })
		mut owner := unsafe { &Host(host) }
		owner.abort_controllers[voidptr(object)] = dom.AbortController.construct_impl()!
		return object
	}
	host.closures << voidptr(construct)
	mut controller := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'AbortController requires new') }, construct, 0, libjs.PropertyName.from_str('AbortController')).object
	mut signal := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.event_target_constructor,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal AbortSignal constructor') },
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal AbortSignal constructor') }, 0, libjs.PropertyName.from_str('AbortSignal')).object
	for name, constructor in {'AbortController': controller, 'AbortSignal': signal} {
		mut function := constructor
		mut prototype := if name == 'AbortController' { controller_prototype } else { signal_prototype }
		function.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
		prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
		mut global := host.realm.global_object_record()
		global.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	}
	host.accessor(mut controller_prototype, 'signal', fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.controller_receiver(mut vm)!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		return owner.wrap_abort_signal(native.signal())
	}, unsafe { nil })
	host.method_attributes(mut controller_prototype, 'abort', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut controller := unsafe { &dom.AbortController(host.controller_receiver(mut vm)!) }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		owner.frame_window(mut vm)!
		settings := unsafe { &html.EnvironmentSettingsObject(host.document.relevant_settings_object()) }
		clock := fn [settings] () f64 { return settings.global_relative_event_timestamp() }
		defer { platform.release_closure(voidptr(clock)) }
		controller.abort_with_clock(owner.native_abort_reason(vm.argument(0)), clock)
		return libjs.js_undefined()
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	for name in ['aborted', 'reason'] {
		host.accessor(mut signal_prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.signal_value(mut vm, vm.this_value())!
			if name == 'aborted' { return libjs.Value.from_bool(native.aborted()) }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			return owner.abort_reason_value(mut vm, native.reason().as_webidl_value()!)
		}, unsafe { nil })
	}
	host.method_attributes(mut signal_prototype, 'throwIfAborted', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.signal_value(mut vm, vm.this_value())!
		native.throw_if_aborted() or {
			mut owner := unsafe { &Host(host) }
			if err is webidl.ValueException { return libjs.throw_completion(owner.abort_reason_value(mut vm, err.value)!) }
			return owner.dom_error(mut vm, err)
		}
		return libjs.js_undefined()
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	host.install_target_event_handler(mut signal_prototype, 'onabort', 'abort', fn [host] (mut vm libjs.VM) !&dom.EventTarget {
		return unsafe { &dom.EventTarget(host.signal_value(mut vm, vm.this_value())!) }
	})
	host.method_attributes(mut signal, 'abort', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		return owner.wrap_abort_signal(dom.AbortSignal.abort(owner.native_abort_reason(vm.argument(0)))!)
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	host.method_attributes(mut signal, 'timeout', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'AbortSignal.timeout requires milliseconds') }
		number := vm.argument(0).to_number(mut vm)!.number
		milliseconds := webidl.convert_to_int(webidl.number_value(number), 64, false, .yes, .no) or { return vm.throw_error(.type_error, err.msg()) }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		owner.frame_window(mut vm)!
		settings := unsafe { &html.EnvironmentSettingsObject(host.document.relevant_settings_object()) }
		return owner.wrap_abort_signal(html.abort_signal_timeout(settings, u64(milliseconds))!)
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	host.method_attributes(mut signal, 'any', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'AbortSignal.any requires signals') }
		mut iterator := libjs.get_iterator_sync_value(mut vm, vm.argument(0))!
		mut signals := []&dom.AbortSignal{}
		for {
			vm.consume_execution_budget()!
			step := libjs.iterator_step_value(mut vm, mut iterator)!
			if step.done { break }
			native := host.signal_value(mut vm, step.value) or { return libjs.iterator_close(mut vm, iterator, libjs.completion_from_error(err)).release_error() }
			signals << native
		}
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		return owner.wrap_abort_signal(dom.AbortSignal.any(signals)!)
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
}
