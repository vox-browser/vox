// UIEvents/KeyboardEvent.{idl,h,cpp}; keyboard state stays on the DOM record.
module browserjs

import dom
import highresolutiontime
import webidl

fn (mut runtime Runtime) install_keyboard_event_binding() ! {
	owner := voidptr(&runtime)
	mut binding := runtime.event_binding()!
	if binding.keyboard_event_prototype != unsafe { nil } { return }
	construct := runtime.make_native_value_host_function('KeyboardEvent', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.keyboard_event_binding_call('construct', receiver, args)
	})!
	mut functions := [construct]
	for name in ['key', 'code', 'location', 'ctrlKey', 'shiftKey', 'altKey', 'metaKey', 'repeat',
		'isComposing', 'charCode', 'keyCode'] {
		functions << runtime.make_native_value_host_function('get ${name}', 0, fn [owner, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.keyboard_event_binding_call('get', receiver, [runtime.binding_string(name)])
		})!
	}
	for name in ['getModifierState', 'initKeyboardEvent'] {
		functions << runtime.make_native_value_host_function(name, 1, fn [owner, name] (receiver voidptr, args []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.keyboard_event_binding_call(name, receiver, args)
		})!
	}
	factory := runtime.evaluate_host_value(keyboard_event_bootstrap())!
	defer { runtime.release_javascript_value(factory) }
	mut arguments := [binding.ui_event_constructor, C.JSContextGetGlobalObject(runtime.context)]
	arguments << functions
	binding.keyboard_event_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), arguments)!)!
}

fn (mut runtime Runtime) keyboard_event_unsigned(value voidptr) !u32 {
	return u32(webidl.convert_to_int(runtime.webidl_value(value)!, 32, false, .no, .no)!)
}

fn (mut runtime Runtime) keyboard_event_dictionary(dictionary voidptr) !dom.KeyboardEventInit {
	mut init := dom.KeyboardEventInit{}
	// Generated WebIDL dictionaries convert inherited members first, then
	// visit own members in lexical order, preserving original getter failures.
	init.bubbles = runtime.event_binding_bool_property(dictionary, 'bubbles', false)!
	init.cancelable = runtime.event_binding_bool_property(dictionary, 'cancelable', false)!
	init.composed = runtime.event_binding_bool_property(dictionary, 'composed', false)!
	detail := runtime.ui_event_dictionary_member(dictionary, 'detail')!
	if !C.JSValueIsUndefined(runtime.context, detail) {
		init.detail = runtime.ui_event_long(detail)!
	}
	init.view = runtime.ui_event_native_view(runtime.ui_event_dictionary_member(dictionary, 'view')!)!
	init.alt_key = runtime.event_binding_bool_property(dictionary, 'altKey', false)!
	init.ctrl_key = runtime.event_binding_bool_property(dictionary, 'ctrlKey', false)!
	init.meta_key = runtime.event_binding_bool_property(dictionary, 'metaKey', false)!
	init.modifier_alt_graph = runtime.event_binding_bool_property(dictionary, 'modifierAltGraph', false)!
	init.modifier_caps_lock = runtime.event_binding_bool_property(dictionary, 'modifierCapsLock', false)!
	init.modifier_fn = runtime.event_binding_bool_property(dictionary, 'modifierFn', false)!
	init.modifier_fn_lock = runtime.event_binding_bool_property(dictionary, 'modifierFnLock', false)!
	init.modifier_hyper = runtime.event_binding_bool_property(dictionary, 'modifierHyper', false)!
	init.modifier_num_lock = runtime.event_binding_bool_property(dictionary, 'modifierNumLock', false)!
	init.modifier_scroll_lock = runtime.event_binding_bool_property(dictionary, 'modifierScrollLock', false)!
	init.modifier_super = runtime.event_binding_bool_property(dictionary, 'modifierSuper', false)!
	init.modifier_symbol = runtime.event_binding_bool_property(dictionary, 'modifierSymbol', false)!
	init.modifier_symbol_lock = runtime.event_binding_bool_property(dictionary, 'modifierSymbolLock', false)!
	init.shift_key = runtime.event_binding_bool_property(dictionary, 'shiftKey', false)!
	init.char_code = runtime.keyboard_event_unsigned(runtime.ui_event_dictionary_member(dictionary, 'charCode')!)!
	code := runtime.ui_event_dictionary_member(dictionary, 'code')!
	if !C.JSValueIsUndefined(runtime.context, code) {
		init.code = runtime.binding_dom_string(code)!
	}
	init.is_composing = runtime.event_binding_bool_property(dictionary, 'isComposing', false)!
	key := runtime.ui_event_dictionary_member(dictionary, 'key')!
	if !C.JSValueIsUndefined(runtime.context, key) { init.key = runtime.binding_dom_string(key)! }
	init.key_code = runtime.keyboard_event_unsigned(runtime.ui_event_dictionary_member(dictionary, 'keyCode')!)!
	init.location = runtime.keyboard_event_unsigned(runtime.ui_event_dictionary_member(dictionary, 'location')!)!
	init.repeat = runtime.event_binding_bool_property(dictionary, 'repeat', false)!
	return init
}

fn (mut runtime Runtime) keyboard_event_binding_call(method string, receiver voidptr, args []voidptr) !voidptr {
	context := runtime.context
	if method == 'construct' {
		if args.len < 2 {
			return runtime.event_binding_type_error('Missing internal KeyboardEvent arguments')
		}
		type_ := runtime.binding_dom_string(args[0])!
		init := runtime.keyboard_event_dictionary(args[1])!
		mut event := dom.KeyboardEvent.construct_impl(type_, init)!
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
	if event.interface_ != .keyboard_event {
		return runtime.event_binding_type_error('Illegal KeyboardEvent receiver')
	}
	mut keyboard := unsafe { &dom.KeyboardEvent(event) }
	if method == 'get' {
		name := runtime.binding_dom_string(args[0])!
		return match name {
			'key' { runtime.binding_string(keyboard.key()) }
			'code' { runtime.binding_string(keyboard.code()) }
			'location' { C.vox_jsc_JSValueMakeNumber(context, keyboard.location()) }
			'ctrlKey' { C.vox_jsc_JSValueMakeBoolean(context, keyboard.ctrl_key()) }
			'shiftKey' { C.vox_jsc_JSValueMakeBoolean(context, keyboard.shift_key()) }
			'altKey' { C.vox_jsc_JSValueMakeBoolean(context, keyboard.alt_key()) }
			'metaKey' { C.vox_jsc_JSValueMakeBoolean(context, keyboard.meta_key()) }
			'repeat' { C.vox_jsc_JSValueMakeBoolean(context, keyboard.repeat()) }
			'isComposing' { C.vox_jsc_JSValueMakeBoolean(context, keyboard.is_composing()) }
			'charCode' { C.vox_jsc_JSValueMakeNumber(context, keyboard.char_code()) }
			'keyCode' { C.vox_jsc_JSValueMakeNumber(context, keyboard.key_code()) }
			else { return runtime.event_binding_type_error('Unknown KeyboardEvent attribute') }
		}
	}
	if method == 'getModifierState' {
		if args.len < 1 {
			return runtime.event_binding_type_error('getModifierState requires an argument')
		}
		return C.vox_jsc_JSValueMakeBoolean(context, keyboard.get_modifier_state(runtime.binding_dom_string(args[0])!))
	}
	if method == 'initKeyboardEvent' {
		if args.len < 1 {
			return runtime.event_binding_type_error('initKeyboardEvent requires an argument')
		}
		mut values := args.clone()
		for values.len < 10 { values << C.vox_jsc_JSValueMakeUndefined(context) }
		type_ := runtime.binding_dom_string(values[0])!
		bubbles := C.JSValueToBoolean(context, values[1])
		cancelable := C.JSValueToBoolean(context, values[2])
		view := runtime.ui_event_native_view(values[3])!
		key := if C.JSValueIsUndefined(context, values[4]) {
			''
		} else {
			runtime.binding_dom_string(values[4])!
		}
		location := runtime.keyboard_event_unsigned(values[5])!
		keyboard.init_keyboard_event(type_, bubbles, cancelable, view, key, location,
			C.JSValueToBoolean(context, values[6]), C.JSValueToBoolean(context, values[7]),
			C.JSValueToBoolean(context, values[8]), C.JSValueToBoolean(context, values[9]))
		return C.vox_jsc_JSValueMakeUndefined(context)
	}
	return runtime.event_binding_type_error('Unknown KeyboardEvent operation')
}
