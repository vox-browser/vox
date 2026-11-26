// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform
import xhr

fn (mut host Host) event_form_data(native &html.FormData) libjs.Value {
	if data := host.form_event_data[voidptr(native)] { return host.wrap_form_data(data, none) }
	data := xhr.FormData.from_html_entries(native.entries())
	mut source := unsafe { &html.FormData(native) }
	source.bind_entry_list(html.FormDataEntryList(data))
	host.form_event_data[voidptr(native)] = data
	return host.wrap_form_data(data, none)
}

fn (mut host Host) install_form_data_events() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.event_prototype)
	host.form_data_event_prototype = prototype
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		if vm.argument_count() < 2 { return vm.throw_error(.type_error, 'FormDataEvent requires type and eventInit') }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		options := vm.argument(1)
		if !options.is_nullish() && !options.is_object() { return vm.throw_error(.type_error, 'FormDataEventInit must be an object') }
		bubbles := text_encoding_member(mut vm, options, 'bubbles')!.to_boolean()
		cancelable := text_encoding_member(mut vm, options, 'cancelable')!.to_boolean()
		composed := text_encoding_member(mut vm, options, 'composed')!.to_boolean()
		data := host.form_data_value(mut vm, text_encoding_member(mut vm, options, 'formData')!)!
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		mut actual := html.FormData.create([]html.FormDataEntry{})
		actual.bind_entry_list(html.FormDataEntryList(data))
		native := html.FormDataEvent.construct_impl(type_, html.FormDataEventInit{form_data: actual, bubbles: bubbles, cancelable: cancelable, composed: composed})!
		mut owner := unsafe { &Host(host) }
		owner.form_event_data[voidptr(actual)] = data
		mut object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else { host.form_data_event_prototype })
		return owner.register_event_wrapper(mut object, unsafe { &dom.Event(native) }).as_object()
	}
	host.closures << voidptr(construct)
	mut global := host.realm.global_object_record()
	event_constructor := global.get(mut vm, libjs.PropertyName.from_str('Event'))!
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, event_constructor.as_object(),
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'FormDataEvent requires new') }, construct, 2, libjs.PropertyName.from_str('FormDataEvent')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('FormDataEvent')), libjs.attribute_configurable)
	global.define_direct_property(libjs.PropertyName.from_str('FormDataEvent'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	host.accessor(mut prototype, 'formData', fn [host] (mut vm libjs.VM) !libjs.Value {
		event := host.event(mut vm)!
		if event.interface_ != .form_data_event { return vm.throw_error(.type_error, 'Expected a FormDataEvent') }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		data := unsafe { &html.FormDataEvent(event) }.form_data() or { return vm.throw_error(.type_error, 'FormDataEvent has no data') }
		mut owner := unsafe { &Host(host) }
		return owner.event_form_data(data)
	}, unsafe { nil })
}
