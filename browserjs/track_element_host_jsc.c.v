// HTML/HTMLTrackElement.idl readonly state over the actual DOM/model owner.
module browserjs

import dom
import html

fn (mut host MediaElementHost) install_track_elements() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	bind := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.bind_track_element(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	mut functions := [bind]
	for name in ['track', 'readyState'] {
		functions << runtime.make_native_value_host_function('get ${name}', 0, fn [handle, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			return host.track_element_value(name, receiver) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
	}
	factory := runtime.evaluate_host_value(r'(function(bind,getTrack,getState){
 const define=Object.defineProperty,prototype=Object.create(EventTarget.prototype),T=TypeError;
 const illegal=()=>{throw new T("Illegal HTMLTrackElement constructor")},constructor=new Proxy(function HTMLTrackElement(){},{apply:illegal,construct:illegal});
 define(constructor,"prototype",{value:prototype,writable:false});define(prototype,"constructor",{value:constructor,writable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"HTMLTrackElement",configurable:true});
 define(prototype,"track",{get:getTrack,enumerable:true,configurable:true});define(prototype,"readyState",{get:getState,enumerable:true,configurable:true});
 for(const [name,value] of [["NONE",0],["LOADING",1],["LOADED",2],["ERROR",3]])for(const object of [constructor,prototype])define(object,name,{value,enumerable:true});
 define(globalThis,"HTMLTrackElement",{value:constructor,writable:true,configurable:true});define(globalThis,"__ladybirdTrackElementBind",{value:bind,configurable:true});return prototype;
})')!
	defer { runtime.release_javascript_value(factory) }
	host.track_element_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.JSValueMakeUndefined(runtime.context), functions)!)!
}

fn (mut host MediaElementHost) bind_track_element(args []voidptr) !voidptr {
	if host.closed || args.len != 2 { return error('TypeError: Invalid track element binding') }
	wrapper := args[0]
	if !C.JSValueIsObject(host.runtime.context, wrapper) { return error('TypeError: Track wrapper is not an object') }
	key := host.runtime.binding_dom_string(args[1])!
	if element := host.runtime.canvas_element_for_binding(key) { host.elements[key] = element }
	if key !in host.elements {
		if !key.starts_with('__created_') { return error('TypeError: Track wrapper has no native element') }
		host.elements[key] = dom.create_element(host.document, 'track', 'http://www.w3.org/1999/xhtml', none, none, false)!
	}
	element := host.elements[key] or { return error('TypeError: Missing native track element') }
	if !element.is_html_element() || element.local_name() != 'track' {
		return error('TypeError: Not an object of type HTMLTrackElement')
	}
	// EventTarget identity is shared with the compact Element facade. Binding
	// the same wrapper again is harmless; another owner/wrapper must reject.
	binding := host.runtime.event_binding()!
	if existing := binding.targets[wrapper] {
		if voidptr(existing) != voidptr(element) { return error('TypeError: Track wrapper already owns another native target') }
	}
	host.runtime.bind_event_target(wrapper, unsafe { &dom.EventTarget(element) })!
	host.track_elements[wrapper] = unsafe { &dom.HTMLTrackElement(element) }
	C.JSObjectSetPrototype(host.runtime.context, wrapper, host.track_element_prototype)
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) track_element_value(name string, receiver voidptr) !voidptr {
	if host.closed { return error('TypeError: Track element binding is closed') }
	element := host.track_elements[receiver] or { return error('TypeError: Not an object of type HTMLTrackElement') }
	// Branding precedes compact replay, which can run author callbacks. The
	// cached DOM owner remains authoritative across movement or adoption.
	if replay := host.replay { replay(host.runtime)! }
	model := html.html_track_element_model_for_dom_element(element)
	if name == 'readyState' { return C.JSValueMakeNumber(host.runtime.context, int(model.ready_state())) }
	return host.wrap_text_track(model.track)
}

fn (host &MediaElementHost) track_element_text_track(target &dom.EventTarget) ?&html.TextTrack {
	for _, element in host.track_elements {
		// An unknown EventTarget lookup must not initialize unrelated lazy models.
		if element.track_element_model_ == unsafe { nil } { continue }
		model := unsafe { &html.HTMLTrackElementModel(element.track_element_model_) }
		if voidptr(target) == voidptr(&model.track.EventTarget) { return model.track }
	}
	return none
}
