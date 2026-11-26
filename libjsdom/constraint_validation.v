// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs
import platform

fn (mut host Host) wrap_validity_state(control &html.FormAssociatedElement) libjs.Value {
	if object := host.validity_state_wrappers[voidptr(control)] { return libjs.Value.from_object(object) }
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, host.validity_state_prototype)
	object.class_name = 'ValidityState'
	host.validity_states[voidptr(object)] = html.ValidityState.create(control)
	host.validity_state_wrappers[voidptr(control)] = object
	return libjs.Value.from_object(object)
}

fn (host &Host) validity_state_receiver(mut vm libjs.VM) !&html.ValidityState {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if native := host.validity_states[voidptr(vm.this_value().as_object())] { return native }
	}
	return vm.throw_error(.type_error, 'Expected a ValidityState object')
}

fn validity_state_flag(native &html.ValidityState, name string) bool {
	return match name {
		'valueMissing' { native.value_missing() }
		'typeMismatch' { native.type_mismatch() }
		'patternMismatch' { native.pattern_mismatch() }
		'tooLong' { native.too_long() }
		'tooShort' { native.too_short() }
		'rangeUnderflow' { native.range_underflow() }
		'rangeOverflow' { native.range_overflow() }
		'stepMismatch' { native.step_mismatch() }
		'badInput' { native.bad_input() }
		'customError' { native.custom_error() }
		else { native.valid() }
	}
}

fn (mut host Host) install_constraint_validation() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.validity_state_prototype = prototype
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal ValidityState constructor') },
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal ValidityState constructor') }, 0, libjs.PropertyName.from_str('ValidityState')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('ValidityState')), libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('ValidityState'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for name in ['valueMissing', 'typeMismatch', 'patternMismatch', 'tooLong', 'tooShort', 'rangeUnderflow', 'rangeOverflow', 'stepMismatch', 'badInput', 'customError', 'valid'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
			return libjs.Value.from_bool(validity_state_flag(host.validity_state_receiver(mut vm)!, name))
		}, unsafe { nil })
	}
	for tag, interface_name in {'input':'HTMLInputElement', 'textarea':'HTMLTextAreaElement', 'select':'HTMLSelectElement', 'button':'HTMLButtonElement'} {
		mut control_prototype := host.html_element_prototypes[interface_name] or { return error('Missing validation control prototype') }
		for name in ['willValidate', 'validity', 'validationMessage'] {
			host.accessor(mut control_prototype, name, fn [host, tag, name] (mut vm libjs.VM) !libjs.Value {
				element := host.form_control_receiver(mut vm, tag)!
				persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
				control := native_form_control(element)
				if name == 'willValidate' { return libjs.Value.from_bool(control.will_validate()) }
				if name == 'validationMessage' { return libjs.Value.from_string(vm.create_string_from_str(control.validation_message())) }
				mut owner := unsafe { &Host(host) }; return owner.wrap_validity_state(control)
			}, unsafe { nil })
		}
		for name in ['checkValidity', 'reportValidity', 'setCustomValidity'] {
			host.method_attributes(mut control_prototype, name, if name == 'setCustomValidity' { 1 } else { 0 }, fn [host, tag, name] (mut vm libjs.VM) !libjs.Value {
				element := host.form_control_receiver(mut vm, tag)!
				persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
				mut owner := unsafe { &Host(host) }
				if name == 'setCustomValidity' {
					if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'setCustomValidity requires a message') }
					message := vm.argument(0).to_primitive_string(mut vm)!.str()
					mut control := native_form_control(element); control.set_custom_validity(message)
					owner.finish_form_mutation(); return libjs.js_undefined()
				}
				control := native_form_control(element)
				valid := if name == 'checkValidity' { control.check_validity() } else { control.report_validity() }
				owner.finish_form_mutation(); return libjs.Value.from_bool(valid)
			}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
		}
	}
}
