// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (mut host Host) install_node_utilities() {
	mut prototype := host.node_prototype
	for name in ['isConnected', 'baseURI', 'nodeValue'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.node(mut vm)!
			if name == 'isConnected' { return libjs.Value.from_bool(native.is_connected()) }
			if name == 'baseURI' { return libjs.Value.from_string(vm.create_string_from_str(native.base_uri())) }
			return if text := native.node_value() { libjs.Value.from_string(vm.create_string_from_str(text)) } else { libjs.js_null() }
		}, if name == 'nodeValue' { fn [host] (mut vm libjs.VM) !libjs.Value {
			mut native := host.node(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			text := if vm.argument(0).is_nullish() { ?string(none) } else { ?string(vm.argument(0).to_primitive_string(mut vm)!.str()) }
			mut owner := unsafe { &Host(host) }
			defer { owner.drain_custom_elements(); owner.changed() }
			native.set_node_value(text) or { return owner.dom_error(mut vm, err) }
			return libjs.js_undefined()
		} } else { unsafe { nil } })
	}
	for name in ['contains', 'isSameNode', 'isEqualNode', 'compareDocumentPosition'] {
		host.method_attributes(mut prototype, name, 1, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.node(mut vm)!
			if vm.argument_count() == 0 { return vm.throw_error(.type_error, name + ' requires a Node argument') }
			other := if vm.argument(0).is_nullish() && name != 'compareDocumentPosition' { ?&dom.Node(none) } else { ?&dom.Node(host.tree_node_argument(mut vm, vm.argument(0))!) }
			return match name {
				'contains' { libjs.Value.from_bool(native.contains(other)) }
				'isSameNode' { libjs.Value.from_bool(native.is_same_node(other)) }
				'isEqualNode' { libjs.Value.from_bool(native.is_equal_node(other)) }
				else { libjs.Value.from_i32(i32(native.compare_document_position(other))) }
			}
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	for name in ['hasChildNodes', 'getRootNode', 'cloneNode', 'normalize'] {
		host.method_attributes(mut prototype, name, 0, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut native := host.node(mut vm)!
			if name == 'hasChildNodes' { return libjs.Value.from_bool(native.has_child_nodes()) }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			if name == 'getRootNode' {
				value := vm.argument(0)
				if !value.is_nullish() && !value.is_object() { return vm.throw_error(.type_error, 'GetRootNodeOptions must be an object') }
				composed := if value.is_nullish() { false } else { value.as_object().get(mut vm, libjs.PropertyName.from_str('composed'))!.to_boolean() }
				return owner.wrap_node(native.get_root_node(dom.GetRootNodeOptions{composed: composed}))
			}
			defer { owner.drain_custom_elements(); owner.changed() }
			if name == 'cloneNode' { return owner.wrap_node(native.clone_node_binding(vm.argument(0).to_boolean()) or { return owner.dom_error(mut vm, err) }) }
			native.normalize() or { return owner.dom_error(mut vm, err) }
			return libjs.js_undefined()
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	mut targets := [host.element_prototype, host.character_data_prototype]
	for mut target in targets {
		for name in ['before', 'after', 'replaceWith', 'remove'] {
			host.method_attributes(mut target, name, 0, fn [host, name] (mut vm libjs.VM) !libjs.Value {
				mut native := host.node(mut vm)!
				if !native.is_element() && !native.is_character_data() { return vm.throw_error(.type_error, 'ChildNode member requires Element or CharacterData') }
				persistent := platform.enter_persistent()
				defer { platform.leave_persistent(persistent) }
				mut values := []dom.NodeOrString{}
				if name != 'remove' {
					for index in 0 .. vm.argument_count() {
						vm.consume_execution_budget()!
						value := vm.argument(index)
						if value.is_object() { if node := host.nodes[voidptr(value.as_object())] { values << dom.NodeOrString{node: node}; continue } }
						values << dom.NodeOrString{is_text: true, text: value.to_primitive_string(mut vm)!.str()}
					}
				}
				mut owner := unsafe { &Host(host) }
				defer { owner.drain_custom_elements(); owner.changed() }
				match name {
					'before' { native.before(values) or { return owner.dom_error(mut vm, err) } }
					'after' { native.after(values) or { return owner.dom_error(mut vm, err) } }
					'replaceWith' { native.replace_with(values) or { return owner.dom_error(mut vm, err) } }
					else { native.remove(false) }
				}
				return libjs.js_undefined()
			}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
		}
		mut unscopables := libjs.Object.create(host.realm, none)
		for name in ['before','after','replaceWith','remove'] { unscopables.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_bool(true), libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable) }
		target.define_direct_property(libjs.PropertyName.from_symbol(host.vm.well_known_symbol_unscopables()), libjs.Value.from_object(unscopables), libjs.attribute_configurable)
	}
}
