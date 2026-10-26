@[has_globals]
module browserjs

import dom
import html
import webidl

@[heap]
struct WindowMessageBinding {
	clone &StructuredCloneBridge
mut:
	prototype      voidptr
	validate_ports voidptr
	data           map[voidptr]voidptr
}

__global window_message_bindings_ = map[voidptr]&WindowMessageBinding{}

pub fn (mut runtime Runtime) install_window_message_binding() ! {
	runtime.install_window_event_handler_binding()!
	runtime.install_message_event_binding()!
}

// MessageEvent is also exposed in worker realms. Its event wrappers and clone
// projection do not require a Window or install Window.postMessage there.
pub fn (mut runtime Runtime) install_message_event_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in window_message_bindings_ { return }
	runtime.install_event_target_binding()!
	settings := runtime.scripting_settings_ or { return error('MessageEvent requires its owning settings') }
	window_messaging := settings.global_object().data.kind == .window
	if window_messaging { runtime.install_window_event_handler_binding()! }
	mut binding := &WindowMessageBinding{ clone: StructuredCloneBridge.create(&runtime)! }
	operation := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.window_message_operation(mut binding, args) or {
			if err is JavaScriptValueException { return err }
			value := webidl.exception_value(err)
			if value.dom_exception_ != none {
				return runtime.actual_javascript_exception(runtime.javascript_dom_exception(value)!)
			}
			if err.msg().starts_with('SyntaxError:') {
				return runtime.actual_javascript_exception(runtime.javascript_dom_exception(webidl.dom_exception_value(webidl.DOMException.create('SyntaxError', err.msg())))!)
			}
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(window_message_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	values := runtime.retain_javascript_value(runtime.call_javascript_function(factory, global, [
		operation,
		global,
		C.JSValueMakeBoolean(runtime.context, window_messaging),
	])!)!
	defer { runtime.release_javascript_value(values) }
	mut exception := unsafe { nil }
	binding.prototype = runtime.retain_javascript_value(C.JSObjectGetPropertyAtIndex(runtime.context, values, 0, &exception))!
	binding.validate_ports = runtime.retain_javascript_value(C.JSObjectGetPropertyAtIndex(runtime.context, values, 1, &exception))!
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.install_event_wrapper_provider(EventWrapperProvider{
		owner:  voidptr(binding)
		create: fn [owner, binding] (event &dom.Event) !voidptr {
			if event.interface_ != .message_event { return unsafe { nil } }
			mut runtime := unsafe { &Runtime(owner) }
			events := runtime.event_binding()!
			return runtime.call_javascript_function(events.factory, C.JSValueMakeUndefined(runtime.context), [
				runtime.binding_string('event'),
				binding.prototype,
			])
		}
	})!
	window_message_bindings_[owner] = binding
	runtime.add_close_handler(fn [owner, mut binding] () {
		binding.data = {}
		window_message_bindings_.delete(owner)
	})
}

fn (runtime &Runtime) message_window(receiver voidptr) !&html.WindowModel {
	target := runtime.native_event_target(receiver)!
	if target.data.kind != .window {
		return runtime.event_binding_type_error('Illegal Window receiver')
	}
	for window in html.all_windows() {
		if voidptr(window) == voidptr(target) { return window }
	}
	return error('Window messaging requires the actual owning Window model')
}

struct WindowMessageSource {
	value ?html.MessageEventSource
}

fn (runtime &Runtime) message_source(value voidptr) !WindowMessageSource {
	if C.JSValueIsNull(runtime.context, value) || C.JSValueIsUndefined(runtime.context, value) {
		return WindowMessageSource{}
	}
	window := runtime.message_window(value)!
	return WindowMessageSource{ value: html.WindowMessageEventSource{ value: window.window().dom_proxy() } }
}

fn (mut runtime Runtime) window_message_operation(mut binding WindowMessageBinding, args []voidptr) !voidptr {
	if args.len < 2 { return error('Missing Window message operation') }
	method := runtime.binding_dom_string(args[0])!
	receiver := args[1]
	if method == 'string' { return runtime.binding_string(runtime.binding_dom_string(args[2])!) }
	if method in ['windowBrand', 'post'] {
		mut window := runtime.message_window(receiver)!
		if method == 'windowBrand' { return C.JSValueMakeUndefined(runtime.context) }
		settings := runtime.scripting_settings_ or { return error('postMessage requires sender settings') }
		origin := runtime.binding_dom_string(args[3])!
		_ = html.window_post_message_target_origin(settings.origin(), origin)!
		if runtime.ui_event_long(args[4])! != 0 {
			return native_clone_unsupported('No native transferable wrapper is bound for these objects')
		}
		mut projection := NativeCloneProjection{ bridge: binding.clone }
		defer { projection.release_roots() }
		message := projection.project(args[2])!
		sender := runtime.message_window(C.JSContextGetGlobalObject(runtime.context))!
		window.post_message(*message, settings.origin(), html.WindowPostMessageOptions{
			target_origin: origin
			source:        sender.window().dom_proxy()
		})!
		return C.JSValueMakeUndefined(runtime.context)
	}
	if method == 'construct' {
		type_ := runtime.binding_dom_string(args[2])!
		dictionary := args[3]
		// Web IDL reads dictionary members in lexicographic order.
		bubbles := runtime.event_binding_bool_property(dictionary, 'bubbles', false)!
		cancelable := runtime.event_binding_bool_property(dictionary, 'cancelable', false)!
		composed := runtime.event_binding_bool_property(dictionary, 'composed', false)!
		data := runtime.ui_event_dictionary_member(dictionary, 'data')!
		actual_data := if C.JSValueIsUndefined(runtime.context, data) {
			C.JSValueMakeNull(runtime.context)
		} else {
			data
		}
		last_value := runtime.ui_event_dictionary_member(dictionary, 'lastEventId')!
		last_id := if C.JSValueIsUndefined(runtime.context, last_value) {
			''
		} else {
			runtime.binding_dom_string(last_value)!
		}
		origin_value := runtime.ui_event_dictionary_member(dictionary, 'origin')!
		origin := if C.JSValueIsUndefined(runtime.context, origin_value) {
			''
		} else {
			runtime.binding_dom_string(origin_value)!
		}
		ports := runtime.ui_event_dictionary_member(dictionary, 'ports')!
		if !C.JSValueIsUndefined(runtime.context, ports) {
			// The event factory validates the real iterable, without fabricating ports.
			runtime.call_javascript_function(binding.validate_ports, C.JSValueMakeUndefined(runtime.context), [ports])!
		}
		source := runtime.message_source(runtime.ui_event_dictionary_member(dictionary, 'source')!)!
		mut event := html.MessageEvent.construct_impl(type_, html.MessageEventInit{
			EventInit:     dom.EventInit{ bubbles: bubbles, cancelable: cancelable, composed: composed }
			data:          runtime.event_callback_result(actual_data)!
			origin:        origin
			last_event_id: last_id
			source:        source.value
		})!
		runtime.bind_event(receiver, unsafe { &dom.Event(event) })!
		binding.data[voidptr(event)] = runtime.retain_javascript_value(actual_data)!
		return C.JSValueMakeUndefined(runtime.context)
	}
	event := runtime.native_event(receiver)!
	if event.interface_ != .message_event {
		return runtime.event_binding_type_error('Illegal MessageEvent receiver')
	}
	mut message := unsafe { &html.MessageEvent(event) }
	match method {
		'eventBrand' { return C.JSValueMakeUndefined(runtime.context) }
		'data' {
			if value := binding.data[voidptr(event)] { return value }
			mut projection := NativeCloneProjection{ bridge: binding.clone }
			defer { projection.release_roots() }
			value := runtime.retain_javascript_value(projection.reconstruct(message.data())!)!
			binding.data[voidptr(event)] = value
			return value
		}
		'origin' { return runtime.binding_string(message.origin()) }
		'lastEventId' { return runtime.binding_string(message.last_event_id()) }
		'source' {
			if source := message.source() {
				if source is html.WindowMessageEventSource {
					window := source.value.window() or { return C.JSValueMakeNull(runtime.context) }
					return runtime.javascript_event_target(unsafe { &dom.EventTarget(window) }, none)
				}
				return error('MessagePort has no native wrapper')
			}
			return C.JSValueMakeNull(runtime.context)
		}
		'ports' {
			if message.ports().len > 0 { return error('MessagePort has no native wrapper') }
			return C.JSObjectMakeArray(runtime.context, 0, unsafe { nil }, unsafe { nil })
		}
		'init' {
			type_ := runtime.binding_dom_string(args[2])!
			origin := runtime.binding_dom_string(args[6])!
			last_id := runtime.binding_dom_string(args[7])!
			source := runtime.message_source(args[8])!
			runtime.call_javascript_function(binding.validate_ports, C.JSValueMakeUndefined(runtime.context), [args[9]])!
			if !event.dispatched() {
				data := runtime.event_callback_result(args[5])!
				message.init_message_event(type_, C.JSValueToBoolean(runtime.context, args[3]), C.JSValueToBoolean(runtime.context, args[4]), data, origin, last_id, source.value, [])
				if previous := binding.data[voidptr(event)] {
					runtime.release_javascript_value(previous)
				}
				binding.data[voidptr(event)] = runtime.retain_javascript_value(args[5])!
			}
		}
		else { return error('Unknown Window messaging operation') }
	}
	return C.JSValueMakeUndefined(runtime.context)
}
