// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform

fn (host &Host) html_element_receiver(mut vm libjs.VM) !&dom.HTMLElement {
	element := host.element(mut vm)!
	if !element.is_html_element() { return vm.throw_error(.type_error, 'Expected HTMLElement') }
	return unsafe { &dom.HTMLElement(element) }
}

fn (mut host Host) install_element_focus() {
	mut prototype := host.html_element_prototype
	host.accessor(mut prototype, 'tabIndex', fn [host] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_f64(f64(host.html_element_receiver(mut vm)!.tab_index()))
	}, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut native := host.html_element_receiver(mut vm)!
		value := vm.argument(0).to_i32(mut vm)!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		native.set_tab_index(int(value))
		mut owner := unsafe { &Host(host) }
		owner.changed()
		return libjs.js_undefined()
	})
	for name in ['focus', 'blur'] {
		host.method_attributes(mut prototype, name, 0, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.html_element_receiver(mut vm)!
			element := unsafe { &dom.Element(native) }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut prevent_scroll := false
			if name == 'focus' {
				options := vm.argument(0)
				if !options.is_nullish() && !options.is_object() {
					return vm.throw_error(.type_error, 'FocusOptions must be a dictionary')
				}
				// Native focus indication currently follows the document policy.
				// Preserve observable dictionary access order for focusVisible.
				_ = text_encoding_member(mut vm, options, 'focusVisible')!.to_boolean()
				prevent_scroll = text_encoding_member(mut vm, options, 'preventScroll')!.to_boolean()
			}
			mut document := element.document()
			mut manager := html.FocusManager.create()
			manager.currently_focused_area = document.focused_area()
			if name == 'blur' {
				html.run_unfocusing_steps(mut manager, element.as_node())
			} else if document.allow_focus() && element.is_focusable() {
				html.run_focusing_steps(mut manager, element.as_node(), none, .other)
				if !prevent_scroll {
					mut mutable := unsafe { &dom.Element(element) }
					_ = mutable.scroll_into_view()
				}
			}
			mut owner := unsafe { &Host(host) }
			owner.changed()
			return libjs.js_undefined()
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	mut document := host.document_prototype
	host.method_attributes(mut document, 'hasFocus', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_bool(host.document_receiver(mut vm)!.has_focus_for_bindings())
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
}
