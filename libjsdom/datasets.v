// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform

@[heap]
struct DatasetProperties {
	host   &Host
	native &html.DOMStringMap
}

fn (properties &DatasetProperties) is_supported_property_name(name libjs.Utf16String) bool {
	if properties.host.closed { return false }
	return properties.native.supported_property_names().any(it == name.str())
}

fn (properties &DatasetProperties) named_property_value(name libjs.Utf16String) libjs.Value {
	if properties.host.closed { return libjs.js_undefined() }
	return libjs.Value.from_string(properties.host.vm.create_string_from_str(properties.native.determine_value_of_named_property(name.str())))
}

fn (properties &DatasetProperties) supported_property_names() []libjs.Utf16String {
	if properties.host.closed { return [] }
	return properties.native.supported_property_names().map(libjs.utf16_string(it))
}

fn (properties &DatasetProperties) set_named_property(mut vm libjs.VM, name libjs.Utf16String, value libjs.Value) ! {
	properties.host.require_open(mut vm)!
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	// WebIDL converts the value before the native setter validates the name.
	text := value.to_primitive_string(mut vm)!.str()
	mut native := unsafe { &html.DOMStringMap(properties.native) }
	mut host := unsafe { &Host(properties.host) }
	native.set_value_of_named_property(name.str(), text) or { return host.dom_error(mut vm, err) }
	host.drain_custom_elements()
	host.changed()
}

fn (properties &DatasetProperties) delete_named_property(mut vm libjs.VM, name libjs.Utf16String) !bool {
	properties.host.require_open(mut vm)!
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut native := unsafe { &html.DOMStringMap(properties.native) }
	native.delete_value(name.str())
	mut host := unsafe { &Host(properties.host) }
	host.drain_custom_elements()
	host.changed()
	return true
}

fn (mut host Host) wrap_dataset(element &dom.Element) libjs.Value {
	if object := host.dataset_wrappers[element.as_node().unique_id()] {
		return libjs.Value.from_object(object)
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, host.dataset_prototype)
	object.class_name = 'DOMStringMap'
	properties := &DatasetProperties{ host: &host, native: html.DOMStringMap.create(element) }
	object.legacy_platform_object = libjs.LegacyPlatformObject{
		named_properties:         libjs.LegacyNamedProperties(properties)
		named_setter:             libjs.LegacyNamedPropertySetter(properties)
		named_deleter:            libjs.LegacyNamedPropertyDeleter(properties)
		legacy_override_builtins: true
	}
	host.dataset_wrappers[element.as_node().unique_id()] = object
	return libjs.Value.from_object(object)
}

fn (mut host Host) install_datasets() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.dataset_prototype = prototype
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value {
			return vm.throw_error(.type_error, 'Illegal DOMStringMap constructor')
		},
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object {
			return vm.throw_error(.type_error, 'Illegal DOMStringMap constructor')
		}, 0, libjs.PropertyName.from_str('DOMStringMap')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('DOMStringMap')), libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('DOMStringMap'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut element := host.html_element_prototype
	host.accessor(mut element, 'dataset', fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.element(mut vm)!
		if !native.is_html_element() {
			return vm.throw_error(.type_error, 'dataset requires HTMLElement')
		}
		mut owner := unsafe { &Host(host) }
		return owner.wrap_dataset(native)
	}, unsafe { nil })
}
