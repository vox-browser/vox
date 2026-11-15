// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform

fn (mut host Host) wrap_radio_node_list(native &html.RadioNodeList) libjs.Value {
	value := host.wrap_node_list_with_prototype(native.node_list(), host.radio_node_list_prototype, 'RadioNodeList')
	host.radio_node_lists[voidptr(value.as_object())] = native
	return value
}

fn (mut host Host) wrap_form_controls_collection(native &html.HTMLFormControlsCollection) libjs.Value {
	value := host.wrap_collection_with_prototype(native.html_collection(), host.form_controls_collection_prototype, 'HTMLFormControlsCollection')
	host.form_controls_collections[voidptr(value.as_object())] = native
	return value
}

fn (host &Host) form_controls_collection_receiver(mut vm libjs.VM) !&html.HTMLFormControlsCollection {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if native := host.form_controls_collections[voidptr(vm.this_value().as_object())] { return native }
	}
	return vm.throw_error(.type_error, 'Expected an HTMLFormControlsCollection')
}

fn (host &Host) radio_node_list_receiver(mut vm libjs.VM) !&html.RadioNodeList {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if native := host.radio_node_lists[voidptr(vm.this_value().as_object())] { return native }
	}
	return vm.throw_error(.type_error, 'Expected a RadioNodeList')
}

fn (mut host Host) wrap_form_named_item(item html.HTMLFormControlsNamedItem) libjs.Value {
	return match item {
		html.HTMLFormControlsCollectionEmpty { libjs.js_null() }
		html.HTMLFormControlsCollectionElement { host.wrap_node(item.element.as_node()) }
		html.HTMLFormControlsCollectionRadioNodeList { host.wrap_radio_node_list(item.list) }
	}
}

fn (mut host Host) install_form_collections() ! {
	mut vm := host.vm
	mut global := host.realm.global_object_record()
	mut constructors := map[string]&libjs.Object{}
	// Native HTMLCollection already backs children/getElementsBy* results.
	// Publish its interface and iterator before exposing the specialized view.
	for name in ['HTMLCollection', 'HTMLFormControlsCollection', 'RadioNodeList'] {
		mut prototype := if name == 'HTMLCollection' { host.collection_prototype } else { libjs.Object.create(host.realm, if name == 'RadioNodeList' { host.node_list_prototype } else { host.collection_prototype }) }
		if name == 'HTMLFormControlsCollection' { host.form_controls_collection_prototype = prototype }
		if name == 'RadioNodeList' { host.radio_node_list_prototype = prototype }
		mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
			fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal collection constructor') },
			fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal collection constructor') }, 0, libjs.PropertyName.from_str(name)).object
		if name == 'HTMLFormControlsCollection' {
			parent := constructors['HTMLCollection'] or { return error('Missing collection constructor') }
			if !constructor.internal_set_prototype_of(parent) { return error('Unable to set collection constructor ancestry') }
		} else if name == 'RadioNodeList' {
			parent := global.get(mut vm, libjs.PropertyName.from_str('NodeList'))!
			if !constructor.internal_set_prototype_of(parent.as_object()) { return error('Unable to set radio list constructor ancestry') }
		}
		constructors[name] = constructor
		constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
		prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
		prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str(name)), libjs.attribute_configurable)
		global.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	}
	mut collection := host.collection_prototype
	collection.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator()), host.realm.array_prototype_values, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	mut controls := host.form_controls_collection_prototype
	host.method_attributes(mut controls, 'namedItem', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.form_controls_collection_receiver(mut vm)!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'namedItem requires a name') }
		name := vm.argument(0).to_primitive_string(mut vm)!.str()
		persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		return owner.wrap_form_named_item(native.named_item_or_radio_node_list(name))
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	mut radio := host.radio_node_list_prototype
	host.accessor(mut radio, 'value', fn [host] (mut vm libjs.VM) !libjs.Value {
		persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
		return libjs.Value.from_string(vm.create_string_from_str(host.radio_node_list_receiver(mut vm)!.value()))
	}, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut native := unsafe { &html.RadioNodeList(host.radio_node_list_receiver(mut vm)!) }
		value := vm.argument(0).to_primitive_string(mut vm)!.str()
		persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
		native.set_value(value)
		mut owner := unsafe { &Host(host) }; owner.finish_form_mutation()
		return libjs.js_undefined()
	})
	mut form := host.html_element_prototypes['HTMLFormElement'] or { return error('Missing form prototype') }
	for name in ['elements', 'length'] {
		host.accessor(mut form, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			element := host.form_control_receiver(mut vm, 'form')!
			persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
			mut native := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(element) })
			if name == 'length' { return libjs.Value.from_f64(f64(native.length())) }
			mut owner := unsafe { &Host(host) }; return owner.wrap_form_controls_collection(native.elements())
		}, unsafe { nil })
	}
}
