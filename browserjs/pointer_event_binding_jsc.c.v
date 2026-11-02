// UIEvents/PointerEvent.{idl,h,cpp}; data and sequence ownership stay DOM-owned.
module browserjs

import dom
import highresolutiontime
import math
import webidl


fn (mut runtime Runtime) install_pointer_event_binding() ! {
	owner := voidptr(&runtime)
	mut binding := runtime.event_binding()!
	if binding.pointer_event_prototype != unsafe { nil } { return }
	settings := runtime.scripting_settings_ or {
		return runtime.event_binding_type_error('PointerEvent requires an owning Window')
	}

	construct := runtime.make_native_value_host_function('PointerEvent', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.pointer_event_binding_call('construct', receiver, args)
	})!
	brand := runtime.make_native_value_host_function('PointerEvent sequence item', 1, fn [owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len < 1 {
			return runtime.event_binding_type_error('Missing PointerEvent sequence item')
		}
		runtime.native_pointer_event(args[0])!
		return args[0]
	})!
	mut functions := [construct, brand]
	for name in ['pointerId', 'width', 'height', 'pressure', 'tangentialPressure', 'tiltX', 'tiltY',
		'twist', 'altitudeAngle', 'azimuthAngle', 'pointerType', 'isPrimary', 'persistentDeviceId'] {
		functions << runtime.make_native_value_host_function('get ${name}', 0, fn [owner, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.pointer_event_binding_call('get', receiver, [
				runtime.binding_string(name),
			])
		})!
	}
	for name in ['getCoalescedEvents', 'getPredictedEvents'] {
		functions << runtime.make_native_value_host_function(name, 0, fn [owner, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.pointer_event_binding_call(name, receiver, [])
		})!
	}
	factory := runtime.evaluate_host_value(pointer_event_bootstrap())!
	defer { runtime.release_javascript_value(factory) }
	mut call_arguments := [binding.mouse_event_constructor, C.JSContextGetGlobalObject(runtime.context),
		C.vox_jsc_JSValueMakeBoolean(runtime.context, settings.is_secure_context())]
	call_arguments << functions
	values := runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), call_arguments)!)!
	defer { runtime.release_javascript_value(values) }
	binding.pointer_event_prototype =
		runtime.retain_javascript_value(runtime.binding_property(values, '0')!)!
	binding.pointer_event_sequence_converter =
		runtime.retain_javascript_value(runtime.binding_property(values, '1')!)!
}

fn (runtime &Runtime) native_pointer_event(value voidptr) !&dom.PointerEvent {
	event := runtime.native_event(value)!
	if event.interface_ != .pointer_event {
		return runtime.event_binding_type_error('Illegal PointerEvent receiver')
	}
	return unsafe { &dom.PointerEvent(event) }
}

fn (mut runtime Runtime) pointer_event_number(value voidptr, name string) !f64 {
	number := webidl.value_to_number(runtime.webidl_value(value)!)!
	if math.is_nan(number) || math.is_inf(number, 0) {
		return runtime.event_binding_type_error('PointerEvent ${name} must be finite')
	}
	return number
}

fn (mut runtime Runtime) pointer_event_float(value voidptr, name string) !f32 {
	number := f32(runtime.pointer_event_number(value, name)!)
	if math.is_nan(f64(number)) || math.is_inf(f64(number), 0) {
		return runtime.event_binding_type_error('PointerEvent ${name} must fit a finite float')
	}
	return number
}

fn (mut runtime Runtime) pointer_event_sequence(value voidptr) ![]&dom.PointerEvent {
	if C.JSValueIsUndefined(runtime.context, value) { return []&dom.PointerEvent{} }
	binding := runtime.event_binding()!
	array := runtime.retain_javascript_value(runtime.call_javascript_function(binding.pointer_event_sequence_converter,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [value])!)!
	defer { runtime.release_javascript_value(array) }
	length := int(C.vox_jsc_JSValueToNumber(runtime.context, runtime.binding_property(array, 'length')!,
		unsafe { nil }))
	mut events := []&dom.PointerEvent{cap: length}
	for index in 0 .. length {
		events << runtime.native_pointer_event(runtime.binding_property(array, index.str())!)!
	}
	return events
}

fn (mut runtime Runtime) pointer_event_dictionary(dictionary voidptr) !dom.PointerEventInit {
	mut init := dom.PointerEventInit{
		MouseEventInit: runtime.mouse_event_dictionary(dictionary)!
	}
	// Own dictionary members follow the inherited 28 MouseEvent members.
	altitude := runtime.ui_event_dictionary_member(dictionary, 'altitudeAngle')!
	if !C.JSValueIsUndefined(runtime.context, altitude) {
		init.altitude_angle = runtime.pointer_event_number(altitude, 'altitudeAngle')!
	}
	azimuth := runtime.ui_event_dictionary_member(dictionary, 'azimuthAngle')!
	if !C.JSValueIsUndefined(runtime.context, azimuth) {
		init.azimuth_angle = runtime.pointer_event_number(azimuth, 'azimuthAngle')!
	}
	init.coalesced_events = runtime.pointer_event_sequence(runtime.ui_event_dictionary_member(dictionary,
		'coalescedEvents')!)!
	height := runtime.ui_event_dictionary_member(dictionary, 'height')!
	if !C.JSValueIsUndefined(runtime.context, height) {
		init.height = runtime.pointer_event_number(height, 'height')!
	}
	init.is_primary = runtime.event_binding_bool_property(dictionary, 'isPrimary', false)!
	device := runtime.ui_event_dictionary_member(dictionary, 'persistentDeviceId')!
	if !C.JSValueIsUndefined(runtime.context, device) {
		init.persistent_device_id = runtime.ui_event_long(device)!
	}
	id := runtime.ui_event_dictionary_member(dictionary, 'pointerId')!
	if !C.JSValueIsUndefined(runtime.context, id) { init.pointer_id = runtime.ui_event_long(id)! }
	type_ := runtime.ui_event_dictionary_member(dictionary, 'pointerType')!
	if !C.JSValueIsUndefined(runtime.context, type_) {
		init.pointer_type = runtime.binding_dom_string(type_)!
	}
	init.predicted_events = runtime.pointer_event_sequence(runtime.ui_event_dictionary_member(dictionary,
		'predictedEvents')!)!
	pressure := runtime.ui_event_dictionary_member(dictionary, 'pressure')!
	if !C.JSValueIsUndefined(runtime.context, pressure) {
		init.pressure = runtime.pointer_event_float(pressure, 'pressure')!
	}
	tangential := runtime.ui_event_dictionary_member(dictionary, 'tangentialPressure')!
	if !C.JSValueIsUndefined(runtime.context, tangential) {
		init.tangential_pressure = runtime.pointer_event_float(tangential, 'tangentialPressure')!
	}
	tilt_x := runtime.ui_event_dictionary_member(dictionary, 'tiltX')!
	if !C.JSValueIsUndefined(runtime.context, tilt_x) {
		init.tilt_x = runtime.ui_event_long(tilt_x)!
	}
	tilt_y := runtime.ui_event_dictionary_member(dictionary, 'tiltY')!
	if !C.JSValueIsUndefined(runtime.context, tilt_y) {
		init.tilt_y = runtime.ui_event_long(tilt_y)!
	}
	twist := runtime.ui_event_dictionary_member(dictionary, 'twist')!
	if !C.JSValueIsUndefined(runtime.context, twist) { init.twist = runtime.ui_event_long(twist)! }
	width := runtime.ui_event_dictionary_member(dictionary, 'width')!
	if !C.JSValueIsUndefined(runtime.context, width) {
		init.width = runtime.pointer_event_number(width, 'width')!
	}
	return init
}

fn (mut runtime Runtime) pointer_event_binding_call(method string, receiver voidptr, args []voidptr) !voidptr {
	context := runtime.context
	if method == 'construct' {
		if args.len < 2 {
			return runtime.event_binding_type_error('Missing internal PointerEvent constructor arguments')
		}
		type_ := runtime.binding_dom_string(args[0])!
		init := runtime.pointer_event_dictionary(args[1])!
		mut event := dom.PointerEvent.construct_impl(type_, init)!
		if settings := runtime.scripting_settings_ {
			event.set_time_stamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
				time_origin:                      settings.time_origin()
				cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
			}))
		}
		runtime.bind_event(receiver, unsafe { &dom.Event(event) })!
		return C.vox_jsc_JSValueMakeUndefined(context)
	}
	pointer := runtime.native_pointer_event(receiver)!
	if method == 'get' {
		name := runtime.binding_dom_string(args[0])!
		return match name {
			'pointerId' { C.vox_jsc_JSValueMakeNumber(context, pointer.pointer_id()) }
			'width' { C.vox_jsc_JSValueMakeNumber(context, pointer.width()) }
			'height' { C.vox_jsc_JSValueMakeNumber(context, pointer.height()) }
			'pressure' { C.vox_jsc_JSValueMakeNumber(context, pointer.pressure()) }
			'tangentialPressure' { C.vox_jsc_JSValueMakeNumber(context, pointer.tangential_pressure()) }
			'tiltX' { C.vox_jsc_JSValueMakeNumber(context, pointer.tilt_x()) }
			'tiltY' { C.vox_jsc_JSValueMakeNumber(context, pointer.tilt_y()) }
			'twist' { C.vox_jsc_JSValueMakeNumber(context, pointer.twist()) }
			'altitudeAngle' { C.vox_jsc_JSValueMakeNumber(context, pointer.altitude_angle()) }
			'azimuthAngle' { C.vox_jsc_JSValueMakeNumber(context, pointer.azimuth_angle()) }
			'pointerType' { runtime.binding_string(pointer.pointer_type()) }
			'isPrimary' { C.vox_jsc_JSValueMakeBoolean(context, pointer.is_primary()) }
			'persistentDeviceId' { C.vox_jsc_JSValueMakeNumber(context, pointer.persistent_device_id()) }
			else { return runtime.event_binding_type_error('Unknown PointerEvent attribute') }
		}
	}
	if method in ['getCoalescedEvents', 'getPredictedEvents'] {
		events := if method == 'getCoalescedEvents' {
			pointer.get_coalesced_events()
		} else {
			pointer.get_predicted_events()
		}
		mut values := []voidptr{cap: events.len}
		for event in events {
			values << runtime.javascript_event(unsafe { &dom.Event(event) })!
		}
		mut exception := unsafe { nil }
		array := C.vox_jsc_JSObjectMakeArray(context, uint(values.len), values.data, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		return array
	}
	return runtime.event_binding_type_error('Unknown PointerEvent operation')
}
