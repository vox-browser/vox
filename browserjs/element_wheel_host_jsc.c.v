module browserjs

import dom
import json2


fn C.vox_jsc_JSValueMakeUndefined(context voidptr) voidptr

pub fn (mut host ElementWheelHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	runtime.install_event_target_binding()!
	host.runtime = &runtime
	host.install_raw_wheel_handler_compiler()!
	handle := voidptr(&host)
	bind := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &ElementWheelHost(handle) }
		return host.bind_wheel_element(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	type_ := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		host := unsafe { &ElementWheelHost(handle) }
		return host.wheel_listener_type(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	set_resolver := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &ElementWheelHost(handle) }
		return host.set_wheel_element_resolver(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	get_handler, set_handler := host.element_event_handler_accessors('wheel')!
	get_scrollend, set_scrollend := host.element_event_handler_accessors('scrollend')!
	inline_handler := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &ElementWheelHost(handle) }
		return host.inline_handler_operation(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(element_wheel_host_bootstrap())!
	defer { runtime.release_javascript_value(factory) }
	runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		bind,
		type_,
		set_resolver,
		get_handler,
		set_handler,
		get_scrollend,
		set_scrollend,
		inline_handler,
	])!
	runtime.add_canvas_element_provider_with_merge(fn [handle] () map[string]&dom.Element {
		host := unsafe { &ElementWheelHost(handle) }
		return host.elements_for_binding()
	}, fn [handle] (key string) ?&dom.Element {
		host := unsafe { &ElementWheelHost(handle) }
		if key !in host.elements { return none }
		return unsafe { host.elements[key] }
	}, fn [handle] (element &dom.Element) []string {
		host := unsafe { &ElementWheelHost(handle) }
		return native_canvas_element_identity_keys(host.elements, element)
	}, fn [handle] (registry &CanvasElementRegistry) {
		host := unsafe { &ElementWheelHost(handle) }
		for key, element in host.elements { registry.set(key, element) }
	})
	runtime.install_event_target_wrapper_provider(EventTargetWrapperProvider{
		owner:  handle
		create: fn [handle] (target &dom.EventTarget) !voidptr {
			mut host := unsafe { &ElementWheelHost(handle) }
			return host.resolve_wheel_element_wrapper(target)!
		}
	})!
	runtime.add_close_handler(fn [handle] () {
		mut host := unsafe { &ElementWheelHost(handle) }
		host.closed = true
		host.resolver = unsafe { nil }
		host.records = {}
		host.elements = {}
	})
}

fn (mut host ElementWheelHost) element_event_handler_accessors(name string) !(voidptr, voidptr) {
	handle := voidptr(&host)
	get_handler := host.runtime.make_native_value_host_function('get on' + name, 0, fn [handle, name] (receiver voidptr, _ []voidptr) !voidptr {
		host := unsafe { &ElementWheelHost(handle) }
		target := host.wheel_handler_target(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
		if replay := host.replay { replay(host.runtime)! }
		return host.runtime.javascript_event_handler(target, name)!
	})!
	set_handler := host.runtime.make_native_value_host_function('set on' + name, 1, fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &ElementWheelHost(handle) }
		target := host.wheel_handler_target(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
		mut value := voidptr(0)
		if args.len == 0 {
			value = C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
		} else {
			value = args[0]
		}
		// Capture callback settings before flushing queued content attributes;
		// an earlier raw content-attribute write must not overwrite this later IDL write.
		callback := host.runtime.event_callback(value, true)!
		if replay := host.replay { replay(host.runtime)! }
		target.set_event_handler_attribute(name, if callback != unsafe { nil } {
			?&dom.CallbackType(callback)
		} else {
			?&dom.CallbackType(none)
		})
		return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
	})!
	return get_handler, set_handler
}

// HTMLElement's GlobalEventHandlers accessors: 0 gets and 1 sets a handler,
// 2 reports whether the receiver's inline handlers are native. Get and set
// return undefined when the compact layer still owns the receiver's handlers.
fn (mut host ElementWheelHost) inline_handler_operation(args []voidptr) !voidptr {
	if host.closed || args.len < 3 { return error('TypeError: Invalid Element handler operation') }
	mut exception := voidptr(0)
	operation := int(C.vox_jsc_JSValueToNumber(host.runtime.context, args[0], &exception))
	element := host.records[args[1]] or { return C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
	if !element_owns_native_inline_handlers(element) {
		if operation == 2 { return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, false) }
		return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
	}
	if operation == 2 { return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, true) }
	name := host.runtime.binding_dom_string(args[2])!
	if name !in element_inline_handler_events { return error('TypeError: Unknown event handler') }
	target := unsafe { &dom.EventTarget(element) }
	if operation == 0 {
		if replay := host.replay { replay(host.runtime)! }
		return host.runtime.javascript_event_handler(target, name)!
	}
	value := if args.len > 3 { args[3] } else { C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
	// Capture callback settings before flushing queued content attributes;
	// an earlier raw content-attribute write must not overwrite this later IDL write.
	callback := host.runtime.event_callback(value, true)!
	if replay := host.replay { replay(host.runtime)! }
	target.set_event_handler_attribute(name, if callback != unsafe { nil } {
		?&dom.CallbackType(callback)
	} else {
		?&dom.CallbackType(none)
	})
	return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, true)
}

fn element_exposes_wheel_handler(element &dom.Element) bool {
	return (element.namespace_uri() or { '' }) in ['http://www.w3.org/1999/xhtml',
		'http://www.w3.org/2000/svg', 'http://www.w3.org/1998/Math/MathML']
}

fn (host &ElementWheelHost) wheel_handler_target(receiver voidptr) !&dom.EventTarget {
	if host.closed { return error('TypeError: Element wheel binding is closed') }
	// The receiver must be this host's actual facade, not a Proxy, inherited
	// facade, arbitrary EventTarget or an element without GlobalEventHandlers.
	element := host.records[receiver] or {
		return error('TypeError: Not an object with a native Element wheel handler')
	}
	if !element_exposes_wheel_handler(element) {
		return error('TypeError: Not an object with a native Element wheel handler')
	}
	return unsafe { &dom.EventTarget(element) }
}

fn (host &ElementWheelHost) wheel_listener_type(args []voidptr) !voidptr {
	if host.closed || args.len != 2 { return error('TypeError: Invalid Element wheel operation') }
	// Carry the strict JavaScript receiver as a value: JSC's callback thisObject
	// otherwise substitutes/boxes null, undefined and primitive receivers.
	host.runtime.native_event_target(args[0])!
	return host.runtime.binding_string(host.runtime.binding_dom_string(args[1])!)
}

fn (mut host ElementWheelHost) bind_wheel_element(args []voidptr) !voidptr {
	if host.closed || args.len != 4 { return error('TypeError: Invalid Element wheel binding') }
	wrapper := args[0]
	if !C.JSValueIsObject(host.runtime.context, wrapper) {
		return error('TypeError: Element wrapper is not an object')
	}
	key := host.runtime.binding_dom_string(args[1])!
	tag := host.runtime.binding_dom_string(args[2])!
	namespace := if C.JSValueIsNull(host.runtime.context, args[3])
		|| C.JSValueIsUndefined(host.runtime.context, args[3]) {
		''
	} else {
		host.runtime.binding_dom_string(args[3])!
	}
	element := host.element_for_wheel_binding(key, tag, namespace)!
	binding := host.runtime.event_binding()!
	if existing := binding.targets[wrapper] {
		if voidptr(existing) != voidptr(element) {
			return error('TypeError: Element wrapper already owns a different native target')
		}
	} else {
		host.runtime.bind_event_target(wrapper, unsafe { &dom.EventTarget(element) })!
	}
	host.records[wrapper] = element
	return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, element_exposes_wheel_handler(element))
}

fn (mut host ElementWheelHost) set_wheel_element_resolver(args []voidptr) !voidptr {
	if host.closed || args.len != 1 || !C.JSValueIsObject(host.runtime.context, args[0])
		|| !C.JSObjectIsFunction(host.runtime.context, args[0]) {
		return error('TypeError: Element wrapper resolver must be callable')
	}
	if host.resolver != unsafe { nil } {
		return error('TypeError: Element wrapper resolver is already installed')
	}
	host.resolver = host.runtime.retain_javascript_value(args[0])!
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (mut host ElementWheelHost) resolve_wheel_element_wrapper(target &dom.EventTarget) !voidptr {
	if host.closed || host.resolver == unsafe { nil } { return unsafe { nil } }
	// Only elements have wrapper keys; windows, documents and other nodes
	// never match, so do not refresh the registry for them.
	if !event_target_is_element(target) { return unsafe { nil } }
	host.refresh_elements()
	for key, element in host.elements {
		if voidptr(element) != voidptr(target) { continue
		 }
		wrapper := host.runtime.call_javascript_function(host.resolver,
			C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [host.runtime.binding_string(key)])!
		if C.JSValueIsNull(host.runtime.context, wrapper)
			|| C.JSValueIsUndefined(host.runtime.context, wrapper) {
			return unsafe { nil }
		}
		if !C.JSValueIsObject(host.runtime.context, wrapper) {
			return error('TypeError: Element resolver returned a non-object wrapper')
		}
		return wrapper
	}
	return unsafe { nil }
}

fn element_wheel_host_bootstrap() string {
	// Existing built-in event adapters still own their compact resource/UI
	// delivery. Arbitrary author event names must share the native listener
	// list with dispatchEvent, including capture, cancellation and options.
	pointer_types := native_pointer_event_names()
	legacy_types := window_event_handler_names().filter(it.event !in pointer_types).map(it.event)
	return r'(function(bind,type,setResolver,getHandler,setHandler,getScrollEnd,setScrollEnd,inlineHandler){
 "use strict";
 const apply=Reflect.apply,define=Object.defineProperty,wrapped=new WeakSet(),has=WeakSet.prototype.has,add=WeakSet.prototype.add;
 const legacyTypes=new Set(' + json2.encode(legacy_types) + r'),legacyHas=Set.prototype.has;
 const nativeAdd=EventTarget.prototype.addEventListener,nativeRemove=EventTarget.prototype.removeEventListener,nativeDispatch=EventTarget.prototype.dispatchEvent;
 function nativeEvent(name){return name==="wheel"||name==="scrollend"||name==="beforeinput"||name==="input"||name==="change"||name==="click"||name==="keydown"||name==="keyup"||name==="keypress"||name==="submit"||name==="reset"||name==="formdata"||name==="invalid"||!apply(legacyHas,legacyTypes,[name]);}
 define(globalThis,"__ladybirdElementWheelSetResolver",{value:setResolver,configurable:true});
 define(globalThis,"__ladybirdElementInlineHandler",{value:inlineHandler,configurable:true});
 define(globalThis,"__ladybirdElementWheelBind",{value:function(o,key,tag,namespace){
  const exposesHandler=apply(bind,undefined,[o,key,tag,namespace]);
  if(apply(has,wrapped,[o]))return;
  if(exposesHandler){
   define(o,"onwheel",{get:getHandler,set:setHandler,enumerable:true,configurable:true});
   define(o,"onscrollend",{get:getScrollEnd,set:setScrollEnd,enumerable:true,configurable:true});
  }
  const legacyAdd=o.addEventListener,legacyRemove=o.removeEventListener;
  define(o,"addEventListener",{value:function addEventListener(name,callback){
   if(arguments.length<2)return apply(nativeAdd,this,arguments);
   const converted=apply(type,undefined,[this,name]);
   if(nativeEvent(converted))return apply(nativeAdd,this,[converted,callback,arguments[2]]);
   return apply(legacyAdd,this,[converted,callback,arguments[2]]);
  },writable:true,enumerable:true,configurable:true});
  define(o,"removeEventListener",{value:function removeEventListener(name,callback){
   if(arguments.length<2)return apply(nativeRemove,this,arguments);
   const converted=apply(type,undefined,[this,name]);
   if(nativeEvent(converted))return apply(nativeRemove,this,[converted,callback,arguments[2]]);
   return apply(legacyRemove,this,[converted,callback,arguments[2]]);
  },writable:true,enumerable:true,configurable:true});
  define(o,"dispatchEvent",{value:function dispatchEvent(event){
   if(arguments.length<1)return apply(nativeDispatch,this,arguments);
   apply(type,undefined,[this,""]);
   return apply(nativeDispatch,this,arguments);
  },writable:true,enumerable:true,configurable:true});
  apply(add,wrapped,[o]);
 },configurable:true});
})'
}
