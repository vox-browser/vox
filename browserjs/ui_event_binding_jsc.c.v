// UIEvents/UIEvent.{idl,h,cpp}; subtype data stays on the actual native event.
module browserjs

import dom
import html
import highresolutiontime
import webidl


fn native_event_is_ui_event(event &dom.Event) bool {
	return event.interface_ in [.ui_event, .mouse_event, .pointer_event, .keyboard_event,
		.composition_event, .focus_event, .input_event, .text_event, .wheel_event, .drag_event]
}

fn (mut runtime Runtime) install_ui_event_binding() ! {
	owner := voidptr(&runtime)
	construct := runtime.make_native_value_host_function('UIEvent', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.ui_event_binding_call('construct', receiver, args)
	})!
	mut functions := [construct]
	for name in ['view', 'detail', 'which'] {
		functions << runtime.make_native_value_host_function('get ${name}', 0, fn [owner, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.ui_event_binding_call('get', receiver, [
				runtime.binding_string(name),
			])
		})!
	}
	functions << runtime.make_native_value_host_function('initUIEvent', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.ui_event_binding_call('init', receiver, args)
	})!
	factory := runtime.evaluate_host_value(ui_event_bootstrap())!
	defer { runtime.release_javascript_value(factory) }
	mut binding := runtime.event_binding()!
	mut call_arguments := [binding.event_constructor, C.JSContextGetGlobalObject(runtime.context)]
	call_arguments << functions
	binding.ui_event_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), call_arguments)!)!
	binding.ui_event_constructor = runtime.retain_javascript_value(runtime.binding_property(binding.ui_event_prototype,
		'constructor')!)!
}

fn (runtime &Runtime) ui_event_owning_window() !&html.WindowModel {
	settings := runtime.scripting_settings_ or {
		return runtime.event_binding_type_error('UIEvent view requires an owning Window')
	}

	target := settings.global_object()
	if target.data.kind == .window {
		for window in html.all_windows() {
			if voidptr(window) == voidptr(target) { return window }
		}
	}
	return runtime.event_binding_type_error('UIEvent view requires an owning Window')
}

fn (runtime &Runtime) ui_event_native_view(value voidptr) !voidptr {
	if C.JSValueIsUndefined(runtime.context, value) || C.JSValueIsNull(runtime.context, value) {
		return unsafe { nil }
	}
	// The compact browser has one actual global wrapper per Runtime. Foreign
	// WindowProxy wrappers need their own cross-realm binding before acceptance.
	if value != C.JSContextGetGlobalObject(runtime.context) {
		return runtime.event_binding_type_error('UIEvent view is not the owning WindowProxy')
	}
	window := runtime.ui_event_owning_window()!
	return voidptr(window.window().dom_proxy())
}

fn (runtime &Runtime) ui_event_javascript_view(view voidptr) !voidptr {
	if view == unsafe { nil } { return C.vox_jsc_JSValueMakeNull(runtime.context) }
	window := runtime.ui_event_owning_window()!
	if view == voidptr(window.window().dom_proxy()) || view == voidptr(window) {
		return C.JSContextGetGlobalObject(runtime.context)
	}
	return runtime.event_binding_type_error('UIEvent view has no owning WindowProxy wrapper')
}

fn (mut runtime Runtime) ui_event_long(value voidptr) !int {
	return int(webidl.convert_to_int(runtime.webidl_value(value)!, 32, true, .no, .no)!)
}

fn (runtime &Runtime) ui_event_dictionary_member(value voidptr, name string) !voidptr {
	if C.JSValueIsUndefined(runtime.context, value) || C.JSValueIsNull(runtime.context, value) {
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	if !C.JSValueIsObject(runtime.context, value) {
		return runtime.event_binding_type_error('UIEvent options must be a dictionary')
	}
	return runtime.binding_property(value, name)
}

fn native_ui_event_which(event &dom.Event) u32 {
	// UIEvent::which is virtual upstream. Struct embedding needs the concrete
	// override selected here, including the MouseEvent override inherited by
	// PointerEvent, WheelEvent and HTML::DragEvent.
	if event.interface_ == .keyboard_event {
		return unsafe { &dom.KeyboardEvent(event) }.which()
	}
	if event.interface_ in [.mouse_event, .pointer_event, .wheel_event, .drag_event] {
		return unsafe { &dom.MouseEvent(event) }.which()
	}
	return unsafe { &dom.UIEvent(event) }.which()
}

fn (runtime &Runtime) ui_event_argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.vox_jsc_JSValueMakeUndefined(runtime.context)
}

fn (mut runtime Runtime) ui_event_binding_call(method string, receiver voidptr, args []voidptr) !voidptr {
	context := runtime.context
	if method == 'construct' {
		if args.len < 2 {
			return runtime.event_binding_type_error('Missing internal UIEvent constructor arguments')
		}
		type_ := runtime.binding_dom_string(args[0])!
		// Convert inherited dictionaries before this dictionary's members, each
		// in lexicographic order. Author getters and coercions run exactly once.
		bubbles := runtime.event_binding_bool_property(args[1], 'bubbles', false)!
		cancelable := runtime.event_binding_bool_property(args[1], 'cancelable', false)!
		composed := runtime.event_binding_bool_property(args[1], 'composed', false)!
		detail_value := runtime.ui_event_dictionary_member(args[1], 'detail')!
		detail := if C.JSValueIsUndefined(context, detail_value) {
			0
		} else {
			runtime.ui_event_long(detail_value)!
		}
		view := runtime.ui_event_native_view(runtime.ui_event_dictionary_member(args[1], 'view')!)!
		mut event := dom.UIEvent.construct_impl(type_, dom.UIEventInit{
			EventInit: dom.EventInit{
				bubbles:    bubbles
				cancelable: cancelable
				composed:   composed
			}
			detail:    detail
			view:      view
		})!
		if settings := runtime.scripting_settings_ {
			event.set_time_stamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
				time_origin:                      settings.time_origin()
				cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
			}))
		}
		runtime.bind_event(receiver, unsafe { &dom.Event(event) })!
		return C.vox_jsc_JSValueMakeUndefined(context)
	}
	// A genuine Event wrapper is insufficient: this receiver must own a UIEvent
	// record. Check before reading/coercing operation arguments or Proxy fields.
	event := runtime.native_event(receiver)!
	if !native_event_is_ui_event(event) {
		return runtime.event_binding_type_error('Illegal UIEvent receiver')
	}
	mut ui := unsafe { &dom.UIEvent(event) }
	if method == 'get' {
		if args.len < 1 {
			return runtime.event_binding_type_error('Missing internal UIEvent attribute')
		}
		return match runtime.binding_dom_string(args[0])! {
			'view' { runtime.ui_event_javascript_view(ui.view())! }
			'detail' { C.vox_jsc_JSValueMakeNumber(context, ui.detail()) }
			'which' { C.vox_jsc_JSValueMakeNumber(context, native_ui_event_which(event)) }
			else { return runtime.event_binding_type_error('Unknown UIEvent attribute') }
		}
	}
	if method == 'init' {
		if args.len < 1 {
			return runtime.event_binding_type_error('initUIEvent requires one argument')
		}
		type_ := runtime.binding_dom_string(args[0])!
		bubbles := C.JSValueToBoolean(context, runtime.ui_event_argument(args, 1))
		cancelable := C.JSValueToBoolean(context, runtime.ui_event_argument(args, 2))
		view := runtime.ui_event_native_view(runtime.ui_event_argument(args, 3))!
		detail := runtime.ui_event_long(runtime.ui_event_argument(args, 4))!
		ui.init_ui_event(type_, bubbles, cancelable, view, detail)
		return C.vox_jsc_JSValueMakeUndefined(context)
	}
	return runtime.event_binding_type_error('Unknown UIEvent operation')
}
