// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (host &Host) document_receiver(mut vm libjs.VM) !&dom.Document {
	node := host.node(mut vm)!
	if !node.is_document() { return vm.throw_error(.type_error, 'Document member requires Document') }
	return node.document()
}

// Read the owning native document; cookie access retains the PageClient hook
// and native non-HTTP cookie policy rather than keeping a script-side jar.
fn (mut host Host) install_document_state() {
	mut prototype := host.document_prototype
	host.method_attributes(mut prototype,'getElementsByName',1,fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.document_receiver(mut vm)!
		if vm.argument_count()==0 { return vm.throw_error(.type_error,'getElementsByName requires a name') }
		persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
		name := vm.argument(0).to_primitive_string(mut vm)!.str()
		mut owner := unsafe { &Host(host) }
		return owner.wrap_node_list(native.get_elements_by_name(name))
	},libjs.attribute_writable|libjs.attribute_enumerable|libjs.attribute_configurable)
	for name in ['documentURI','contentType','characterSet','charset','inputEncoding','title','cookie','domain','hidden','visibilityState','activeElement','defaultView','location'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut native := host.document_receiver(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			if name == 'hidden' { return libjs.Value.from_bool(native.hidden()) }
			if name == 'activeElement' { return if element := native.active_element() { owner.wrap_node(element.as_node()) } else { libjs.js_null() } }
			if name in ['defaultView','location'] {
				if voidptr(native) != voidptr(host.document) || native.default_view() == none { return libjs.js_null() }
				if name == 'defaultView' { return libjs.Value.from_object(host.realm.global_object_record()) }
				return host.realm.global_object_record().get(mut vm, libjs.PropertyName.from_str('location'))
			}
			text := match name {
				'documentURI' { native.url.serialize() }
				'contentType' { native.get_content_type() }
				'characterSet','charset','inputEncoding' { native.character_set() }
				'title' { native.title() }
				'cookie' { native.cookie() or { return owner.dom_error(mut vm, err) } }
				'domain' { native.domain() }
				else { native.visibility_state() }
			}
			return libjs.Value.from_string(vm.create_string_from_str(text))
		}, if name in ['title','cookie','domain'] { fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut native := host.document_receiver(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			text := vm.argument(0).to_primitive_string(mut vm)!.str()
			mut owner := unsafe { &Host(host) }
			if name == 'title' { native.set_title(text) or { return owner.dom_error(mut vm, err) }; owner.changed() }
			else if name == 'domain' { native.set_domain(text) or { return owner.dom_error(mut vm, err) } }
			else { native.set_cookie(text) or { return owner.dom_error(mut vm, err) } }
			return libjs.js_undefined()
		} } else { unsafe { nil } })
	}
}
