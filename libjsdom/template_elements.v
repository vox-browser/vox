// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

// HTMLTemplateElement.content_for_bindings. Native template contents retain
// their inert owner document and transfer actual children on insertion.
fn (mut host Host) install_template_elements() ! {
	mut prototype := host.html_element_prototypes['HTMLTemplateElement'] or { return error('Missing HTMLTemplateElement prototype') }
	host.accessor(mut prototype, 'content', fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.element(mut vm)!
		if !native.is_html_element() || native.local_name() != 'template' { return vm.throw_error(.type_error, 'HTMLTemplateElement.content requires a template') }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		contents := dom.html_template_element_content_for_bindings(unsafe { &dom.HTMLTemplateElement(native) })
		mut owner := unsafe { &Host(host) }
		return owner.wrap_node(contents.as_node())
	}, unsafe { nil })
}
