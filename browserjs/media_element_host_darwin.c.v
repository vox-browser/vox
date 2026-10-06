module browserjs

import dom
import html

pub fn (mut host MediaElementHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	runtime.install_event_target_binding()!
	runtime.install_time_ranges_binding()!
	host.runtime = &runtime
	handle := voidptr(&host)
	getter := runtime.make_native_value_host_function('get buffered', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.buffered(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	bind := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.bind(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(media_element_native_factory)!
	defer { runtime.release_javascript_value(factory) }
	host.prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.JSValueMakeUndefined(runtime.context), [getter, bind])!)!
	runtime.add_canvas_element_provider(fn [handle] () map[string]&dom.Element {
		host := unsafe { &MediaElementHost(handle) }
		return host.elements_for_binding()
	})
	runtime.add_close_handler(fn [handle] () {
		mut host := unsafe { &MediaElementHost(handle) }
		host.closed = true
		host.records.clear()
		host.elements.clear()
	})
}

fn (mut host MediaElementHost) bind(args []voidptr) !voidptr {
	if host.closed || args.len != 3 { return error('TypeError: Invalid media element binding') }
	wrapper := args[0]
	if !C.JSValueIsObject(host.runtime.context, wrapper) {
		return error('TypeError: Media element wrapper is not an object')
	}
	if _ := host.records[wrapper] { return C.JSValueMakeUndefined(host.runtime.context) }
	key := host.runtime.binding_dom_string(args[1])!
	tag := host.runtime.binding_dom_string(args[2])!
	element := host.element_for_binding(key, tag)!
	media := html.html_media_element_for_dom_element(element) or {
		return error('TypeError: Not an object of type HTMLMediaElement')
	}
	host.runtime.bind_event_target(wrapper, unsafe { &dom.EventTarget(element) })!
	C.JSObjectSetPrototype(host.runtime.context, wrapper, host.prototype)
	host.records[wrapper] = media
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) buffered(receiver voidptr) !voidptr {
	// Native receiver checks precede replay, including author Proxy traps.
	media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	return host.runtime.javascript_time_ranges(media.buffered())
}

// The compact DOM hierarchy remains partial. This base prototype exposes only
// the completed buffered getter and the pinned constants, preserving its other
// existing element operations. Full HTMLElement/audio/video interfaces are open.
const media_element_native_factory = r'(function(getter,bind){
 "use strict";
 const define=Object.defineProperty,create=Object.create,P=Proxy,T=TypeError;
 const prototype=create(EventTarget.prototype);
 define(prototype,"buffered",{get:getter,enumerable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"HTMLMediaElement",configurable:true});
 const constructor=new P(function HTMLMediaElement(){},{apply(){throw new T("Illegal HTMLMediaElement constructor")},construct(){throw new T("Illegal HTMLMediaElement constructor")}});
 define(constructor,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:constructor,writable:true,configurable:true});
 const constants={NETWORK_EMPTY:0,NETWORK_IDLE:1,NETWORK_LOADING:2,NETWORK_NO_SOURCE:3,HAVE_NOTHING:0,HAVE_METADATA:1,HAVE_CURRENT_DATA:2,HAVE_FUTURE_DATA:3,HAVE_ENOUGH_DATA:4};
 for(const name of Object.keys(constants))for(const object of [constructor,prototype])define(object,name,{value:constants[name],enumerable:true});
 define(globalThis,"HTMLMediaElement",{value:constructor,writable:true,configurable:true});
 define(globalThis,"__ladybirdMediaElementBind",{value:bind,configurable:true});
 return prototype;
})'
