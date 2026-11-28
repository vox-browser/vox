// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import css
import dom
import libjs
import platform

fn (mut host Host) install_element_selectors() {
	mut prototype := host.element_prototype
	for name in ['matches','closest'] {
		host.method_attributes(mut prototype, name, 1, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.element(mut vm)!
			if vm.argument_count() == 0 { return vm.throw_error(.type_error, name + ' requires selectors') }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			selectors := vm.argument(0).to_primitive_string(mut vm)!.str()
			css.install_document_selector_query_hook(native.document())
			mut owner := unsafe { &Host(host) }
			if name == 'matches' { return libjs.Value.from_bool(native.matches(selectors) or { return owner.dom_error(mut vm, err) }) }
			// Retain the original scoping root for every inclusive ancestor.
			// Use the native checked hook so invalid syntax throws, including
			// when a selector has no matching ancestor.
			hook := native.document().selector_query_hook() or { return error('Missing native selector query hook') }
			mut current := ?&dom.Element(native)
			for {
				candidate := current or { break }
				vm.consume_execution_budget()!
				if hook.matches_checked(hook.target, selectors, candidate, unsafe { &dom.ParentNode(native) }) or { return owner.dom_error(mut vm, err) } {
					return owner.wrap_node(candidate.as_node())
				}
				current = candidate.as_node().parent_element()
			}
			return libjs.js_null()
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	for name in ['getAttributeNames','toggleAttribute'] {
		host.method_attributes(mut prototype, name, if name == 'toggleAttribute' { 1 } else { 0 }, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut native := host.element(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			if name == 'getAttributeNames' {
				mut names := []libjs.Value{}
				for text in native.get_attribute_names() { names << libjs.Value.from_string(vm.create_string_from_str(text)) }
				return libjs.Value.from_object(libjs.ArrayObject.create_from(mut vm, host.realm, names, host.realm.array_prototype_record())!.object)
			}
			if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'toggleAttribute requires a name') }
			key := vm.argument(0).to_primitive_string(mut vm)!.str()
			force := if vm.argument_count() < 2 { ?bool(none) } else { ?bool(vm.argument(1).to_boolean()) }
			mut owner := unsafe { &Host(host) }
			defer { owner.drain_custom_elements(); owner.changed() }
			return libjs.Value.from_bool(native.toggle_attribute(key, force) or { return owner.dom_error(mut vm, err) })
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
}
