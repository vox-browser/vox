module browserjs

import dom
import html
import webidl


pub fn (mut host ImageHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	runtime.install_dom_exception_binding()!
	runtime.install_event_target_binding()!
	host.runtime = &runtime
	host_handle := voidptr(&host)
	decode := runtime.make_value_host_function(fn [host_handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &ImageHost(host_handle) }
		return host.decode(receiver) or { host.reject_binding_exception(err) }
	})!
	get := runtime.make_value_host_function(fn [host_handle] (receiver voidptr, arguments []voidptr) !voidptr {
		mut host := unsafe { &ImageHost(host_handle) }
		return host.get(receiver, arguments) or { host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err)) }
	})!
	set_attribute := runtime.make_value_host_function(fn [host_handle] (_ voidptr, arguments []voidptr) !voidptr {
		mut host := unsafe { &ImageHost(host_handle) }
		return host.set_attribute(arguments) or { host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err)) }
	})!
	bind := runtime.make_value_host_function(fn [host_handle] (_ voidptr, arguments []voidptr) !voidptr {
		mut host := unsafe { &ImageHost(host_handle) }
		return host.bind(arguments) or { host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err)) }
	})!
	installer := runtime.evaluate_host_value(image_host_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	host.prototype = runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		decode,
		get,
		set_attribute,
		bind,
	])!
	runtime.retain_javascript_value(host.prototype)!
	runtime.add_canvas_element_provider_with_identity_lookup(fn [host_handle] () map[string]&dom.Element {
		host := unsafe { &ImageHost(host_handle) }
		return host.elements_for_binding()
	}, fn [host_handle] (key string) ?&dom.Element {
		host := unsafe { &ImageHost(host_handle) }
		if key !in host.elements { return none }
		return unsafe { host.elements[key] }
	}, fn [host_handle] (element &dom.Element) []string {
		host := unsafe { &ImageHost(host_handle) }
		return native_canvas_element_identity_keys(host.elements, element)
	})
	runtime.add_close_handler(fn [host_handle] () {
		mut host := unsafe { &ImageHost(host_handle) }
		host.closed = true
		host.records = {}
	})
}

fn (mut host ImageHost) convert(value webidl.Value) !voidptr {
	if value.dom_exception_ != none { return host.runtime.javascript_dom_exception(value) }
	if value.kind == .undefined { return C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
	return host.runtime.actual_webidl_value(value)
}

fn (mut host ImageHost) wrap(promise &webidl.Promise) !voidptr {
	host_handle := voidptr(&host)
	return host.runtime.javascript_webidl_promise(promise, fn [host_handle] (value webidl.Value) !voidptr {
		mut host := unsafe { &ImageHost(host_handle) }
		return host.convert(value)
	})
}

fn (mut host ImageHost) reject_binding_exception(exception IError) !voidptr {
	// Generated HTMLImageElementPrototype.cpp turns every binding abrupt
	// completion into a rejected Promise, preserving the original engine value.
	actual := host.runtime.binding_exception_value(exception)
	reason := host.runtime.webidl_value(actual)!
	return host.wrap(webidl.create_rejected_promise_for(host.settings.stream_promise_context(), reason))
}

fn (mut host ImageHost) decode(receiver voidptr) !voidptr {
	if host.closed { return error('Image binding is closed') }
	record := host.records[receiver] or { return error('TypeError: HTMLImageElement receiver is not an image') }
	host.replay_before_decode()!
	promise := record.model.decode().webidl_promise() or { return error('Image decode requires its actual WebIDL capability') }
	return host.wrap(promise)
}

fn (mut host ImageHost) bind(arguments []voidptr) !voidptr {
	if host.closed || arguments.len != 2 { return error('TypeError: Invalid image binding') }
	wrapper := arguments[0]
	if !C.JSValueIsObject(host.runtime.context, wrapper) {
		return error('TypeError: Image wrapper is not an object')
	}
	if _ := host.records[wrapper] { return C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
	key := host.runtime.binding_dom_string(arguments[1])!
	element := host.element_for_binding(key)!
	image := unsafe { &dom.HTMLImageElement(element) }
	mut model := host.configure_image_fetch(image)
	host.records[wrapper] = &ImageHostRecord{ key: key, element: image, model: model }
	host.runtime.bind_event_target(wrapper, unsafe { &dom.EventTarget(element) })!
	C.JSObjectSetPrototype(host.runtime.context, wrapper, host.prototype)
	if !model.has_pending_request() && (element.has_attribute('src') || element.has_attribute('srcset')) {
		model.update_the_image_data(false, false)
	}
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (mut host ImageHost) set_attribute(arguments []voidptr) !voidptr {
	if arguments.len != 3 { return error('TypeError: Invalid image attribute binding') }
	record := host.records[arguments[0]] or { return error('TypeError: HTMLImageElement receiver is not an image') }
	name := host.runtime.binding_dom_string(arguments[1])!
	value := if C.JSValueIsNull(host.runtime.context, arguments[2]) {
		?string(none)
	} else {
		?string(host.runtime.binding_dom_string(arguments[2])!)
	}
	mut element := unsafe { &dom.Element(record.element) }
	old := element.get_attribute(name)
	if text := value {
		if previous := old {
			if text == previous { return C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
		}
	} else if old == none {
		return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
	}
	if text := value {
		element.set_attribute_value(name, text)
	} else {
		element.remove_attribute(name)
	}
	html.html_image_element_form_associated_element_attribute_changed(record.element, name, old, value, none)
	if name in ['src', 'srcset'] {
		mut node := element.as_node()
		node.set_needs_layout_update(.html_image_element_update_the_image_data)
		node.set_needs_repaint(.paint_commands)
	}
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (mut host ImageHost) get(receiver voidptr, arguments []voidptr) !voidptr {
	if arguments.len != 1 { return error('TypeError: Invalid image property binding') }
	record := host.records[receiver] or { return error('TypeError: HTMLImageElement receiver is not an image') }
	property := host.runtime.binding_dom_string(arguments[0])!
	return match property {
		'crossOrigin' {
			match record.model.crossorigin() {
				.no_cors { C.vox_jsc_JSValueMakeNull(host.runtime.context) }
				.anonymous { host.runtime.binding_string('anonymous') }
				.use_credentials { host.runtime.binding_string('use-credentials') }
			}
		}
		'complete' { C.vox_jsc_JSValueMakeBoolean(host.runtime.context, record.model.complete()) }
		'naturalWidth' { C.vox_jsc_JSValueMakeNumber(host.runtime.context, record.model.natural_width()) }
		'naturalHeight' { C.vox_jsc_JSValueMakeNumber(host.runtime.context, record.model.natural_height()) }
		'currentSrc' { host.runtime.binding_string(record.model.current_src()) }
		'width' {
			C.vox_jsc_JSValueMakeNumber(host.runtime.context, html.html_image_element_width(record.element))
		}
		'height' {
			C.vox_jsc_JSValueMakeNumber(host.runtime.context, html.html_image_element_height(record.element))
		}
		else { return error('TypeError: Unknown image property') }
	}
}

const image_host_bootstrap = r'(function(decode,get,setAttribute,bind){
 const apply=Reflect.apply,define=Object.defineProperty,String=globalThis.String;
 function HTMLImageElement(){throw new TypeError("Illegal HTMLImageElement constructor")}
 const prototype=HTMLImageElement.prototype;Object.setPrototypeOf(prototype,EventTarget.prototype);
 define(prototype,"decode",{value:function decode(){return apply(decodeNative,this,[])},writable:true,enumerable:true,configurable:true});
 const decodeNative=decode;
 for(const name of ["complete","naturalWidth","naturalHeight","currentSrc"])define(prototype,name,{get:function(){return apply(get,this,[name])},enumerable:true,configurable:true});
 define(prototype,"crossOrigin",{get:function(){return apply(get,this,["crossOrigin"])},set:function(value){const converted=value===null?null:String(value);setAttribute(this,"crossorigin",converted);const state=this.__state;if(state&&state.attributes){if(converted===null)delete state.attributes.crossorigin;else state.attributes.crossorigin=converted;state.attributesDirty=true;}},enumerable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"HTMLImageElement",configurable:true});
 define(globalThis,"HTMLImageElement",{value:HTMLImageElement,writable:true,configurable:true});
 define(globalThis,"__ladybirdImageBind",{value:bind,configurable:true});
 define(globalThis,"__ladybirdImageGet",{value:function(receiver,name){return apply(get,receiver,[name])},configurable:true});
 define(globalThis,"__ladybirdImageSetAttribute",{value:setAttribute,configurable:true});
 return prototype;
})'
