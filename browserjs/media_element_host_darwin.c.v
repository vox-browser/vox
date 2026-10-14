module browserjs

import dom
import html
import json2
import math
import webidl

fn C.JSObjectMakeDate(context voidptr, count usize, arguments &voidptr, exception &voidptr) voidptr

pub fn (mut host MediaElementHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	runtime.install_event_target_binding()!
	runtime.install_time_ranges_binding()!
	runtime.install_media_error_binding()!
	runtime.install_dom_exception_binding()!
	host.runtime = &runtime
	handle := voidptr(&host)
	mut getters := []voidptr{}
	for name in ['buffered', 'currentSrc', 'networkState', 'readyState', 'seeking', 'duration', 'paused', 'ended', 'defaultPlaybackRate', 'playbackRate', 'volume', 'muted', 'currentTime', 'error', 'played', 'seekable'] {
		getters << runtime.make_native_value_host_function('get ${name}', 0, fn [handle, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			return host.get(name, receiver) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
	}
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(runtime.context, usize(getters.len), getters.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(array)!
	defer { runtime.release_javascript_value(array) }
	mut setters := []voidptr{}
	for name in ['defaultPlaybackRate', 'playbackRate', 'volume', 'muted', 'currentTime'] {
		setters << runtime.make_native_value_host_function('set ${name}', 1, fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			mut argument := C.JSValueMakeUndefined(host.runtime.context)
			if args.len > 0 { argument = args[0] }
			return host.set_property(name, receiver, argument) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
	}
	setter_array := C.JSObjectMakeArray(runtime.context, usize(setters.len), setters.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(setter_array)!
	defer { runtime.release_javascript_value(setter_array) }
	mut handler_getters := []voidptr{}
	mut handler_setters := []voidptr{}
	for name in media_element_event_handler_names {
		handler_getters << runtime.make_native_value_host_function('get on${name}', 0, fn [handle, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			return host.get_event_handler(name, receiver) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
		handler_setters << runtime.make_native_value_host_function('set on${name}', 1, fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			mut argument := C.JSValueMakeUndefined(host.runtime.context)
			if args.len > 0 { argument = args[0] }
			return host.set_event_handler(name, receiver, argument) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
	}
	handler_getter_array := C.JSObjectMakeArray(runtime.context, usize(handler_getters.len), handler_getters.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(handler_getter_array)!
	defer { runtime.release_javascript_value(handler_getter_array) }
	handler_setter_array := C.JSObjectMakeArray(runtime.context, usize(handler_setters.len), handler_setters.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(handler_setter_array)!
	defer { runtime.release_javascript_value(handler_setter_array) }
	fast_seek := runtime.make_native_value_host_function('fastSeek', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.fast_seek(receiver, args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	start_date := runtime.make_native_value_host_function('getStartDate', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.start_date(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	pause := runtime.make_native_value_host_function('pause', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.pause(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	load := runtime.make_native_value_host_function('load', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.load(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	play := runtime.make_native_value_host_function('play', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		// Promise-returning WebIDL operations reject binding abrupt completions.
		return host.play(receiver) or { host.reject_play_binding_exception(err) }
	})!
	can_play_type := runtime.make_native_value_host_function('canPlayType', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.can_play_type(receiver, args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	bind := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.bind(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(media_element_native_factory.replace('__MEDIA_HANDLER_NAMES__',
		json2.encode(media_element_event_handler_names)))!
	defer { runtime.release_javascript_value(factory) }
	host.prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.JSValueMakeUndefined(runtime.context), [array, setter_array, bind, fast_seek, start_date,
			pause, load, play, handler_getter_array, handler_setter_array, can_play_type])!)!
	runtime.add_canvas_element_provider_with_lookup(fn [handle] () map[string]&dom.Element {
		host := unsafe { &MediaElementHost(handle) }
		return host.elements_for_binding()
	}, fn [handle] (key string) ?&dom.Element {
		host := unsafe { &MediaElementHost(handle) }
		if key !in host.elements { return none }
		return unsafe { host.elements[key] }
	})
	runtime.add_close_handler(fn [handle] () {
		mut host := unsafe { &MediaElementHost(handle) }
		host.closed = true
		host.records.clear()
		host.elements.clear()
	})
	// The combined Document compiler must use this owner's actual media records.
	runtime.media_element_hosts_ << &host
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

fn (mut host MediaElementHost) get(name string, receiver voidptr) !voidptr {
	// Native receiver checks precede replay, including author Proxy traps.
	media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	return match name {
		'buffered' { host.runtime.javascript_time_ranges(media.buffered())! }
		'played' { host.runtime.javascript_time_ranges(media.played())! }
		'seekable' { host.runtime.javascript_time_ranges(media.seekable())! }
		'currentSrc' { host.runtime.binding_string(media.current_src()) }
		'networkState' { C.JSValueMakeNumber(host.runtime.context, f64(media.network_state())) }
		'readyState' { C.JSValueMakeNumber(host.runtime.context, f64(media.ready_state())) }
		'seeking' { C.JSValueMakeBoolean(host.runtime.context, media.seeking()) }
		'duration' { C.JSValueMakeNumber(host.runtime.context, media.duration()) }
		'paused' { C.JSValueMakeBoolean(host.runtime.context, media.paused()) }
		'ended' { C.JSValueMakeBoolean(host.runtime.context, media.ended()) }
		'defaultPlaybackRate' { C.JSValueMakeNumber(host.runtime.context, media.default_playback_rate()) }
		'playbackRate' { C.JSValueMakeNumber(host.runtime.context, media.playback_rate()) }
		'volume' { C.JSValueMakeNumber(host.runtime.context, media.volume()) }
		'muted' { C.JSValueMakeBoolean(host.runtime.context, media.muted()) }
		'currentTime' { C.JSValueMakeNumber(host.runtime.context, media.current_time()) }
		'error' {
			if failure := media.error() { host.runtime.javascript_media_error(failure)! }
			else { C.JSValueMakeNull(host.runtime.context) }
		}
		else { return error('Unknown media element getter') }
	}
}

fn (mut host MediaElementHost) get_event_handler(name string, receiver voidptr) !voidptr {
	media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	return host.runtime.javascript_event_handler(media.event_target(), name)
}

fn (mut host MediaElementHost) set_event_handler(name string, receiver voidptr, value voidptr) !voidptr {
	media := host.media_element_for_binding(receiver)!
	// Convert and capture the incumbent settings before replaying DOM mutations.
	callback := host.runtime.event_callback(value, true)!
	if replay := host.replay { replay(host.runtime)! }
	media.event_target().set_event_handler_attribute(name, if callback != unsafe { nil } {
		?&dom.CallbackType(callback)
	} else {
		none
	})
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) restricted_double(name string, value voidptr) !f64 {
	// Unary plus preserves ECMAScript ToNumber, including the BigInt rejection.
	converted := host.runtime.call_engine_function(host.runtime.value_number_intrinsic_, [value])!
	mut exception := unsafe { nil }
	number := C.JSValueToNumber(host.runtime.context, converted, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	if !math.is_finite(number) { return error('TypeError: Expected ${name} to be a finite floating-point number') }
	return number
}

fn (mut host MediaElementHost) fast_seek(receiver voidptr, args []voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	// Source's generated operation checks the receiver, arity, then conversion.
	if args.len == 0 { return error('TypeError: fastSeek() needs one argument') }
	number := host.restricted_double('time', args[0])!
	if replay := host.replay { replay(host.runtime)! }
	media.fast_seek(number)
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) can_play_type(receiver voidptr, args []voidptr) !voidptr {
	media := host.media_element_for_binding(receiver)!
	if args.len == 0 { return error('TypeError: canPlayType() needs one argument') }
	// DOMString retains every UTF-16 code unit, including lone surrogates.
	converted := host.runtime.binding_dom_utf16(args[0])!
	type_ := converted.str()
	if replay := host.replay { replay(host.runtime)! }
	return host.runtime.binding_string(match media.can_play_type(type_) {
		.empty { '' }
		.maybe { 'maybe' }
		.probably { 'probably' }
	})
}

fn (mut host MediaElementHost) start_date(receiver voidptr) !voidptr {
	media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	value := media.get_start_date().get_time()
	// Source Date::create installs the raw value; JSC's constructor TimeClips it.
	// Keep that existing engine boundary explicit instead of silently losing it.
	if !math.is_nan(value) && math.abs(value) > 8_640_000_000_000_000.0 {
		return error('Source media Date value cannot be installed exactly by JavaScriptCore')
	}
	arguments := [C.JSValueMakeNumber(host.runtime.context, value)]
	mut exception := unsafe { nil }
	date := C.JSObjectMakeDate(host.runtime.context, 1, arguments.data, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	return date
}

fn (mut host MediaElementHost) pause(receiver voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	media.pause()
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) wrap_play_promise(promise &webidl.Promise) !voidptr {
	handle := voidptr(&host)
	return host.runtime.javascript_webidl_promise(promise, fn [handle] (value webidl.Value) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		if value.dom_exception_ != none { return host.runtime.javascript_dom_exception(value) }
		if value.kind == .undefined { return C.JSValueMakeUndefined(host.runtime.context) }
		return host.runtime.actual_webidl_value(value)
	})
}

fn (mut host MediaElementHost) reject_play_binding_exception(exception IError) !voidptr {
	actual := host.runtime.binding_exception_value(exception)
	return host.wrap_play_promise(webidl.create_rejected_promise_for(host.settings.stream_promise_context(),
		host.runtime.webidl_value(actual)!))
}

fn (mut host MediaElementHost) play(receiver voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	promise := media.play().webidl_promise() or { return error('Media play requires its actual WebIDL capability') }
	return host.wrap_play_promise(promise)
}

fn (mut host MediaElementHost) load(receiver voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	media.load() or {
		message := err.msg()
		if !message.starts_with('NotSupportedError:') { return err }
		native_exception := webidl.dom_exception_value(webidl.DOMException.create('NotSupportedError',
			message['NotSupportedError:'.len..].trim_left(' ')))
		return host.runtime.actual_javascript_exception(host.runtime.javascript_dom_exception(native_exception)!)
	}
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) set_property(name string, receiver voidptr, value voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	// Source's generated setters check the brand before converting the value.
	if name == 'muted' {
		// ToBoolean does not invoke author conversion hooks, including on proxies.
		muted := C.JSValueToBoolean(host.runtime.context, value)
		if replay := host.replay { replay(host.runtime)! }
		media.set_muted(muted)
		return C.JSValueMakeUndefined(host.runtime.context)
	}
	number := host.restricted_double(name, value)!
	if replay := host.replay { replay(host.runtime)! }
	if name == 'defaultPlaybackRate' {
		media.set_default_playback_rate(number)
	} else if name == 'currentTime' {
		media.set_current_time(number)
	} else if name == 'volume' {
		media.set_volume(number) or {
			message := err.msg()
			if !message.starts_with('IndexSizeError:') { return err }
			native_exception := webidl.dom_exception_value(webidl.DOMException.create('IndexSizeError',
				message['IndexSizeError:'.len..].trim_left(' ')))
			return host.runtime.actual_javascript_exception(host.runtime.javascript_dom_exception(native_exception)!)
		}
	} else {
		media.set_playback_rate(number) or {
			message := err.msg()
			if !message.starts_with('NotSupportedError:') { return err }
			native_exception := webidl.dom_exception_value(webidl.DOMException.create('NotSupportedError',
				message['NotSupportedError:'.len..].trim_left(' ')))
			return host.runtime.actual_javascript_exception(host.runtime.javascript_dom_exception(native_exception)!)
		}
	}
	return C.JSValueMakeUndefined(host.runtime.context)
}

// The compact DOM hierarchy remains partial. This base prototype exposes only
// the completed state/range getters, rate/volume/time accessors, fastSeek,
// getStartDate, pause, load, play, canPlayType, selected media and input handler attributes,
// and constants.
// Full HTMLElement/audio/video interfaces remain open.
const media_element_native_factory = r'(function(getters,setters,bind,fastSeek,getStartDate,pause,load,play,handlerGetters,handlerSetters,canPlayType){
 "use strict";
 const define=Object.defineProperty,create=Object.create,P=Proxy,T=TypeError;
 const prototype=create(EventTarget.prototype);
 const names=["buffered","currentSrc","networkState","readyState","seeking","duration","paused","ended"];
 for(let i=0;i<names.length;i++)define(prototype,names[i],{get:getters[i],enumerable:true,configurable:true});
 const properties=["defaultPlaybackRate","playbackRate","volume","muted","currentTime"];
 for(let i=0;i<properties.length;i++)define(prototype,properties[i],{get:getters[names.length+i],set:setters[i],enumerable:true,configurable:true});
 define(prototype,"error",{get:getters[names.length+properties.length],enumerable:true,configurable:true});
 define(prototype,"played",{get:getters[names.length+properties.length+1],enumerable:true,configurable:true});
 define(prototype,"seekable",{get:getters[names.length+properties.length+2],enumerable:true,configurable:true});
 const handlerNames=__MEDIA_HANDLER_NAMES__;
 for(let i=0;i<handlerNames.length;i++)define(prototype,"on"+handlerNames[i],{get:handlerGetters[i],set:handlerSetters[i],enumerable:true,configurable:true});
 define(prototype,"fastSeek",{value:fastSeek,writable:true,enumerable:true,configurable:true});
 define(prototype,"getStartDate",{value:getStartDate,writable:true,enumerable:true,configurable:true});
 define(prototype,"pause",{value:pause,writable:true,enumerable:true,configurable:true});
 define(prototype,"load",{value:load,writable:true,enumerable:true,configurable:true});
 define(prototype,"play",{value:play,writable:true,enumerable:true,configurable:true});
 define(prototype,"canPlayType",{value:canPlayType,writable:true,enumerable:true,configurable:true});
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
