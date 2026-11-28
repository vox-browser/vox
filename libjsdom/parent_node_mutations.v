// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (mut host Host) install_parent_node_mutations() {
	mut prototypes := [host.element_prototype, host.document_prototype, host.fragment_prototype]
	for mut prototype in prototypes {
		for name in ['append', 'prepend', 'replaceChildren'] {
			host.method_attributes(mut prototype, name, 0, fn [host, name] (mut vm libjs.VM) !libjs.Value {
				actual := host.node(mut vm)!
				if !actual.is_element() && !actual.is_document() && !actual.is_document_fragment() { return vm.throw_error(.type_error, 'ParentNode method called on incompatible receiver') }
				persistent := platform.enter_persistent()
				defer { platform.leave_persistent(persistent) }
				mut nodes := []dom.NodeOrString{}
				// WebIDL converts the entire variadic Node-or-DOMString list
				// before entering the native mutation algorithm.
				for index in 0 .. vm.argument_count() {
					vm.consume_execution_budget()!
					value := vm.argument(index)
					if value.is_object() {
						if node := host.nodes[voidptr(value.as_object())] {
							nodes << dom.NodeOrString{node: node}
							continue
						}
					}
					nodes << dom.NodeOrString{is_text: true, text: value.to_primitive_string(mut vm)!.str()}
				}
				mut owner := unsafe { &Host(host) }
				defer { owner.drain_custom_elements(); owner.changed() }
				mut parent := unsafe { &dom.ParentNode(actual) }
				match name {
					'append' { parent.append(nodes) or { return owner.dom_error(mut vm, err) } }
					'prepend' { parent.prepend(nodes) or { return owner.dom_error(mut vm, err) } }
					else { parent.replace_children(nodes) or { return owner.dom_error(mut vm, err) } }
				}
				return libjs.js_undefined()
			}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
		}
	}
}
