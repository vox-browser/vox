// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import math
import platform

fn (host &Host) mouse_event_receiver(mut vm libjs.VM) !&dom.MouseEvent {
	event := host.event(mut vm)!
	if !libjsdom_is_mouse_event(event) { return vm.throw_error(.type_error, 'Expected MouseEvent') }
	return unsafe { &dom.MouseEvent(event) }
}

fn (host &Host) event_target_argument(mut vm libjs.VM, value libjs.Value) !&dom.EventTarget {
	if value.is_nullish() { return unsafe { nil } }
	if value.is_object() {
		if voidptr(value.as_object()) == voidptr(host.realm.global_object_record()) {
			if window := host.document.get_window() { return unsafe { &dom.EventTarget(window) } }
		}
		if node := host.nodes[voidptr(value.as_object())] {
			return unsafe { &dom.EventTarget(node) }
		}
		if target := host.event_targets[voidptr(value.as_object())] { return target }
	}
	return vm.throw_error(.type_error, 'Expected EventTarget')
}

fn mouse_event_double_member(mut vm libjs.VM, options libjs.Value, name string) !f64 {
	value := text_encoding_member(mut vm, options, name)!
	if value.is_undefined() { return 0 }
	number := value.to_number(mut vm)!.number
	if math.is_nan(number) || math.is_inf(number, 0) {
		return vm.throw_error(.type_error, name + ' must be finite')
	}
	return number
}

fn (host &Host) mouse_event_dictionary(mut vm libjs.VM, options libjs.Value) !dom.MouseEventInit {
	modifiers := host.event_modifier_dictionary(mut vm, options)!
	button := text_encoding_member(mut vm, options, 'button')!.to_i16(mut vm)!
	buttons := text_encoding_member(mut vm, options, 'buttons')!.to_u16(mut vm)!
	client_x, client_y := mouse_event_double_member(mut vm, options, 'clientX')!, mouse_event_double_member(mut vm, options, 'clientY')!
	movement_x, movement_y := mouse_event_double_member(mut vm, options, 'movementX')!, mouse_event_double_member(mut vm, options, 'movementY')!
	related_pointer := host.event_target_argument(mut vm, text_encoding_member(mut vm, options, 'relatedTarget')!)!
	related := if related_pointer == unsafe { nil } {
		?&dom.EventTarget(none)
	} else {
		?&dom.EventTarget(related_pointer)
	}
	screen_x, screen_y := mouse_event_double_member(mut vm, options, 'screenX')!, mouse_event_double_member(mut vm, options, 'screenY')!
	return dom.MouseEventInit{ EventModifierInit: modifiers, button: button, buttons: buttons, client_x: client_x, client_y: client_y, movement_x: movement_x, movement_y: movement_y, related_target: related, screen_x: screen_x, screen_y: screen_y }
}

fn (mut host Host) install_mouse_events() ! {
	mut prototype := libjs.Object.create(host.realm, host.ui_event_prototype)
	host.mouse_event_prototype = prototype
	host.register_event_interface(mut prototype, 'MouseEvent', 'UIEvent', fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		if vm.argument_count() == 0 {
			return vm.throw_error(.type_error, 'MouseEvent requires a type')
		}
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		init := host.mouse_event_dictionary(mut vm, vm.argument(1))!
		native := dom.MouseEvent.construct_impl(type_, init)!
		mut object := libjs.Object.create(host.realm, if parent.is_object() {
			parent.as_object()
		} else {
			host.mouse_event_prototype
		})
		mut owner := unsafe { &Host(host) }
		return owner.register_event_wrapper(mut object, unsafe { &dom.Event(native) }).as_object()
	})!
	for name in ['screenX', 'screenY', 'pageX', 'pageY', 'clientX', 'clientY', 'x', 'y', 'offsetX',
		'offsetY', 'ctrlKey', 'shiftKey', 'altKey', 'metaKey', 'movementX', 'movementY', 'button',
		'buttons', 'relatedTarget'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.mouse_event_receiver(mut vm)!
			if name == 'relatedTarget' {
				mut owner := unsafe { &Host(host) }
				return if target := native.related_target() {
					owner.wrap_target(target)
				} else {
					libjs.js_null()
				}
			}
			if name in ['ctrlKey', 'shiftKey', 'altKey', 'metaKey'] {
				return libjs.Value.from_bool(match name {
					'ctrlKey' { native.ctrl_key() }
					'shiftKey' { native.shift_key() }
					'altKey' { native.alt_key() }
					else { native.meta_key() }
				})
			}
			if native.interface_ == .pointer_event && name in ['screenX', 'screenY', 'pageX', 'pageY',
				'clientX', 'clientY', 'x', 'y', 'offsetX', 'offsetY'] {
				pointer := unsafe { &dom.PointerEvent(native) }
				return libjs.Value.from_f64(match name {
					'screenX' { pointer.screen_x() }
					'screenY' { pointer.screen_y() }
					'pageX' { pointer.page_x() }
					'pageY' { pointer.page_y() }
					'clientX', 'x' { pointer.client_x() }
					'clientY', 'y' { pointer.client_y() }
					'offsetX' { pointer.offset_x() }
					else { pointer.offset_y() }
				})
			}
			return libjs.Value.from_f64(match name {
				'screenX' { native.screen_x() }
				'screenY' { native.screen_y() }
				'pageX' { native.page_x() }
				'pageY' { native.page_y() }
				'clientX', 'x' { native.client_x() }
				'clientY', 'y' { native.client_y() }
				'offsetX' { native.offset_x() }
				'offsetY' { native.offset_y() }
				'movementX' { native.movement_x() }
				'movementY' { native.movement_y() }
				'button' { f64(native.button()) }
				else { f64(native.buttons()) }
			})
		}, unsafe { nil })
	}
	host.method_attributes(mut prototype, 'getModifierState', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.mouse_event_receiver(mut vm)!
		if vm.argument_count() == 0 {
			return vm.throw_error(.type_error, 'getModifierState requires a key')
		}
		return libjs.Value.from_bool(native.get_modifier_state(vm.argument(0).to_primitive_string(mut vm)!.str()))
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	host.method_attributes(mut prototype, 'initMouseEvent', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut native := host.mouse_event_receiver(mut vm)!
		if vm.argument_count() == 0 {
			return vm.throw_error(.type_error, 'initMouseEvent requires a type')
		}
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		bubbles, cancelable := vm.argument(1).to_boolean(), vm.argument(2).to_boolean()
		view := host.ui_event_view_argument(mut vm, vm.argument(3))!
		detail := vm.argument(4).to_i32(mut vm)!
		sx, sy := vm.argument(5).to_i32(mut vm)!, vm.argument(6).to_i32(mut vm)!
		cx, cy := vm.argument(7).to_i32(mut vm)!, vm.argument(8).to_i32(mut vm)!
		ctrl, alt, shift, meta := vm.argument(9).to_boolean(), vm.argument(10).to_boolean(), vm.argument(11).to_boolean(), vm.argument(12).to_boolean()
		button := vm.argument(13).to_i16(mut vm)!
		related_pointer := host.event_target_argument(mut vm, vm.argument(14))!
		related := if related_pointer == unsafe { nil } {
			?&dom.EventTarget(none)
		} else {
			?&dom.EventTarget(related_pointer)
		}
		native.init_mouse_event(type_, bubbles, cancelable, view, int(detail), int(sx), int(sy), int(cx), int(cy), ctrl, alt, shift, meta, button, related)
		return libjs.js_undefined()
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
}
