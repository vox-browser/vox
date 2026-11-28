// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (mut host Host) install_submit_events() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.event_prototype)
	host.submit_event_prototype = prototype
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'SubmitEvent requires a type') }
		persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		options := vm.argument(1)
		if !options.is_nullish() && !options.is_object() { return vm.throw_error(.type_error, 'SubmitEventInit must be an object') }
		bubbles := text_encoding_member(mut vm, options, 'bubbles')!.to_boolean()
		cancelable := text_encoding_member(mut vm, options, 'cancelable')!.to_boolean()
		composed := text_encoding_member(mut vm, options, 'composed')!.to_boolean()
		button := text_encoding_member(mut vm, options, 'submitter')!
		submitter := if button.is_nullish() { ?&dom.HTMLElement(none) } else { ?&dom.HTMLElement(unsafe { &dom.HTMLElement(host.form_data_element(mut vm, button, false)!) }) }
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		mut native := dom.SubmitEvent.construct_impl(type_, dom.SubmitEventInit{bubbles: bubbles, cancelable: cancelable, composed: composed, submitter: submitter})!
		native.set_is_trusted(false)
		mut owner := unsafe { &Host(host) }
		mut object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else { host.submit_event_prototype })
		return owner.register_event_wrapper(mut object, unsafe { &dom.Event(native) }).as_object()
	}
	host.closures << voidptr(construct)
	mut global := host.realm.global_object_record()
	event_constructor := global.get(mut vm, libjs.PropertyName.from_str('Event'))!
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, event_constructor.as_object(),
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'SubmitEvent requires new') }, construct, 1, libjs.PropertyName.from_str('SubmitEvent')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('SubmitEvent')), libjs.attribute_configurable)
	global.define_direct_property(libjs.PropertyName.from_str('SubmitEvent'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	host.accessor(mut prototype, 'submitter', fn [host] (mut vm libjs.VM) !libjs.Value {
		event := host.event(mut vm)!
		if event.interface_ != .submit_event { return vm.throw_error(.type_error, 'Expected a SubmitEvent') }
		mut owner := unsafe { &Host(host) }
		return if button := unsafe { &dom.SubmitEvent(event) }.submitter() { owner.wrap_node(button.as_node()) } else { libjs.js_null() }
	}, unsafe { nil })
}
