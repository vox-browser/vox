// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import css
import dom
import libjs
import platform

@[heap]
struct NodeListCollection {
	host &Host
	native &dom.NodeList
}

fn (list &NodeListCollection) get_own_property(key libjs.PropertyName) ?libjs.PropertyDescriptor {
	if list.host.closed || !key.is_number() { return none }
	if native := list.native.item(int(key.number)) {
		mut host := unsafe { &Host(list.host) }
		return libjs.PropertyDescriptor{value: host.wrap_node(native), writable: false, enumerable: true, configurable: false}
	}
	return none
}

fn (list &NodeListCollection) own_property_keys() []libjs.PropertyName {
	if list.host.closed { return [] }
	return []libjs.PropertyName{len: list.native.length(), init: libjs.PropertyName.from_number(u32(index))}
}

fn (host &Host) node_list_receiver(mut vm libjs.VM) !&dom.NodeList {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if provider := vm.this_value().as_object().host_properties {
			if provider is NodeListCollection {
				if voidptr(provider.host) == voidptr(host) { return provider.native }
			}
		}
	}
	return vm.throw_error(.type_error, 'NodeList member called on incompatible receiver')
}

fn (mut host Host) wrap_node_list(native &dom.NodeList) libjs.Value {
	if object := host.node_list_wrappers[voidptr(native)] { return libjs.Value.from_object(object) }
	mut object := libjs.Object.create(host.realm, host.node_list_prototype)
	object.class_name = 'NodeList'
	object.host_properties = libjs.HostProperties(&NodeListCollection{host: &host, native: native})
	host.node_list_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

fn (mut host Host) install_node_lists() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.node_list_prototype = prototype
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('NodeList')), libjs.attribute_configurable)
	host.accessor(mut prototype, 'length', fn [host] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_f64(f64(host.node_list_receiver(mut vm)!.length()))
	}, unsafe { nil })
	host.method_attributes(mut prototype, 'item', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		list := host.node_list_receiver(mut vm)!
		if vm.argument_count() < 1 { return vm.throw_error(.type_error, 'NodeList.item requires an index') }
		index := vm.argument(0).to_u32(mut vm)!
		mut owner := unsafe { &Host(host) }
		return if native := list.item(int(index)) { owner.wrap_node(native) } else { libjs.js_null() }
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	// WebIDL value-iterable methods use the realm's generic Array intrinsics.
	for name in ['entries', 'keys', 'values', 'forEach'] {
		method := host.realm.array_prototype_record().get(mut vm, libjs.PropertyName.from_str(name))!
		prototype.define_direct_property(libjs.PropertyName.from_str(name), method, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator()), host.realm.array_prototype_values, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal NodeList constructor') },
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal NodeList constructor') }, 0, libjs.PropertyName.from_str('NodeList')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('NodeList'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut node := host.node_prototype
	host.accessor(mut node, 'childNodes', fn [host] (mut vm libjs.VM) !libjs.Value {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut native := unsafe { &dom.Node(host.node(mut vm)!) }
		mut owner := unsafe { &Host(host) }
		return owner.wrap_node_list(native.child_nodes())
	}, unsafe { nil })
	mut prototypes := [host.document_prototype, host.element_prototype, host.fragment_prototype]
	for mut target in prototypes {
		host.method_attributes(mut target, 'querySelectorAll', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
			node := host.node(mut vm)!
			if !node.is_element() && !node.is_document() && !node.is_document_fragment() { return vm.throw_error(.type_error, 'querySelectorAll requires a ParentNode') }
			if vm.argument_count() < 1 { return vm.throw_error(.type_error, 'querySelectorAll requires a selector') }
			selector := vm.argument(0).to_primitive_string(mut vm)!.str()
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			css.install_document_selector_query_hook(node.document())
			parent := unsafe { &dom.ParentNode(node) }
			mut owner := unsafe { &Host(host) }
			list := parent.query_selector_all(selector) or { return owner.dom_error(mut vm, err) }
			return owner.wrap_node_list(list)
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
}
