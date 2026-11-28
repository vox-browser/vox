// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (host &Host) tree_node_argument(mut vm libjs.VM, value libjs.Value) !&dom.Node {
	if value.is_object() {
		if node := host.nodes[voidptr(value.as_object())] { return node }
	}
	return vm.throw_error(.type_error, 'Node argument required')
}

// DOM/Node.idl: use pre-insert/pre-remove/replacement, retaining native tree
// validity, adoption, observer records and custom-element reactions.
fn (mut host Host) install_tree_mutations(mut prototype libjs.Object) {
	for name in ['insertBefore', 'appendChild', 'replaceChild', 'removeChild'] {
		length := if name in ['insertBefore', 'replaceChild'] { 2 } else { 1 }
		host.method_attributes(mut prototype, name, length, fn [host, name, length] (mut vm libjs.VM) !libjs.Value {
			mut parent := host.node(mut vm)!
			if vm.argument_count() < length { return vm.throw_error(.type_error, name + ' requires ' + length.str() + ' arguments') }
			value := vm.argument(0)
			node := host.tree_node_argument(mut vm, value)!
			mut child := ?&dom.Node(none)
			if length == 2 && (name == 'replaceChild' || !vm.argument(1).is_nullish()) {
				child = host.tree_node_argument(mut vm, vm.argument(1))!
			}
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			defer { owner.drain_custom_elements(); owner.changed() }
			match name {
				'insertBefore' { parent.pre_insert(node, child) or { return owner.dom_error(mut vm, err) } }
				'appendChild' { parent.append_child(node) or { return owner.dom_error(mut vm, err) } }
				'replaceChild' { parent.replace_child(node, child or { return vm.throw_error(.type_error, 'Node argument required') }) or { return owner.dom_error(mut vm, err) } }
				else { parent.remove_child(node) or { return owner.dom_error(mut vm, err) } }
			}
			return if name == 'replaceChild' { vm.argument(1) } else { value }
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
}
