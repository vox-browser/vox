// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform
import webidl

fn native_text_control(element &dom.Element) &html.FormAssociatedTextControlElement {
	if element.local_name() == 'input' {
		return html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) }).text_control
	}
	return html.HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) }).text
}

fn selection_unsigned_long(mut vm libjs.VM, value libjs.Value) !u32 {
	number := value.to_number(mut vm)!.number
	return u32(webidl.convert_to_int(webidl.number_value(number), 32, false, .no, .no)!)
}

fn set_text_selection_member(mut vm libjs.VM, element &dom.Element, tag string, member string) ! {
	value := vm.argument(0)
	if member == 'selectionDirection' {
		direction := if tag == 'input' && value.is_nullish() { ?string(none) } else { ?string(value.to_primitive_string(mut vm)!.str()) }
		mut text := native_text_control(element)
		text.set_selection_direction_binding(direction)!
		return
	}
	position := if tag == 'input' && value.is_nullish() { ?u32(none) } else { ?u32(selection_unsigned_long(mut vm, value)!) }
	// Author conversions may have changed the input type or its value. Apply
	// the native operation only after conversion, using the live owner.
	mut text := native_text_control(element)
	if member == 'selectionStart' { text.set_selection_start_binding(position)! }
	else { text.set_selection_end_binding(position)! }
}

fn selection_mode_argument(mut vm libjs.VM) !html.SelectionMode {
	if vm.argument(3).is_undefined() { return .preserve }
	return match vm.argument(3).to_primitive_string(mut vm)!.str() {
		'select' { .select }
		'start' { .start }
		'end' { .end }
		'preserve' { .preserve }
		else { return vm.throw_error(.type_error, 'Invalid SelectionMode') }
	}
}

fn apply_text_selection_method(mut vm libjs.VM, element &dom.Element, member string) ! {
	if member == 'select' {
		mut text := native_text_control(element); text.select(); return
	}
	if member == 'setSelectionRange' {
		if vm.argument_count() < 2 { return vm.throw_error(.type_error, 'setSelectionRange requires start and end') }
		start := selection_unsigned_long(mut vm, vm.argument(0))!
		end := selection_unsigned_long(mut vm, vm.argument(1))!
		direction := if vm.argument(2).is_undefined() { ?string(none) } else { ?string(vm.argument(2).to_primitive_string(mut vm)!.str()) }
		mut text := native_text_control(element)
		text.set_selection_range(start, end, direction)!
		return
	}
	// Resolve the WebIDL overload before invoking any author conversion.
	if vm.argument_count() == 0 || vm.argument_count() == 2 { return vm.throw_error(.type_error, 'setRangeText requires one or at least three arguments') }
	replacement := vm.argument(0).to_primitive_string(mut vm)!.str()
	if vm.argument_count() == 1 {
		mut text := native_text_control(element)
		text.set_range_text_at_selection(replacement)!
		return
	}
	start := selection_unsigned_long(mut vm, vm.argument(1))!
	end := selection_unsigned_long(mut vm, vm.argument(2))!
	mode := selection_mode_argument(mut vm)!
	mut text := native_text_control(element)
	text.set_range_text_binding(replacement, start, end, mode)!
}

fn (mut host Host) install_text_control_selection() ! {
	for tag, interface_name in {'input': 'HTMLInputElement', 'textarea': 'HTMLTextAreaElement'} {
		mut prototype := host.html_element_prototypes[interface_name] or { return error('Missing native text-control prototype') }
		for member in ['selectionStart', 'selectionEnd', 'selectionDirection'] {
			host.accessor(mut prototype, member, fn [host, tag, member] (mut vm libjs.VM) !libjs.Value {
				element := host.form_control_receiver(mut vm, tag)!
				persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
				text := native_text_control(element)
				if member == 'selectionDirection' {
					if direction := text.selection_direction() { return libjs.Value.from_string(vm.create_string_from_str(direction)) }
					return libjs.js_null()
				}
				position := if member == 'selectionStart' { text.selection_start_binding() } else { text.selection_end_binding() }
				return if offset := position { libjs.Value.from_f64(f64(offset)) } else { libjs.js_null() }
			}, fn [host, tag, member] (mut vm libjs.VM) !libjs.Value {
				element := host.form_control_receiver(mut vm, tag)!
				persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
				mut owner := unsafe { &Host(host) }
				set_text_selection_member(mut vm, element, tag, member) or { return owner.dom_error(mut vm, err) }
				owner.finish_form_mutation(); return libjs.js_undefined()
			})
		}
		for member in ['select', 'setSelectionRange', 'setRangeText'] {
			length := if member == 'select' { 0 } else if member == 'setSelectionRange' { 2 } else { 1 }
			host.method_attributes(mut prototype, member, length, fn [host, tag, member] (mut vm libjs.VM) !libjs.Value {
				element := host.form_control_receiver(mut vm, tag)!
				persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
				mut owner := unsafe { &Host(host) }
				apply_text_selection_method(mut vm, element, member) or { return owner.dom_error(mut vm, err) }
				owner.finish_form_mutation(); return libjs.js_undefined()
			}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
		}
	}
}
