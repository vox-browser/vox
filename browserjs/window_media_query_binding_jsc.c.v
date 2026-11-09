@[has_globals]
module browserjs

import css
import dom
import html
import highresolutiontime

@[heap]
struct WindowMediaQueryBinding {
mut:
	lists           map[voidptr]&css.MediaQueryList
	list_prototype  voidptr
	event_prototype voidptr
}

__global window_media_query_bindings_ = map[voidptr]&WindowMediaQueryBinding{}

pub fn (mut runtime Runtime) install_window_media_query_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in window_media_query_bindings_ { return }
	runtime.install_window_event_handler_binding()!
	mut binding := &WindowMediaQueryBinding{}
	operation := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.window_media_query_operation(mut binding, args) or {
			runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(window_media_query_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	prototypes := runtime.call_javascript_function(factory, global, [operation, global])!
	runtime.retain_javascript_value(prototypes)!
	defer { runtime.release_javascript_value(prototypes) }
	mut exception := unsafe { nil }
	binding.list_prototype = runtime.retain_javascript_value(C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, prototypes, 0, &exception))!
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	binding.event_prototype = runtime.retain_javascript_value(C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, prototypes, 1, &exception))!
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.install_event_wrapper_provider(EventWrapperProvider{
		owner:  voidptr(binding)
		create: fn [owner, binding] (event &dom.Event) !voidptr {
			if event.interface_ != .media_query_list_event { return unsafe { nil } }
			mut runtime := unsafe { &Runtime(owner) }
			events := runtime.event_binding()!
			return runtime.call_javascript_function(events.factory, C.vox_jsc_JSValueMakeUndefined(runtime.context),
				[runtime.binding_string('event'), binding.event_prototype])
		}
	})!
	register_runtime_binding(mut window_media_query_bindings_, owner, binding)
	runtime.add_close_handler(fn [owner, mut binding] () {
		binding.lists = {}
		unregister_runtime_binding(mut window_media_query_bindings_, owner)
	})
}

fn (mut runtime Runtime) window_media_query_operation(mut binding WindowMediaQueryBinding, args []voidptr) !voidptr {
	if args.len < 2 { return runtime.event_binding_type_error('Missing media query receiver') }
	method := runtime.binding_dom_string(args[0])!
	receiver := args[1]
	if method == 'match' {
		target := runtime.native_event_target(receiver)!
		if target.data.kind != .window {
			return runtime.event_binding_type_error('matchMedia requires a Window')
		}
		if args.len < 3 {
			return runtime.event_binding_type_error('matchMedia requires one argument')
		}
		// Validate the Window brand before DOMString conversion can run author code.
		query := runtime.binding_dom_string(args[2])!
		for window in html.all_windows() {
			if voidptr(window) != voidptr(target) { continue }
			list := window.match_media(query)
			wrapper := runtime.javascript_event_target(unsafe { &dom.EventTarget(list) }, binding.list_prototype)!
			binding.lists[wrapper] = list
			return wrapper
		}
		return error('matchMedia requires its actual owning Window model')
	}
	if method == 'constructEvent' {
		if args.len < 4 {
			return runtime.event_binding_type_error('Missing MediaQueryListEvent arguments')
		}
		type_ := runtime.binding_dom_string(args[2])!
		dictionary := args[3]
		bubbles := runtime.event_binding_bool_property(dictionary, 'bubbles', false)!
		cancelable := runtime.event_binding_bool_property(dictionary, 'cancelable', false)!
		composed := runtime.event_binding_bool_property(dictionary, 'composed', false)!
		matches := runtime.event_binding_bool_property(dictionary, 'matches', false)!
		media_value := runtime.ui_event_dictionary_member(dictionary, 'media')!
		media := if C.JSValueIsUndefined(runtime.context, media_value) {
			''
		} else {
			runtime.binding_dom_string(media_value)!
		}
		mut event := css.MediaQueryListEvent.construct_impl(type_, css.MediaQueryListEventInit{
			EventInit: dom.EventInit{ bubbles: bubbles, cancelable: cancelable, composed: composed }
			media:     media
			matches:   matches
		})
		if settings := runtime.scripting_settings_ {
			event.set_time_stamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
				time_origin:                      settings.time_origin()
				cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
			}))
		}
		runtime.bind_event(receiver, event.base_event())!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	if method in ['eventmedia', 'eventmatches'] {
		event := runtime.native_event(receiver)!
		if event.interface_ != .media_query_list_event {
			return runtime.event_binding_type_error('Illegal MediaQueryListEvent receiver')
		}
		query_event := unsafe { &css.MediaQueryListEvent(event) }
		return if method == 'eventmedia' {
			runtime.binding_string(query_event.media())
		} else {
			C.vox_jsc_JSValueMakeBoolean(runtime.context, query_event.matches())
		}
	}
	list := binding.lists[receiver] or { return runtime.event_binding_type_error('Illegal MediaQueryList receiver') }
	match method {
		'media' { return runtime.binding_string(list.media()) }
		'matches' { return C.vox_jsc_JSValueMakeBoolean(runtime.context, list.matches()) }
		'getHandler' {
			return runtime.javascript_event_handler(unsafe { &dom.EventTarget(list) }, 'change')
		}
		'setHandler' {
			if args.len < 3 { return runtime.event_binding_type_error('Missing onchange value') }
			runtime.set_javascript_event_handler(unsafe { &dom.EventTarget(list) }, 'change', args[2])!
		}
		'addListener', 'removeListener' {
			if args.len < 3 {
				return runtime.event_binding_type_error('Missing media query listener')
			}
			return runtime.event_binding_call(if method == 'addListener' { 'add' } else { 'remove' }, receiver,
				[runtime.binding_string('change'), args[2], C.vox_jsc_JSValueMakeUndefined(runtime.context)])
		}
		else { return error('Unknown media query operation') }
	}
	return C.vox_jsc_JSValueMakeUndefined(runtime.context)
}
