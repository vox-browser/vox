// UIEvents/WheelEvent.{idl,h,cpp}; coordinates and legacy deltas stay DOM-owned.
module browserjs

import dom
import highresolutiontime
import math
import webidl


fn (mut runtime Runtime) install_wheel_event_binding() ! {
	owner := voidptr(&runtime)
	mut binding := runtime.event_binding()!
	if binding.wheel_event_prototype != unsafe { nil } { return }
	construct := runtime.make_native_value_host_function('WheelEvent', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.wheel_event_binding_call('construct', receiver, args)
	})!
	mut functions := [construct]
	for name in ['deltaX', 'deltaY', 'deltaZ', 'deltaMode', 'wheelDeltaX', 'wheelDeltaY',
		'wheelDelta'] {
		functions << runtime.make_native_value_host_function('get ${name}', 0, fn [owner, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.wheel_event_binding_call('get', receiver, [
				runtime.binding_string(name),
			])
		})!
	}
	factory := runtime.evaluate_host_value(wheel_event_bootstrap())!
	defer { runtime.release_javascript_value(factory) }
	mut call_arguments := [binding.mouse_event_constructor, C.JSContextGetGlobalObject(runtime.context)]
	call_arguments << functions
	binding.wheel_event_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.JSValueMakeUndefined(runtime.context), call_arguments)!)!
}

fn (mut runtime Runtime) wheel_event_double_member(dictionary voidptr, name string) !f64 {
	value := runtime.ui_event_dictionary_member(dictionary, name)!
	if C.JSValueIsUndefined(runtime.context, value) { return 0 }
	number := webidl.value_to_number(runtime.webidl_value(value)!)!
	if math.is_nan(number) || math.is_inf(number, 0) {
		return runtime.event_binding_type_error('WheelEvent ${name} must be finite')
	}
	return number
}

fn (mut runtime Runtime) wheel_event_dictionary(dictionary voidptr) !dom.WheelEventInit {
	mut init := dom.WheelEventInit{
		MouseEventInit: runtime.mouse_event_dictionary(dictionary)!
	}
	// Generated dictionaries convert each inherited member before reading the
	// next member, then visit these six own members in lexical order.
	mode := runtime.ui_event_dictionary_member(dictionary, 'deltaMode')!
	if !C.JSValueIsUndefined(runtime.context, mode) {
		init.delta_mode = u32(webidl.convert_to_int(runtime.webidl_value(mode)!, 32, false, .no, .no)!)
	}
	init.delta_x = runtime.wheel_event_double_member(dictionary, 'deltaX')!
	init.delta_y = runtime.wheel_event_double_member(dictionary, 'deltaY')!
	init.delta_z = runtime.wheel_event_double_member(dictionary, 'deltaZ')!
	x := runtime.ui_event_dictionary_member(dictionary, 'wheelDeltaX')!
	if !C.JSValueIsUndefined(runtime.context, x) { init.wheel_delta_x = runtime.ui_event_long(x)! }
	y := runtime.ui_event_dictionary_member(dictionary, 'wheelDeltaY')!
	if !C.JSValueIsUndefined(runtime.context, y) { init.wheel_delta_y = runtime.ui_event_long(y)! }
	return init
}

fn (mut runtime Runtime) wheel_event_binding_call(method string, receiver voidptr, args []voidptr) !voidptr {
	context := runtime.context
	if method == 'construct' {
		if args.len < 2 {
			return runtime.event_binding_type_error('Missing internal WheelEvent constructor arguments')
		}
		type_ := runtime.binding_dom_string(args[0])!
		init := runtime.wheel_event_dictionary(args[1])!
		mut event := dom.WheelEvent.construct_impl(type_, init)!
		if settings := runtime.scripting_settings_ {
			event.set_time_stamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
				time_origin:                      settings.time_origin()
				cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
			}))
		}
		runtime.bind_event(receiver, unsafe { &dom.Event(event) })!
		return C.JSValueMakeUndefined(context)
	}
	event := runtime.native_event(receiver)!
	if event.interface_ != .wheel_event {
		return runtime.event_binding_type_error('Illegal WheelEvent receiver')
	}
	wheel := unsafe { &dom.WheelEvent(event) }
	if method == 'get' {
		name := runtime.binding_dom_string(args[0])!
		return match name {
			'deltaX' { C.JSValueMakeNumber(context, wheel.delta_x()) }
			'deltaY' { C.JSValueMakeNumber(context, wheel.delta_y()) }
			'deltaZ' { C.JSValueMakeNumber(context, wheel.delta_z()) }
			'deltaMode' { C.JSValueMakeNumber(context, wheel.delta_mode()) }
			'wheelDeltaX' { C.JSValueMakeNumber(context, wheel.wheel_delta_x()) }
			'wheelDeltaY' { C.JSValueMakeNumber(context, wheel.wheel_delta_y()) }
			'wheelDelta' { C.JSValueMakeNumber(context, wheel.wheel_delta()) }
			else { return runtime.event_binding_type_error('Unknown WheelEvent attribute') }
		}
	}
	return runtime.event_binding_type_error('Unknown WheelEvent operation')
}
