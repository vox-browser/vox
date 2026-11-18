// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform
import webidl

fn (host &Host) form_control_receiver(mut vm libjs.VM, tag string) !&dom.Element {
	element := host.element(mut vm)!
	if !element.is_html_element() || element.local_name() != tag { return vm.throw_error(.type_error, 'Expected an HTML ${tag} element') }
	return element
}

fn prepare_libjs_select(element &dom.Element) &html.HTMLSelectElementModel {
	native := unsafe { &dom.HTMLSelectElement(element) }
	return html.HTMLSelectElementModel.create(native)
}

fn prepare_libjs_option(element &dom.Element) &dom.HTMLOptionElement {
	native := unsafe { &dom.HTMLOptionElement(element) }
	if select_element := html.html_option_element_nearest_select(native) { _ := prepare_libjs_select(unsafe { &dom.Element(select_element) }) }
	return native
}

fn (mut host Host) finish_form_mutation() {
	host.drain_custom_elements()
	host.changed()
}

fn (mut host Host) install_html_attribute_reflection(mut prototype libjs.Object, tag string, strings map[string]string, booleans map[string]string) {
	for boolean in [false, true] {
		members := if boolean { booleans } else { strings }
		for name, attribute in members {
			host.accessor(mut prototype, name, fn [host, tag, attribute, boolean] (mut vm libjs.VM) !libjs.Value {
				element := host.form_control_receiver(mut vm, tag)!
				if boolean { return libjs.Value.from_bool(element.has_attribute(attribute)) }
				text := libjs.utf16_string_from_utf8_without_validation(element.get_attribute_value(attribute))
				return libjs.Value.from_string(vm.create_string(text))
			}, fn [host, tag, attribute, boolean] (mut vm libjs.VM) !libjs.Value {
				mut element := unsafe { &dom.Element(host.form_control_receiver(mut vm, tag)!) }
				persistent := platform.enter_persistent()
				defer { platform.leave_persistent(persistent) }
				if boolean {
					if vm.argument(0).to_boolean() { element.set_attribute_value(attribute, '') } else { element.remove_attribute(attribute) }
				} else { element.set_attribute_value(attribute, vm.argument(0).to_primitive_string(mut vm)!.str()) }
				mut owner := unsafe { &Host(host) }; owner.finish_form_mutation()
				return libjs.js_undefined()
			})
		}
	}
}

fn form_control_state(mut vm libjs.VM, element &dom.Element, tag string, member string) !libjs.Value {
	if tag == 'input' {
		model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		if member == 'checked' { return libjs.Value.from_bool(model.checked()) }
		if member == 'indeterminate' { return libjs.Value.from_bool(model.indeterminate()) }
		text := if member == 'type' { model.type_() } else if member == 'defaultValue' { model.default_value() } else { model.value() }
		return libjs.Value.from_string(vm.create_string_from_str(text))
	}
	if tag == 'textarea' {
		model := html.HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) })
		if member == 'textLength' { return libjs.Value.from_f64(f64(model.text_length())) }
		text := if member == 'type' { 'textarea' } else if member == 'defaultValue' { model.default_value() } else { model.value() }
		return libjs.Value.from_string(vm.create_string_from_str(text))
	}
	if tag == 'select' {
		_ := prepare_libjs_select(element)
		native := unsafe { &dom.HTMLSelectElement(element) }
		if member == 'selectedIndex' { return libjs.Value.from_i32(html.html_select_element_selected_index(native)) }
		return libjs.Value.from_string(vm.create_string_from_str(if member == 'type' { html.html_select_element_type(native) } else { html.html_select_element_value(native) }))
	}
	if tag == 'option' {
		native := prepare_libjs_option(element)
		if member == 'selected' { return libjs.Value.from_bool(html.html_option_element_selected(native)) }
		if member == 'index' { return libjs.Value.from_i32(html.html_option_element_index(native)) }
		text := if member == 'text' { html.html_option_element_text(native) } else if member == 'label' { html.html_option_element_label(native) } else { html.html_option_element_value(native) }
		return libjs.Value.from_string(vm.create_string_from_str(text))
	}
	return libjs.Value.from_string(vm.create_string_from_str(if member == 'type' { html.html_button_element_type_for_bindings(unsafe { &dom.HTMLButtonElement(element) }) } else { html.html_button_element_value(unsafe { &dom.HTMLButtonElement(element) }) }))
}

fn set_form_control_state(mut vm libjs.VM, mut element dom.Element, tag string, member string) ! {
	value := vm.argument(0)
	if member == 'checked' {
		mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(&element) })
		model.set_checked_binding(value.to_boolean()); return
	}
	if member == 'indeterminate' {
		mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(&element) })
		model.set_indeterminate(value.to_boolean()); return
	}
	if member == 'selected' {
		html.html_option_element_set_selected(prepare_libjs_option(&element), value.to_boolean()); return
	}
	if member == 'selectedIndex' {
		number := value.to_number(mut vm)!.number
		index := i32(webidl.convert_to_int(webidl.number_value(number), 32, true, .no, .no)!)
		_ := prepare_libjs_select(&element)
		html.set_html_select_element_selected_index(unsafe { &dom.HTMLSelectElement(&element) }, index); return
	}
	text := if member == 'value' && tag in ['input', 'textarea'] && value.is_null() { '' } else { value.to_primitive_string(mut vm)!.str() }
	if tag == 'input' {
		mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(&element) })
		if member == 'type' { model.set_type(text) }
		else if member == 'defaultValue' { element.set_attribute_value('value', text) }
		else { model.set_value(text)! }
	} else if tag == 'textarea' {
		mut model := html.HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(&element) })
		if member == 'defaultValue' { model.set_default_value(text) } else { model.set_value(text) }
	} else if tag == 'select' {
		mut model := prepare_libjs_select(&element)
		model.create_shadow_tree_if_needed()
		html.set_html_select_element_value(unsafe { &dom.HTMLSelectElement(&element) }, text)
	} else if tag == 'option' {
		native := prepare_libjs_option(&element)
		if member == 'text' { html.set_html_option_element_text(native, text) }
		else if member == 'label' { html.set_html_option_element_label(native, text) }
		else { html.set_html_option_element_value(native, text) }
	} else {
		if member == 'type' { html.set_html_button_element_type_for_bindings(unsafe { &dom.HTMLButtonElement(&element) }, text) }
		else { element.set_attribute_value('value', text) }
	}
}

fn (mut host Host) install_form_controls() ! {
	for tag, interface_name in {'input': 'HTMLInputElement', 'textarea': 'HTMLTextAreaElement', 'select': 'HTMLSelectElement', 'option': 'HTMLOptionElement', 'button': 'HTMLButtonElement'} {
		mut prototype := host.html_element_prototypes[interface_name] or { return error('Missing native form-control prototype') }
		members := match tag {
			'input' { ['value', 'defaultValue', 'checked', 'indeterminate', 'type'] }
			'textarea' { ['value', 'defaultValue', 'type', 'textLength'] }
			'select' { ['value', 'selectedIndex', 'type'] }
			'option' { ['value', 'text', 'label', 'selected', 'index'] }
			else { ['value', 'type'] }
		}
		for member in members {
			readonly := member == 'index' || member == 'textLength' || (member == 'type' && tag in ['select', 'textarea'])
			getter := fn [host, tag, member] (mut vm libjs.VM) !libjs.Value {
				element := host.form_control_receiver(mut vm, tag)!
				persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
				return form_control_state(mut vm, element, tag, member)
			}
			setter := if readonly { libjs.NativeFunctionPointer(unsafe { nil }) } else { libjs.NativeFunctionPointer(fn [host, tag, member] (mut vm libjs.VM) !libjs.Value {
				mut element := unsafe { &dom.Element(host.form_control_receiver(mut vm, tag)!) }
				persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
				mut owner := unsafe { &Host(host) }
				set_form_control_state(mut vm, mut element, tag, member) or { return owner.dom_error(mut vm, err) }
				owner.finish_form_mutation(); return libjs.js_undefined()
			}) }
			host.accessor(mut prototype, member, getter, setter)
		}
		strings := match tag {
			'input' { {'accept':'accept', 'alt':'alt', 'dirName':'dirname', 'max':'max', 'min':'min', 'name':'name', 'pattern':'pattern', 'placeholder':'placeholder', 'step':'step'} }
			'textarea' { {'dirName':'dirname', 'name':'name', 'placeholder':'placeholder', 'wrap':'wrap'} }
			'select', 'button' { {'name':'name'} }
			else { map[string]string{} }
		}
		booleans := match tag {
			'input' { {'defaultChecked':'checked', 'disabled':'disabled', 'multiple':'multiple', 'readOnly':'readonly', 'required':'required'} }
			'textarea' { {'disabled':'disabled', 'readOnly':'readonly', 'required':'required'} }
			'select' { {'disabled':'disabled', 'multiple':'multiple', 'required':'required'} }
			'option' { {'disabled':'disabled', 'defaultSelected':'selected'} }
			else { {'disabled':'disabled'} }
		}
		host.install_html_attribute_reflection(mut prototype, tag, strings, booleans)
		host.accessor(mut prototype, 'form', fn [host, tag] (mut vm libjs.VM) !libjs.Value {
			element := host.form_control_receiver(mut vm, tag)!
			persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
			form := if tag == 'option' { html.html_option_element_form(prepare_libjs_option(element)) } else { html.computed_listed_element_form_owner(element) }
			mut owner := unsafe { &Host(host) }
			return if native := form { owner.wrap_node(native.as_node()) } else { libjs.js_null() }
		}, unsafe { nil })
	}
}
