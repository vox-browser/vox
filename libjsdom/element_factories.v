// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (host &Host) element_creation_options(mut vm libjs.VM, value libjs.Value) !dom.ElementCreationOptions {
	mut options := dom.ElementCreationOptions{}
	if value.is_nullish() { return options }
	if !value.is_object() {
		// The legacy DOMString union member is converted, then ignored by the
		// native flattening steps. It is not an `is` shorthand.
		value.to_primitive_string(mut vm)!
		return options
	}
	object := value.as_object()
	registry := object.get(mut vm, libjs.PropertyName.from_str('customElementRegistry'))!
	if !registry.is_undefined() {
		if registry.is_null() { options.custom_element_registry = ?voidptr(unsafe { nil }) }
		else if registry.is_object() {
			binding := host.registries[voidptr(registry.as_object())] or { return vm.throw_error(.type_error, 'customElementRegistry requires a CustomElementRegistry') }
			options.custom_element_registry = voidptr(binding.native)
		} else { return vm.throw_error(.type_error, 'customElementRegistry requires a CustomElementRegistry') }
	}
	is_value := object.get(mut vm, libjs.PropertyName.from_str('is'))!
	if !is_value.is_undefined() { options.is_ = is_value.to_primitive_string(mut vm)!.str() }
	return options
}

// DOM/Document.idl and its native element factories. The qualified name and
// namespace are validated by DOM, preserving SVG case and XML prefixes.
fn (mut host Host) install_element_factories() {
	mut document := host.document_prototype
	for name in ['createElement', 'createElementNS'] {
		host.method_attributes(mut document, name, if name == 'createElementNS' { 2 } else { 1 }, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			node := host.node(mut vm)!
			if !node.is_document() { return vm.throw_error(.type_error, name + ' requires a document') }
			namespaced := name == 'createElementNS'
			if vm.argument_count() < u32(if namespaced { 2 } else { 1 }) { return vm.throw_error(.type_error, name + ' requires a name') }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			namespace_ := if namespaced && !vm.argument(0).is_nullish() { ?string(vm.argument(0).to_primitive_string(mut vm)!.str()) } else { none }
			local_name := vm.argument(if namespaced { 1 } else { 0 }).to_primitive_string(mut vm)!.str()
			options := host.element_creation_options(mut vm, vm.argument(if namespaced { 2 } else { 1 }))!
			mut owner := unsafe { &Host(host) }
			element := if namespaced {
				node.document().create_element_ns_with_options(namespace_, local_name, options) or { return owner.dom_error(mut vm, err) }
			} else {
				node.document().create_element_with_options(local_name, options) or { return owner.dom_error(mut vm, err) }
			}
			owner.drain_custom_elements()
			return owner.wrap_node(element.as_node())
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	mut element := host.element_prototype
	for name in ['namespaceURI', 'prefix', 'localName'] {
		host.accessor(mut element, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.element(mut vm)!
			value := match name {
				'namespaceURI' { native.namespace_uri() }
				'prefix' { native.prefix() }
				else { ?string(native.local_name()) }
			}
			return if text := value { libjs.Value.from_string(vm.create_string(libjs.utf16_string_from_utf8_without_validation(text))) } else { libjs.js_null() }
		}, unsafe { nil })
	}
}
