// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (host &Host) attribute_argument(mut vm libjs.VM, value libjs.Value) !&dom.Attr {
	host.require_open(mut vm)!
	if value.is_object() {
		if node := host.nodes[voidptr(value.as_object())] {
			if attribute := node.as_attr() { return attribute }
		}
	}
	return vm.throw_error(.type_error, 'Expected an Attr')
}

fn (mut host Host) wrap_attribute_record(attribute &dom.Attr_) libjs.Value {
	key := voidptr(attribute)
	if wrapper := host.attribute_nodes[key] { return libjs.Value.from_object(wrapper) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut document := unsafe { &dom.Document(host.document) }
	document.share_native_storage_lifetime(attribute.storage_owner())
	node := dom.Attr.from_attribute_record(attribute)
	value := host.wrap_node(node.as_node())
	host.attribute_nodes[key] = value.as_object()
	return value
}

fn (mut host Host) install_attribute_nodes() {
	mut prototype := host.attribute_prototype
	for name in ['name', 'localName', 'namespaceURI', 'prefix', 'ownerElement', 'specified', 'value'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.attribute_argument(mut vm, vm.this_value())!
			if name == 'specified' { return libjs.Value.from_bool(native.specified()) }
			if name == 'ownerElement' {
				mut owner := unsafe { &Host(host) }
				return if element := native.owner_element() {
					owner.wrap_node(element.as_node())
				} else { libjs.js_null() }
			}
			text := match name {
				'name' { ?string(native.name()) }
				'localName' { ?string(native.local_name()) }
				'namespaceURI' { native.namespace_uri() }
				'prefix' { native.prefix() }
				else { ?string(native.value()) }
			}
			return if value := text {
				libjs.Value.from_string(vm.create_string(libjs.utf16_string_from_utf8_without_validation(value)))
			} else { libjs.js_null() }
		}, if name == 'value' { fn [host] (mut vm libjs.VM) !libjs.Value {
			mut native := host.attribute_argument(mut vm, vm.this_value())!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			text := vm.argument(0).to_primitive_string(mut vm)!.str()
			mut owner := unsafe { &Host(host) }
			native.set_value(text) or { return owner.dom_error(mut vm, err) }
			owner.drain_custom_elements()
			owner.changed()
			return libjs.js_undefined()
		} } else { unsafe { nil } })
	}
	mut document := host.document_prototype
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	for name in ['createAttribute', 'createAttributeNS'] {
		namespaced := name.ends_with('NS')
		arity := if namespaced { 2 } else { 1 }
		host.method_attributes(mut document, name, arity, fn [host, name, namespaced, arity] (mut vm libjs.VM) !libjs.Value {
			node := host.node(mut vm)!
			if !node.is_document() { return vm.throw_error(.type_error, name + ' requires a Document') }
			if vm.argument_count() < u32(arity) { return vm.throw_error(.type_error, name + ' requires a name') }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			namespace_ := if namespaced && !vm.argument(0).is_nullish() {
				?string(vm.argument(0).to_primitive_string(mut vm)!.str())
			} else { none }
			key := vm.argument(u32(arity - 1)).to_primitive_string(mut vm)!.str()
			mut owner := unsafe { &Host(host) }
			attribute := if namespaced {
				node.document().create_attribute_ns(namespace_, key) or { return owner.dom_error(mut vm, err) }
			} else {
				node.document().create_attribute(key) or { return owner.dom_error(mut vm, err) }
			}
			return owner.wrap_node(attribute.as_node())
		}, attributes)
	}
}
