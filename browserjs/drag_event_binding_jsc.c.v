// HTML/DragEvent.{idl,h,cpp}; native data ownership and dispatch remain unchanged.
module browserjs

import dom
import html
import highresolutiontime


fn (mut runtime Runtime) install_drag_event_binding() ! {
	owner := voidptr(&runtime)
	mut binding := runtime.event_binding()!
	if binding.drag_event_prototype != unsafe { nil } { return }
	runtime.install_data_transfer_identity()!
	construct := runtime.make_native_value_host_function('DragEvent', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.drag_event_binding_call('construct', receiver, args)
	})!
	get_transfer := runtime.make_native_value_host_function('get dataTransfer', 0, fn [owner] (receiver voidptr, _ []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.drag_event_binding_call('get', receiver, [])
	})!
	factory := runtime.evaluate_host_value(drag_event_bootstrap())!
	defer { runtime.release_javascript_value(factory) }
	binding.drag_event_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [binding.mouse_event_constructor,
		C.JSContextGetGlobalObject(runtime.context), construct, get_transfer])!)!
}

fn (mut runtime Runtime) drag_event_dictionary(dictionary voidptr) !html.DragEventInit {
	init := runtime.mouse_event_dictionary(dictionary)!
	// The generated converter reads its sole own member after the inherited
	// 28 MouseEvent members. Nullable conversion performs no author inspection.
	value := runtime.ui_event_dictionary_member(dictionary, 'dataTransfer')!
	mut transfer := ?&html.DataTransfer(none)
	if !C.JSValueIsUndefined(runtime.context, value) && !C.JSValueIsNull(runtime.context, value) {
		transfer = runtime.native_data_transfer(value)!
	}
	return html.DragEventInit{
		MouseEventInit: init
		data_transfer:  transfer
	}
}

fn (mut runtime Runtime) drag_event_binding_call(method string, receiver voidptr, args []voidptr) !voidptr {
	if method == 'construct' {
		if args.len < 2 {
			return runtime.event_binding_type_error('Missing internal DragEvent constructor arguments')
		}
		type_ := runtime.binding_dom_string(args[0])!
		init := runtime.drag_event_dictionary(args[1])!
		mut event := html.DragEvent.construct_impl(type_, init)!
		if settings := runtime.scripting_settings_ {
			event.set_time_stamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
				time_origin:                      settings.time_origin()
				cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
			}))
		}
		runtime.bind_event(receiver, unsafe { &dom.Event(event) })!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	event := runtime.native_event(receiver)!
	if event.interface_ != .drag_event {
		return runtime.event_binding_type_error('Illegal DragEvent receiver')
	}
	if method == 'get' {
		drag := unsafe { &html.DragEvent(event) }
		if transfer := drag.data_transfer() { return runtime.javascript_data_transfer(transfer)! }
		return C.vox_jsc_JSValueMakeNull(runtime.context)
	}
	return runtime.event_binding_type_error('Unknown DragEvent operation')
}
