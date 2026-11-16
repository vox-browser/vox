// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (host &Host) custom_event_receiver(mut vm libjs.VM) !&dom.CustomEvent {
	event := host.event(mut vm)!
	if event.interface_ != .custom_event { return vm.throw_error(.type_error, 'Expected CustomEvent') }
	return unsafe { &dom.CustomEvent(event) }
}

fn (mut host Host) install_custom_events() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.event_prototype)
	host.custom_event_prototype = prototype
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		if vm.argument_count() < 1 { return vm.throw_error(.type_error, 'CustomEvent requires a type') }
		persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		options := vm.argument(1)
		if !options.is_nullish() && !options.is_object() { return vm.throw_error(.type_error, 'CustomEventInit must be a dictionary') }
		bubbles := text_encoding_member(mut vm, options, 'bubbles')!.to_boolean()
		cancelable := text_encoding_member(mut vm, options, 'cancelable')!.to_boolean()
		composed := text_encoding_member(mut vm, options, 'composed')!.to_boolean()
		detail := text_encoding_member(mut vm, options, 'detail')!
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		mut owner := unsafe { &Host(host) }
		native := dom.CustomEvent.create(type_, dom.CustomEventInit{
			EventInit: dom.EventInit{bubbles:bubbles,cancelable:cancelable,composed:composed}
			detail: owner.native_abort_reason(if detail.is_undefined() { libjs.js_null() } else { detail })
		})
		mut object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else { host.custom_event_prototype })
		return owner.register_event_wrapper(mut object, unsafe { &dom.Event(native) }).as_object()
	}
	host.closures << voidptr(construct)
	mut global := host.realm.global_object_record()
	event_constructor := global.get(mut vm, libjs.PropertyName.from_str('Event'))!
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, event_constructor.as_object(),
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'CustomEvent requires new') }, construct, 1, libjs.PropertyName.from_str('CustomEvent')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('CustomEvent')), libjs.attribute_configurable)
	global.define_direct_property(libjs.PropertyName.from_str('CustomEvent'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	host.accessor(mut prototype, 'detail', fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.custom_event_receiver(mut vm)!
		mut owner := unsafe { &Host(host) }
		return owner.abort_reason_value(mut vm, native.detail().as_webidl_value()!)
	}, unsafe { nil })
	host.method_attributes(mut prototype, 'initCustomEvent', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut native := host.custom_event_receiver(mut vm)!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'initCustomEvent requires a type') }
		persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		bubbles, cancelable := vm.argument(1).to_boolean(), vm.argument(2).to_boolean()
		mut owner := unsafe { &Host(host) }
		detail := if vm.argument(3).is_undefined() { libjs.js_null() } else { vm.argument(3) }
		native.init_custom_event(type_, bubbles, cancelable, owner.native_abort_reason(detail))
		return libjs.js_undefined()
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
}
