// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (host &Host) keyboard_event_receiver(mut vm libjs.VM) !&dom.KeyboardEvent {
	event := host.event(mut vm)!
	if event.interface_ != .keyboard_event {
		return vm.throw_error(.type_error, 'Expected KeyboardEvent')
	}
	return unsafe { &dom.KeyboardEvent(event) }
}

fn (host &Host) keyboard_event_dictionary(mut vm libjs.VM, options libjs.Value) !dom.KeyboardEventInit {
	modifiers := host.event_modifier_dictionary(mut vm, options)!
	char_code := text_encoding_member(mut vm, options, 'charCode')!.to_u32(mut vm)!
	code_value := text_encoding_member(mut vm, options, 'code')!
	code := if code_value.is_undefined() {
		''
	} else {
		code_value.to_primitive_string(mut vm)!.str()
	}
	composing := text_encoding_member(mut vm, options, 'isComposing')!.to_boolean()
	key_value := text_encoding_member(mut vm, options, 'key')!
	key := if key_value.is_undefined() { '' } else { key_value.to_primitive_string(mut vm)!.str() }
	key_code := text_encoding_member(mut vm, options, 'keyCode')!.to_u32(mut vm)!
	location := text_encoding_member(mut vm, options, 'location')!.to_u32(mut vm)!
	repeat := text_encoding_member(mut vm, options, 'repeat')!.to_boolean()
	return dom.KeyboardEventInit{
		EventModifierInit: modifiers
		key:               key
		code:              code
		char_code:         char_code
		key_code:          key_code
		location:          location
		repeat:            repeat
		is_composing:      composing
	}
}

fn (mut host Host) install_keyboard_events() ! {
	mut prototype := libjs.Object.create(host.realm, host.ui_event_prototype)
	host.keyboard_event_prototype = prototype
	host.register_event_interface(mut prototype, 'KeyboardEvent', 'UIEvent', fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		if vm.argument_count() == 0 {
			return vm.throw_error(.type_error, 'KeyboardEvent requires a type')
		}
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		init := host.keyboard_event_dictionary(mut vm, vm.argument(1))!
		native := dom.KeyboardEvent.construct_impl(type_, init)!
		mut object := libjs.Object.create(host.realm, if parent.is_object() {
			parent.as_object()
		} else {
			host.keyboard_event_prototype
		})
		mut owner := unsafe { &Host(host) }
		return owner.register_event_wrapper(mut object, unsafe { &dom.Event(native) }).as_object()
	})!
	for name in ['key', 'code', 'location', 'ctrlKey', 'shiftKey', 'altKey', 'metaKey', 'repeat',
		'isComposing', 'charCode', 'keyCode'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.keyboard_event_receiver(mut vm)!
			if name in ['key', 'code'] {
				return libjs.Value.from_string(vm.create_string_from_str(if name == 'key' {
					native.key()
				} else {
					native.code()
				}))
			}
			if name in ['location', 'charCode', 'keyCode'] {
				return libjs.Value.from_f64(f64(match name {
					'location' { native.location() }
					'charCode' { native.char_code() }
					else { native.key_code() }
				}))
			}
			return libjs.Value.from_bool(match name {
				'ctrlKey' { native.ctrl_key() }
				'shiftKey' { native.shift_key() }
				'altKey' { native.alt_key() }
				'metaKey' { native.meta_key() }
				'repeat' { native.repeat() }
				else { native.is_composing() }
			})
		}, unsafe { nil })
	}
	host.method_attributes(mut prototype, 'getModifierState', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.keyboard_event_receiver(mut vm)!
		if vm.argument_count() == 0 {
			return vm.throw_error(.type_error, 'getModifierState requires a key')
		}
		return libjs.Value.from_bool(native.get_modifier_state(vm.argument(0).to_primitive_string(mut vm)!.str()))
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	host.method_attributes(mut prototype, 'initKeyboardEvent', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut native := host.keyboard_event_receiver(mut vm)!
		if vm.argument_count() == 0 {
			return vm.throw_error(.type_error, 'initKeyboardEvent requires a type')
		}
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		bubbles, cancelable := vm.argument(1).to_boolean(), vm.argument(2).to_boolean()
		view := host.ui_event_view_argument(mut vm, vm.argument(3))!
		key := if vm.argument(4).is_undefined() {
			''
		} else {
			vm.argument(4).to_primitive_string(mut vm)!.str()
		}
		location := vm.argument(5).to_u32(mut vm)!
		ctrl, alt := vm.argument(6).to_boolean(), vm.argument(7).to_boolean()
		shift, meta := vm.argument(8).to_boolean(), vm.argument(9).to_boolean()
		native.init_keyboard_event(type_, bubbles, cancelable, view, key, location, ctrl, alt, shift, meta)
		return libjs.js_undefined()
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	for name, value in {
		'DOM_KEY_LOCATION_STANDARD': 0
		'DOM_KEY_LOCATION_LEFT':     1
		'DOM_KEY_LOCATION_RIGHT':    2
		'DOM_KEY_LOCATION_NUMPAD':   3
	} {
		mut vm := host.vm
		mut constructor := host.realm.global_object_record().get(mut vm, libjs.PropertyName.from_str('KeyboardEvent'))!.as_object()
		prototype.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_i32(value), libjs.attribute_enumerable)
		constructor.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_i32(value), libjs.attribute_enumerable)
	}
}
