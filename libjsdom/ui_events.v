// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn libjsdom_is_ui_event(event &dom.Event) bool {
	return event.interface_ in [.ui_event, .mouse_event, .pointer_event, .keyboard_event,
		.composition_event, .focus_event, .input_event, .text_event, .wheel_event, .drag_event]
}

fn libjsdom_is_mouse_event(event &dom.Event) bool {
	return event.interface_ in [.mouse_event, .pointer_event, .wheel_event, .drag_event]
}

fn (host &Host) ui_event_receiver(mut vm libjs.VM) !&dom.UIEvent {
	event := host.event(mut vm)!
	if !libjsdom_is_ui_event(event) { return vm.throw_error(.type_error, 'Expected UIEvent') }
	return unsafe { &dom.UIEvent(event) }
}

fn (host &Host) ui_event_view_argument(mut vm libjs.VM, value libjs.Value) !voidptr {
	if value.is_nullish() { return unsafe { nil } }
	if !value.is_object() || voidptr(value.as_object()) != voidptr(host.realm.global_object_record()) {
		return vm.throw_error(.type_error, 'UIEvent view requires the owning Window')
	}
	view := host.document.default_view() or { return vm.throw_error(.type_error, 'UIEvent has no owning Window') }
	return voidptr(view)
}

fn (host &Host) ui_event_dictionary(mut vm libjs.VM, options libjs.Value) !dom.UIEventInit {
	if !options.is_nullish() && !options.is_object() {
		return vm.throw_error(.type_error, 'UIEventInit must be a dictionary')
	}
	bubbles := text_encoding_member(mut vm, options, 'bubbles')!.to_boolean()
	cancelable := text_encoding_member(mut vm, options, 'cancelable')!.to_boolean()
	composed := text_encoding_member(mut vm, options, 'composed')!.to_boolean()
	detail := text_encoding_member(mut vm, options, 'detail')!.to_i32(mut vm)!
	view := host.ui_event_view_argument(mut vm, text_encoding_member(mut vm, options, 'view')!)!
	return dom.UIEventInit{ EventInit: dom.EventInit{ bubbles: bubbles, cancelable: cancelable, composed: composed }, detail: int(detail), view: view }
}

fn (host &Host) event_modifier_dictionary(mut vm libjs.VM, options libjs.Value) !dom.EventModifierInit {
	ui := host.ui_event_dictionary(mut vm, options)!
	mut modifiers := dom.EventModifierInit{ UIEventInit: ui }
	// WebIDL's inherited dictionaries are converted in member-name order.
	for name in ['altKey', 'ctrlKey', 'metaKey', 'modifierAltGraph', 'modifierCapsLock', 'modifierFn',
		'modifierFnLock', 'modifierHyper', 'modifierNumLock', 'modifierScrollLock', 'modifierSuper',
		'modifierSymbol', 'modifierSymbolLock', 'shiftKey'] {
		value := text_encoding_member(mut vm, options, name)!.to_boolean()
		match name {
			'altKey' { modifiers.alt_key = value }
			'ctrlKey' { modifiers.ctrl_key = value }
			'metaKey' { modifiers.meta_key = value }
			'modifierAltGraph' { modifiers.modifier_alt_graph = value }
			'modifierCapsLock' { modifiers.modifier_caps_lock = value }
			'modifierFn' { modifiers.modifier_fn = value }
			'modifierFnLock' { modifiers.modifier_fn_lock = value }
			'modifierHyper' { modifiers.modifier_hyper = value }
			'modifierNumLock' { modifiers.modifier_num_lock = value }
			'modifierScrollLock' { modifiers.modifier_scroll_lock = value }
			'modifierSuper' { modifiers.modifier_super = value }
			'modifierSymbol' { modifiers.modifier_symbol = value }
			'modifierSymbolLock' { modifiers.modifier_symbol_lock = value }
			else { modifiers.shift_key = value }
		}
	}
	return modifiers
}

fn (mut host Host) register_event_interface(mut prototype libjs.Object, name string, parent string,
	construct fn (mut libjs.VM, &libjs.Object) !&libjs.Object) ! {
	mut vm := host.vm
	host.closures << voidptr(construct)
	mut global := host.realm.global_object_record()
	parent_constructor := global.get(mut vm, libjs.PropertyName.from_str(parent))!
	call := fn [name] (mut vm libjs.VM) !libjs.Value {
		return vm.throw_error(.type_error, name + ' requires new')
	}
	host.closures << voidptr(call)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, parent_constructor.as_object(),
		call, construct, 1, libjs.PropertyName.from_str(name)).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str(name)), libjs.attribute_configurable)
	global.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
}

fn (mut host Host) install_ui_events() ! {
	mut prototype := libjs.Object.create(host.realm, host.event_prototype)
	host.ui_event_prototype = prototype
	host.register_event_interface(mut prototype, 'UIEvent', 'Event', fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		if vm.argument_count() < 1 { return vm.throw_error(.type_error, 'UIEvent requires a type') }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		init := host.ui_event_dictionary(mut vm, vm.argument(1))!
		native := dom.UIEvent.construct_impl(type_, init)!
		mut object := libjs.Object.create(host.realm, if parent.is_object() {
			parent.as_object()
		} else {
			host.ui_event_prototype
		})
		mut owner := unsafe { &Host(host) }
		return owner.register_event_wrapper(mut object, unsafe { &dom.Event(native) }).as_object()
	})!
	for name in ['view', 'detail', 'which'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.ui_event_receiver(mut vm)!
			if name == 'detail' { return libjs.Value.from_f64(f64(native.detail())) }
			if name == 'which' {
				event := unsafe { &dom.Event(native) }
				which := if event.interface_ == .keyboard_event {
					unsafe { &dom.KeyboardEvent(event) }.which()
				} else if libjsdom_is_mouse_event(event) {
					unsafe { &dom.MouseEvent(event) }.which()
				} else {
					native.which()
				}
				return libjs.Value.from_f64(f64(which))
			}
			view := native.view()
			if view == unsafe { nil } { return libjs.js_null() }
			if proxy := host.document.default_view() {
				if view == voidptr(proxy) {
					return libjs.Value.from_object(host.realm.global_object_record())
				}
			}
			if window := host.document.get_window() {
				if view == voidptr(window) {
					return libjs.Value.from_object(host.realm.global_object_record())
				}
			}
			return vm.throw_error(.type_error, 'UIEvent view has no owning Window wrapper')
		}, unsafe { nil })
	}
	host.method_attributes(mut prototype, 'initUIEvent', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut native := host.ui_event_receiver(mut vm)!
		if vm.argument_count() == 0 {
			return vm.throw_error(.type_error, 'initUIEvent requires a type')
		}
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		bubbles, cancelable := vm.argument(1).to_boolean(), vm.argument(2).to_boolean()
		view := host.ui_event_view_argument(mut vm, vm.argument(3))!
		detail := vm.argument(4).to_i32(mut vm)!
		native.init_ui_event(type_, bubbles, cancelable, view, int(detail))
		return libjs.js_undefined()
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
}
