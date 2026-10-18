module browserjs

import dom


fn C.JSValueMakeUndefined(context voidptr) voidptr

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
	get_handler := runtime.make_native_value_host_function('get onwheel', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		host := unsafe { &ElementWheelHost(handle) }
		target := host.wheel_handler_target(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
		if replay := host.replay { replay(host.runtime)! }
		return host.runtime.javascript_event_handler(target, 'wheel')!
	})!
	set_handler := runtime.make_native_value_host_function('set onwheel', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &ElementWheelHost(handle) }
		target := host.wheel_handler_target(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
		mut value := voidptr(0)
		if args.len == 0 {
			value = C.JSValueMakeUndefined(host.runtime.context)
		} else {
			value = args[0]
		}
		// Capture callback settings before flushing queued content attributes;
		// an earlier raw onwheel write must not overwrite this later IDL write.
		callback := host.runtime.event_callback(value, true)!
		if replay := host.replay { replay(host.runtime)! }
		target.set_event_handler_attribute('wheel', if callback != unsafe { nil } {
			?&dom.CallbackType(callback)
		} else {
			?&dom.CallbackType(none)
		})
		return C.JSValueMakeUndefined(host.runtime.context)
	})!
	factory := runtime.evaluate_host_value(element_wheel_host_bootstrap)!
	defer { runtime.release_javascript_value(factory) }
	runtime.call_javascript_function(factory, C.JSValueMakeUndefined(runtime.context), [
		bind,
		type_,
		set_resolver,
		get_handler,
		set_handler,
	])!
	runtime.add_canvas_element_provider_with_identity_lookup(fn [handle] () map[string]&dom.Element {
		host := unsafe { &ElementWheelHost(handle) }
		return host.elements_for_binding()
	}, fn [handle] (key string) ?&dom.Element {
		host := unsafe { &ElementWheelHost(handle) }
		if key !in host.elements { return none }
		return unsafe { host.elements[key] }
	}, fn [handle] (element &dom.Element) []string {
		host := unsafe { &ElementWheelHost(handle) }
		return native_canvas_element_identity_keys(host.elements, element)
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
		host.records.clear()
		host.elements.clear()
	})
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
	return C.JSValueMakeBoolean(host.runtime.context, element_exposes_wheel_handler(element))
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
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host ElementWheelHost) resolve_wheel_element_wrapper(target &dom.EventTarget) !voidptr {
	if host.closed || host.resolver == unsafe { nil } { return unsafe { nil } }
	host.refresh_elements()
	for key, element in host.elements {
		if voidptr(element) != voidptr(target) { continue
		 }
		wrapper := host.runtime.call_javascript_function(host.resolver,
			C.JSValueMakeUndefined(host.runtime.context), [host.runtime.binding_string(key)])!
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

const element_wheel_host_bootstrap = r'(function(bind,type,setResolver,getHandler,setHandler){
 "use strict";
 const apply=Reflect.apply,define=Object.defineProperty,wrapped=new WeakSet(),has=WeakSet.prototype.has,add=WeakSet.prototype.add;
 const nativeAdd=EventTarget.prototype.addEventListener,nativeRemove=EventTarget.prototype.removeEventListener,nativeDispatch=EventTarget.prototype.dispatchEvent;
 define(globalThis,"__ladybirdElementWheelSetResolver",{value:setResolver,configurable:true});
 define(globalThis,"__ladybirdElementWheelBind",{value:function(o,key,tag,namespace){
  const exposesHandler=apply(bind,undefined,[o,key,tag,namespace]);
  if(apply(has,wrapped,[o]))return;
  if(exposesHandler)define(o,"onwheel",{get:getHandler,set:setHandler,enumerable:true,configurable:true});
  const legacyAdd=o.addEventListener,legacyRemove=o.removeEventListener;
  define(o,"addEventListener",{value:function addEventListener(name,callback){
   if(arguments.length<2)return apply(nativeAdd,this,arguments);
   const converted=apply(type,undefined,[this,name]);
   if(converted==="wheel")return apply(nativeAdd,this,[converted,callback,arguments[2]]);
   return apply(legacyAdd,this,[converted,callback,arguments[2]]);
  },writable:true,enumerable:true,configurable:true});
  define(o,"removeEventListener",{value:function removeEventListener(name,callback){
   if(arguments.length<2)return apply(nativeRemove,this,arguments);
   const converted=apply(type,undefined,[this,name]);
   if(converted==="wheel")return apply(nativeRemove,this,[converted,callback,arguments[2]]);
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
