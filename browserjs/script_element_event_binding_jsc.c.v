@[has_globals]
module browserjs

import dom
import highresolutiontime
import html

__global script_element_event_bindings_ = map[voidptr]bool{}

pub fn (mut runtime Runtime) install_script_element_event_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if script_element_event_bindings_[owner] { return }
	runtime.install_event_target_binding()!
	runtime.define_value_host_function('__ladybirdScriptElementAsync', fn [owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len == 0 { return runtime.event_binding_type_error('Missing script element') }
		target := runtime.native_event_target(args[0])!
		if target.data.kind != .node {
			return runtime.event_binding_type_error('Illegal HTMLScriptElement receiver')
		}
		element := unsafe { &dom.Node(target) }.as_element() or {
			return runtime.event_binding_type_error('Illegal HTMLScriptElement receiver')
		}
		if !element.is_html_element() || element.local_name() != 'script' {
			return runtime.event_binding_type_error('Illegal HTMLScriptElement receiver')
		}
		script := unsafe { &dom.HTMLScriptElement(element) }
		if args.len > 1 {
			html.set_html_script_element_async(script, C.JSValueToBoolean(runtime.context, args[1]))
		}
		return C.JSValueMakeBoolean(runtime.context, html.html_script_element_async(script))
	})!
	runtime.define_value_host_function('__ladybirdScriptElementHandler', fn [owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len < 3 {
			return runtime.event_binding_type_error('Missing script event handler arguments')
		}
		method := runtime.binding_dom_string(args[0])!
		target := runtime.native_event_target(args[1])!
		if target.data.kind != .node {
			return runtime.event_binding_type_error('Script event handler requires an HTMLElement')
		}
		element := unsafe { &dom.Node(target) }.as_element() or {
			return runtime.event_binding_type_error('Script event handler requires an HTMLElement')
		}
		if !element.is_html_element() {
			return runtime.event_binding_type_error('Script event handler requires an HTMLElement')
		}
		name := runtime.binding_dom_string(args[2])!
		if name !in ['load', 'error'] {
			return runtime.event_binding_type_error('Unknown script event handler')
		}
		if method == 'get' { return runtime.javascript_event_handler(target, name) }
		if method == 'set' && args.len >= 4 {
			runtime.set_javascript_event_handler(target, name, args[3])!
			return C.JSValueMakeUndefined(runtime.context)
		}
		return runtime.event_binding_type_error('Unknown script event handler operation')
	})!
	runtime.evaluate_host(script_element_event_binding_factory())!
	script_element_event_bindings_[owner] = true
	runtime.add_close_handler(fn [owner] () { script_element_event_bindings_.delete(owner) })
}

// HTMLScriptElement::execute_script_block fires load after running an external
// classic/module script, including a classic script that throws an exception.
pub fn (runtime &Runtime) dispatch_external_script_load(element &dom.Element) ! {
	runtime.dispatch_external_script_event(element, 'load')!
}

pub fn (runtime &Runtime) dispatch_external_script_event(element &dom.Element, name string) ! {
	if !element.is_html_element() || element.local_name() != 'script' {
		return error('External script completion requires its actual HTMLScriptElement')
	}
	settings := runtime.scripting_settings_ or { return error('Script completion requires its actual settings owner') }
	if name !in ['load', 'error'] { return error('Invalid external script completion event') }
	event := dom.Event.create(name, dom.EventInit{})
	mut mutable_event := unsafe { &dom.Event(event) }
	mutable_event.set_time_stamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
		time_origin:                      settings.time_origin()
		cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
	}))
	unsafe { &dom.EventTarget(element) }.dispatch_event(event)
}
