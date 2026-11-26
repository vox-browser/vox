// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (mut host Host) install_parent_node_properties() {
	mut prototypes := [host.element_prototype, host.document_prototype, host.fragment_prototype]
	for mut prototype in prototypes {
		for name in ['children', 'childElementCount', 'firstElementChild', 'lastElementChild'] {
			host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
				node := host.node(mut vm)!
				if !node.is_element() && !node.is_document() && !node.is_document_fragment() { return vm.throw_error(.type_error, 'ParentNode member requires a parent node') }
				persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
				mut parent := unsafe { &dom.ParentNode(node) }
				mut owner := unsafe { &Host(host) }
				if name == 'children' { return owner.wrap_collection(parent.children_collection()) }
				if name == 'childElementCount' { return libjs.Value.from_f64(f64(parent.child_element_count())) }
				element := if name == 'firstElementChild' { parent.first_element_child() } else { parent.last_element_child() }
				return if child := element { owner.wrap_node(child.as_node()) } else { libjs.js_null() }
			}, unsafe { nil })
		}
	}
}
