// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs
import platform
import requestidlecallback
import time

@[heap]
struct IdleCallbackBinding {
	window &html.WindowModel
mut:
	handle u32
	callback libjs.Value
	native html.WindowIdleCallbackHandler = unsafe { nil }
}

@[heap]
struct IdleDeadlineBinding {
	native requestidlecallback.IdleDeadline
	end_time f64
}

fn (mut host Host) release_retired_idle_callbacks() {
	for callback in host.retired_idle_closures { platform.release_closure(callback) }
	host.retired_idle_closures = []
}

fn (host &Host) idle_deadline_receiver(mut vm libjs.VM) !&IdleDeadlineBinding {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if deadline := host.idle_deadlines[voidptr(vm.this_value().as_object())] { return deadline }
	}
	return vm.throw_error(.type_error, 'IdleDeadline member called on incompatible receiver')
}

fn (mut host Host) fire_idle_callback(mut record IdleCallbackBinding, deadline requestidlecallback.IdleDeadline) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	host.release_retired_idle_callbacks()
	host.idle_callbacks.delete(record.handle)
	callback := record.callback
	record.callback = libjs.js_undefined()
	defer { host.retired_idle_closures << voidptr(record.native) }
	if host.closed || host.document.has_been_destroyed() { return }
	// An IdleDeadline retains this period's end, even when author code keeps
	// the object until another idle period. Timed-out callbacks have no budget.
	end_time := if deadline.did_timeout() { f64(time.sys_mono_now()) / 1_000_000.0 } else { html.main_thread_event_loop().compute_deadline() }
	mut object := libjs.Object.create(host.realm, host.idle_deadline_prototype)
	object.class_name = 'IdleDeadline'
	host.idle_deadlines[voidptr(object)] = &IdleDeadlineBinding{native: deadline, end_time: end_time}
	value := libjs.Value.from_object(object)
	host.callback_entry(fn [callback, value] (mut vm libjs.VM) !libjs.Value {
		return libjs.call(mut vm, callback, libjs.js_undefined(), [value])
	}) or { if report := host.hooks.exception { report(exception_message(err)) } }
}

fn (mut host Host) install_idle_callbacks() {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.idle_deadline_prototype = prototype
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('IdleDeadline')), libjs.attribute_configurable)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal IdleDeadline constructor') },
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal IdleDeadline constructor') },
		0, libjs.PropertyName.from_str('IdleDeadline')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	host.accessor(mut prototype, 'didTimeout', fn [host] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_bool(host.idle_deadline_receiver(mut vm)!.native.did_timeout())
	}, unsafe { nil })
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	host.method_attributes(mut prototype, 'timeRemaining', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		deadline := host.idle_deadline_receiver(mut vm)!
		if deadline.native.did_timeout() { return libjs.Value.from_f64(0) }
		return libjs.Value.from_f64(deadline.native.time_remaining_at(f64(time.sys_mono_now()) / 1_000_000.0, deadline.end_time))
	}, attributes)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('IdleDeadline'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	host.method_attributes(mut global, 'requestIdleCallback', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.window_receiver(mut vm)!
		if vm.argument_count() == 0 || !vm.argument(0).is_function() { return vm.throw_error(.type_error, 'IdleRequestCallback must be callable') }
		options := vm.argument(1)
		mut timeout := ?u32(none)
		if !options.is_nullish() {
			if !options.is_object() { return vm.throw_error(.type_error, 'IdleRequestOptions must be an object') }
			value := options.as_object().get(mut vm, libjs.PropertyName.from_str('timeout'))!
			if !value.is_undefined() { timeout = value.to_u32(mut vm)! }
		}
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		owner.release_retired_idle_callbacks()
		mut window := owner.frame_window(mut vm)!
		mut record := &IdleCallbackBinding{window: window, callback: vm.argument(0)}
		record.native = fn [host, record] (deadline requestidlecallback.IdleDeadline) ! {
			mut owner := unsafe { &Host(host) }
			mut binding := unsafe { &IdleCallbackBinding(record) }
			owner.fire_idle_callback(mut binding, deadline)
		}
		record.handle = window.request_idle_callback(record.native, requestidlecallback.IdleRequestOptions{timeout: timeout})
		owner.idle_callbacks[record.handle] = record
		return libjs.Value.from_f64(f64(record.handle))
	}, attributes)
	host.method_attributes(mut global, 'cancelIdleCallback', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.window_receiver(mut vm)!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'cancelIdleCallback requires 1 argument') }
		handle := vm.argument(0).to_u32(mut vm)!
		mut owner := unsafe { &Host(host) }
		owner.release_retired_idle_callbacks()
		mut window := owner.frame_window(mut vm)!
		window.cancel_idle_callback(handle)
		if mut record := owner.idle_callbacks[handle] {
			owner.idle_callbacks.delete(handle)
			record.callback = libjs.js_undefined()
			platform.release_closure(voidptr(record.native))
		}
		return libjs.js_undefined()
	}, attributes)
}

fn (mut host Host) close_idle_callbacks() {
	for handle, mut record in host.idle_callbacks {
		mut window := unsafe { &html.WindowModel(record.window) }
		window.cancel_idle_callback(handle)
		record.callback = libjs.js_undefined()
		platform.release_closure(voidptr(record.native))
	}
	host.idle_callbacks.clear()
	host.idle_deadlines.clear()
	host.idle_deadline_prototype = unsafe { nil }
	host.release_retired_idle_callbacks()
}
