// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

@[heap]
struct AttributeMapView {
	host   &Host
	native &dom.NamedNodeMap
}

fn (view &AttributeMapView) is_supported_property_index(index u32) bool {
	return !view.host.closed && u64(index) < u64(view.native.length())
}

fn (view &AttributeMapView) get_own_property(key libjs.PropertyName) ?libjs.PropertyDescriptor {
	if view.host.closed || !key.is_number() { return none }
	attribute := view.native.item(int(key.number)) or { return none }
	mut host := unsafe { &Host(view.host) }
	return libjs.PropertyDescriptor{
		value: host.wrap_attribute_record(attribute)
		writable: false
		enumerable: true
		configurable: true
	}
}

fn (view &AttributeMapView) own_property_keys() []libjs.PropertyName {
	if view.host.closed { return [] }
	return []libjs.PropertyName{len: view.native.length(), init: libjs.PropertyName.from_number(u32(index))}
}

fn (view &AttributeMapView) is_supported_property_name(name libjs.Utf16String) bool {
	return !view.host.closed && view.native.is_supported_property_name(name.str())
}

fn (view &AttributeMapView) named_property_value(name libjs.Utf16String) libjs.Value {
	if view.host.closed { return libjs.js_undefined() }
	attribute := view.native.named_item_value(name.str()) or { return libjs.js_undefined() }
	mut host := unsafe { &Host(view.host) }
	return host.wrap_attribute_record(attribute)
}

fn (view &AttributeMapView) supported_property_names() []libjs.Utf16String {
	if view.host.closed { return [] }
	return view.native.supported_property_names().map(libjs.utf16_string_from_utf8_without_validation(it))
}

fn (host &Host) attribute_map_receiver(mut vm libjs.VM) !&dom.NamedNodeMap {
	host.require_open(mut vm)!
	receiver := vm.this_value()
	if receiver.is_object() {
		if view := receiver.as_object().host_properties {
			if view is AttributeMapView {
				if voidptr(view.host) == voidptr(host) { return view.native }
			}
		}
	}
	return vm.throw_error(.type_error, 'NamedNodeMap member called on incompatible receiver')
}

fn (mut host Host) wrap_attribute_map(native &dom.NamedNodeMap, prototype &libjs.Object) libjs.Value {
	key := voidptr(native)
	if object := host.attribute_maps[key] { return libjs.Value.from_object(object) }
	mut object := libjs.Object.create(host.realm, prototype)
	object.class_name = 'NamedNodeMap'
	view := &AttributeMapView{host: &host, native: native}
	object.host_properties = libjs.HostProperties(view)
	object.legacy_platform_object = &libjs.LegacyPlatformObject{
		indexed_properties: libjs.LegacyIndexedProperties(view)
		named_properties: libjs.LegacyNamedProperties(view)
		legacy_unenumerable_named_properties: true
	}
	host.attribute_maps[key] = object
	return libjs.Value.from_object(object)
}

fn (mut host Host) wrap_nullable_attribute(attribute ?&dom.Attr_) libjs.Value {
	return if native := attribute { host.wrap_attribute_record(native) } else { libjs.js_null() }
}

fn (mut host Host) install_attribute_maps() {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal NamedNodeMap constructor') },
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object {
			return vm.throw_error(.type_error, 'Illegal NamedNodeMap constructor')
		}, 0, libjs.PropertyName.from_str('NamedNodeMap')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor),
		libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		libjs.Value.from_string(vm.create_string_from_str('NamedNodeMap')), libjs.attribute_configurable)
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator()),
		host.realm.array_prototype_values, libjs.attribute_writable | libjs.attribute_configurable)
	host.accessor(mut prototype, 'length', fn [host] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_f64(f64(host.attribute_map_receiver(mut vm)!.length()))
	}, unsafe { nil })
	host.method_attributes(mut prototype, 'item', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.attribute_map_receiver(mut vm)!
		if vm.argument_count() < 1 { return vm.throw_error(.type_error, 'NamedNodeMap.item requires an index') }
		index := vm.argument(0).to_u32(mut vm)!
		mut owner := unsafe { &Host(host) }
		return owner.wrap_nullable_attribute(native.item(int(index)))
	}, attributes)
	for name in ['getNamedItem', 'getNamedItemNS', 'removeNamedItem', 'removeNamedItemNS'] {
		namespaced := name.ends_with('NS')
		arity := if namespaced { 2 } else { 1 }
		host.method_attributes(mut prototype, name, arity, fn [host, name, namespaced, arity] (mut vm libjs.VM) !libjs.Value {
			mut native := host.attribute_map_receiver(mut vm)!
			if vm.argument_count() < u32(arity) {
				return vm.throw_error(.type_error, 'NamedNodeMap.' + name + ' requires a name')
			}
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			namespace_ := if namespaced && !vm.argument(0).is_nullish() {
				?string(vm.argument(0).to_primitive_string(mut vm)!.str())
			} else { none }
			key := vm.argument(u32(arity - 1)).to_primitive_string(mut vm)!.str()
			mut owner := unsafe { &Host(host) }
			match name {
				'getNamedItem' { return owner.wrap_nullable_attribute(native.get_named_item(key)) }
				'getNamedItemNS' { return owner.wrap_nullable_attribute(native.get_named_item_ns(namespace_, key)) }
				else {}
			}
			removed := if namespaced {
				native.remove_named_item_ns(namespace_, key) or { return owner.dom_error(mut vm, err) }
			} else {
				native.remove_named_item(key) or { return owner.dom_error(mut vm, err) }
			}
			owner.drain_custom_elements()
			owner.changed()
			return owner.wrap_attribute_record(removed)
		}, attributes)
	}
	for name in ['setNamedItem', 'setNamedItemNS'] {
		host.method_attributes(mut prototype, name, 1, fn [host] (mut vm libjs.VM) !libjs.Value {
			mut native := host.attribute_map_receiver(mut vm)!
			value := vm.argument(0)
			mut attribute := host.attribute_argument(mut vm, value)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			record := attribute.ensure_attribute_record()
			result := native.set_attribute_with_result(record) or { return owner.dom_error(mut vm, err) }
			owner.attribute_nodes[voidptr(record)] = value.as_object()
			owner.drain_custom_elements()
			owner.changed()
			return owner.wrap_nullable_attribute(result.previous)
		}, attributes)
	}
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('NamedNodeMap'), libjs.Value.from_object(constructor),
		libjs.attribute_writable | libjs.attribute_configurable)
	mut element := host.element_prototype
	host.accessor(mut element, 'attributes', fn [host, prototype] (mut vm libjs.VM) !libjs.Value {
		mut native := unsafe { &dom.Element(host.element(mut vm)!) }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		return owner.wrap_attribute_map(native.attributes(), prototype)
	}, unsafe { nil })
}
