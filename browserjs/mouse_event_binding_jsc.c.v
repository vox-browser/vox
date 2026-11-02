// UIEvents/MouseEvent.{idl,h,cpp}; native state and dispatch stay DOM-owned.
module browserjs

import dom
import highresolutiontime
import math
import webidl


fn native_event_is_mouse_event(event &dom.Event) bool {
	return event.interface_ in [.mouse_event, .pointer_event, .wheel_event, .drag_event]
}

fn (mut runtime Runtime) install_mouse_event_binding() ! {
	owner := voidptr(&runtime)
	mut binding := runtime.event_binding()!
	if binding.mouse_event_prototype != unsafe { nil } { return }
	// Window is itself an EventTarget. Register the actual owning global so
	// nullable relatedTarget conversion and readback preserve its identity.
	window := runtime.ui_event_owning_window()!
	runtime.bind_event_target(C.JSContextGetGlobalObject(runtime.context),
		unsafe { &dom.EventTarget(window) })!
	construct := runtime.make_native_value_host_function('MouseEvent', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.mouse_event_binding_call('construct', receiver, args)
	})!
	mut functions := [construct]
	for name in ['screenX', 'screenY', 'pageX', 'pageY', 'clientX', 'clientY', 'x', 'y', 'offsetX',
		'offsetY', 'ctrlKey', 'shiftKey', 'altKey', 'metaKey', 'movementX', 'movementY', 'button',
		'buttons', 'relatedTarget'] {
		functions << runtime.make_native_value_host_function('get ${name}', 0, fn [owner, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.mouse_event_binding_call('get', receiver, [
				runtime.binding_string(name),
			])
		})!
	}
	for name in ['getModifierState', 'initMouseEvent'] {
		functions << runtime.make_native_value_host_function(name, 1, fn [owner, name] (receiver voidptr, args []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.mouse_event_binding_call(name, receiver, args)
		})!
	}
	factory := runtime.evaluate_host_value(mouse_event_bootstrap())!
	defer { runtime.release_javascript_value(factory) }
	mut call_arguments := [binding.ui_event_constructor, C.JSContextGetGlobalObject(runtime.context)]
	call_arguments << functions
	binding.mouse_event_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), call_arguments)!)!
	binding.mouse_event_constructor = runtime.retain_javascript_value(runtime.binding_property(binding.mouse_event_prototype,
		'constructor')!)!
}

fn (runtime &Runtime) mouse_event_native_related_target(value voidptr) !&dom.EventTarget {
	if C.JSValueIsUndefined(runtime.context, value) || C.JSValueIsNull(runtime.context, value) {
		return unsafe { nil }
	}
	return runtime.native_event_target(value)!
}

fn (mut runtime Runtime) mouse_event_double_member(dictionary voidptr, name string) !f64 {
	value := runtime.ui_event_dictionary_member(dictionary, name)!
	if C.JSValueIsUndefined(runtime.context, value) { return 0 }
	number := webidl.value_to_number(runtime.webidl_value(value)!)!
	if math.is_nan(number) || math.is_inf(number, 0) {
		return runtime.event_binding_type_error('MouseEvent ${name} must be finite')
	}
	return number
}

fn (mut runtime Runtime) mouse_event_short(value voidptr, signed bool) !f64 {
	return webidl.convert_to_int(runtime.webidl_value(value)!, 16, signed, .no, .no)
}

fn (mut runtime Runtime) mouse_event_dictionary(dictionary voidptr) !dom.MouseEventInit {
	mut init := dom.MouseEventInit{}
	// Generated WebIDL conversion visits each inherited dictionary in lexical
	// member order, converting each value before reading the next property.
	init.bubbles = runtime.event_binding_bool_property(dictionary, 'bubbles', false)!
	init.cancelable = runtime.event_binding_bool_property(dictionary, 'cancelable', false)!
	init.composed = runtime.event_binding_bool_property(dictionary, 'composed', false)!
	value := runtime.ui_event_dictionary_member(dictionary, 'detail')!
	if !C.JSValueIsUndefined(runtime.context, value) { init.detail = runtime.ui_event_long(value)! }
	init.view =
		runtime.ui_event_native_view(runtime.ui_event_dictionary_member(dictionary, 'view')!)!
	init.alt_key = runtime.event_binding_bool_property(dictionary, 'altKey', false)!
	init.ctrl_key = runtime.event_binding_bool_property(dictionary, 'ctrlKey', false)!
	init.meta_key = runtime.event_binding_bool_property(dictionary, 'metaKey', false)!
	init.modifier_alt_graph = runtime.event_binding_bool_property(dictionary, 'modifierAltGraph',
		false)!
	init.modifier_caps_lock = runtime.event_binding_bool_property(dictionary, 'modifierCapsLock',
		false)!
	init.modifier_fn = runtime.event_binding_bool_property(dictionary, 'modifierFn', false)!
	init.modifier_fn_lock =
		runtime.event_binding_bool_property(dictionary, 'modifierFnLock', false)!
	init.modifier_hyper = runtime.event_binding_bool_property(dictionary, 'modifierHyper', false)!
	init.modifier_num_lock = runtime.event_binding_bool_property(dictionary, 'modifierNumLock',
		false)!
	init.modifier_scroll_lock = runtime.event_binding_bool_property(dictionary,
		'modifierScrollLock', false)!
	init.modifier_super = runtime.event_binding_bool_property(dictionary, 'modifierSuper', false)!
	init.modifier_symbol = runtime.event_binding_bool_property(dictionary, 'modifierSymbol', false)!
	init.modifier_symbol_lock = runtime.event_binding_bool_property(dictionary,
		'modifierSymbolLock', false)!
	init.shift_key = runtime.event_binding_bool_property(dictionary, 'shiftKey', false)!
	init.button = i16(runtime.mouse_event_short(runtime.ui_event_dictionary_member(dictionary,
		'button')!, true)!)
	init.buttons = u16(runtime.mouse_event_short(runtime.ui_event_dictionary_member(dictionary,
		'buttons')!, false)!)
	init.client_x = runtime.mouse_event_double_member(dictionary, 'clientX')!
	init.client_y = runtime.mouse_event_double_member(dictionary, 'clientY')!
	init.movement_x = runtime.mouse_event_double_member(dictionary, 'movementX')!
	init.movement_y = runtime.mouse_event_double_member(dictionary, 'movementY')!
	related := runtime.mouse_event_native_related_target(runtime.ui_event_dictionary_member(dictionary,
		'relatedTarget')!)!
	if related != unsafe { nil } { init.related_target = related }
	init.screen_x = runtime.mouse_event_double_member(dictionary, 'screenX')!
	init.screen_y = runtime.mouse_event_double_member(dictionary, 'screenY')!
	return init
}

fn native_mouse_event_coordinate(event &dom.Event, name string) f64 {
	// x/y call virtual client coordinates upstream. Struct embedding requires
	// explicit PointerEvent dispatch, including its type-dependent flooring.
	if event.interface_ == .pointer_event {
		pointer := unsafe { &dom.PointerEvent(event) }
		return match name {
			'screenX' { pointer.screen_x() }
			'screenY' { pointer.screen_y() }
			'pageX' { pointer.page_x() }
			'pageY' { pointer.page_y() }
			'clientX', 'x' { pointer.client_x() }
			'clientY', 'y' { pointer.client_y() }
			'offsetX' { pointer.offset_x() }
			else { pointer.offset_y() }
		}
	}
	mouse := unsafe { &dom.MouseEvent(event) }
	return match name {
		'screenX' { mouse.screen_x() }
		'screenY' { mouse.screen_y() }
		'pageX' { mouse.page_x() }
		'pageY' { mouse.page_y() }
		'clientX', 'x' { mouse.client_x() }
		'clientY', 'y' { mouse.client_y() }
		'offsetX' { mouse.offset_x() }
		else { mouse.offset_y() }
	}
}

fn (mut runtime Runtime) mouse_event_binding_call(method string, receiver voidptr, args []voidptr) !voidptr {
	context := runtime.context
	if method == 'construct' {
		if args.len < 2 {
			return runtime.event_binding_type_error('Missing internal MouseEvent constructor arguments')
		}
		type_ := runtime.binding_dom_string(args[0])!
		init := runtime.mouse_event_dictionary(args[1])!
		mut event := dom.MouseEvent.construct_impl(type_, init)!
		if settings := runtime.scripting_settings_ {
			event.set_time_stamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
				time_origin:                      settings.time_origin()
				cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
			}))
		}
		runtime.bind_event(receiver, unsafe { &dom.Event(event) })!
		return C.vox_jsc_JSValueMakeUndefined(context)
	}
	event := runtime.native_event(receiver)!
	if !native_event_is_mouse_event(event) {
		return runtime.event_binding_type_error('Illegal MouseEvent receiver')
	}
	mut mouse := unsafe { &dom.MouseEvent(event) }
	if method == 'get' {
		if args.len < 1 {
			return runtime.event_binding_type_error('Missing internal MouseEvent attribute')
		}
		name := runtime.binding_dom_string(args[0])!
		if name in ['screenX', 'screenY', 'pageX', 'pageY', 'clientX', 'clientY', 'x', 'y', 'offsetX',
			'offsetY'] {
			return C.vox_jsc_JSValueMakeNumber(context, native_mouse_event_coordinate(event, name))
		}
		return match name {
			'ctrlKey' {
				C.vox_jsc_JSValueMakeBoolean(context, mouse.ctrl_key())
			}
			'shiftKey' {
				C.vox_jsc_JSValueMakeBoolean(context, mouse.shift_key())
			}
			'altKey' {
				C.vox_jsc_JSValueMakeBoolean(context, mouse.alt_key())
			}
			'metaKey' {
				C.vox_jsc_JSValueMakeBoolean(context, mouse.meta_key())
			}
			'movementX' {
				C.vox_jsc_JSValueMakeNumber(context, mouse.movement_x())
			}
			'movementY' {
				C.vox_jsc_JSValueMakeNumber(context, mouse.movement_y())
			}
			'button' {
				C.vox_jsc_JSValueMakeNumber(context, mouse.button())
			}
			'buttons' {
				C.vox_jsc_JSValueMakeNumber(context, mouse.buttons())
			}
			'relatedTarget' {
				if related := mouse.related_target() {
					return runtime.javascript_event_target(related, none)!
				}
				return C.vox_jsc_JSValueMakeNull(context)
			}
			else {
				return runtime.event_binding_type_error('Unknown MouseEvent attribute')
			}
		}
	}
	if method == 'getModifierState' {
		if args.len < 1 {
			return runtime.event_binding_type_error('getModifierState requires one argument')
		}
		key := runtime.binding_dom_string(args[0])!
		return C.vox_jsc_JSValueMakeBoolean(context, mouse.get_modifier_state(key))
	}
	if method == 'initMouseEvent' {
		if args.len < 1 {
			return runtime.event_binding_type_error('initMouseEvent requires one argument')
		}
		type_ := runtime.binding_dom_string(args[0])!
		bubbles := C.JSValueToBoolean(context, runtime.ui_event_argument(args, 1))
		cancelable := C.JSValueToBoolean(context, runtime.ui_event_argument(args, 2))
		view := runtime.ui_event_native_view(runtime.ui_event_argument(args, 3))!
		detail := runtime.ui_event_long(runtime.ui_event_argument(args, 4))!
		screen_x := runtime.ui_event_long(runtime.ui_event_argument(args, 5))!
		screen_y := runtime.ui_event_long(runtime.ui_event_argument(args, 6))!
		client_x := runtime.ui_event_long(runtime.ui_event_argument(args, 7))!
		client_y := runtime.ui_event_long(runtime.ui_event_argument(args, 8))!
		ctrl_key := C.JSValueToBoolean(context, runtime.ui_event_argument(args, 9))
		alt_key := C.JSValueToBoolean(context, runtime.ui_event_argument(args, 10))
		shift_key := C.JSValueToBoolean(context, runtime.ui_event_argument(args, 11))
		meta_key := C.JSValueToBoolean(context, runtime.ui_event_argument(args, 12))
		button := i16(runtime.mouse_event_short(runtime.ui_event_argument(args, 13), true)!)
		related_pointer :=
			runtime.mouse_event_native_related_target(runtime.ui_event_argument(args, 14))!
		mut related := ?&dom.EventTarget(none)
		if related_pointer != unsafe { nil } { related = related_pointer }
		mouse.init_mouse_event(type_, bubbles, cancelable, view, detail, screen_x, screen_y,
			client_x, client_y, ctrl_key, alt_key, shift_key, meta_key, button, related)
		return C.vox_jsc_JSValueMakeUndefined(context)
	}
	return runtime.event_binding_type_error('Unknown MouseEvent operation')
}
