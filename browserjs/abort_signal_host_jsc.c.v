// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Native generated-binding adaptation for DOM/Abort{Controller,Signal}.idl.
// All state, dependencies, reasons and event dispatch belong to source DOM.
@[has_globals]
module browserjs

import dom
import html
import webidl



__global abort_signal_bindings_ = map[voidptr]&AbortSignalHost{}

pub fn (mut host AbortSignalHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	if installed := abort_signal_bindings_[voidptr(&runtime)] {
		if voidptr(installed) == voidptr(&host) { return }
		return error('AbortSignal binding already belongs to this runtime')
	}
	runtime.install_dom_exception_binding()!
	runtime.install_event_target_binding()!
	host.runtime = &runtime
	host_handle := voidptr(&host)
	operate := runtime.make_value_host_function(fn [host_handle] (_ voidptr, args []voidptr) !voidptr {
		mut owner := unsafe { &AbortSignalHost(host_handle) }
		return owner.operate(args) or {
			if err is webidl.ValueException {
				return owner.runtime.actual_javascript_exception(owner.value(err.value)!)
			}
			return owner.runtime.actual_javascript_exception(owner.runtime.binding_exception_value(err))
		}
	})!
	installer := runtime.evaluate_host_value(abort_signal_native_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	prototypes := runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [operate])!
	runtime.retain_javascript_value(prototypes)!
	defer { runtime.release_javascript_value(prototypes) }
	for index, kind in [AbortSignalHostKind.signal, .controller] {
		mut exception := unsafe { nil }
		prototype := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, prototypes, u32(index), &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		host.prototypes[kind] = runtime.retain_javascript_value(prototype)!
	}
	abort_signal_bindings_[voidptr(&runtime)] = &host
	owner_handle := voidptr(&runtime)
	runtime.add_close_handler(fn [host_handle, owner_handle] () {
		mut owner := unsafe { &AbortSignalHost(host_handle) }
		owner.close()
		abort_signal_bindings_.delete(owner_handle)
	})
}

fn (host &AbortSignalHost) argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (mut host AbortSignalHost) value(value webidl.Value) !voidptr {
	if value.dom_exception_ != none { return host.runtime.javascript_dom_exception(value) }
	match value.kind {
		.runtime_value { return host.runtime.actual_webidl_value(value) }
		.undefined { return C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
		.null_ { return C.vox_jsc_JSValueMakeNull(host.runtime.context) }
		.boolean { return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, value.boolean_value) }
		.number { return C.vox_jsc_JSValueMakeNumber(host.runtime.context, value.number_value) }
		.string_ { return host.runtime.binding_string(value.string_value) }
		else { return error('Abort reason requires its actual JavaScript platform wrapper') }
	}
}

fn (mut host AbortSignalHost) wrap(kind AbortSignalHostKind, native voidptr, desired_prototype voidptr) !voidptr {
	if existing := host.records[native] {
		if existing.kind != kind { return error('Abort object native interface mismatch') }
		return existing.object
	}
	mut record := &AbortSignalHostRecord{host: host, kind: kind, native: native}
	object := host.runtime.make_native_stream_wrapper(record)!
	mut prototype := host.prototypes[kind] or { return error('Abort object prototype is missing') }
	if desired_prototype != unsafe { nil } && C.JSValueIsObject(host.runtime.context, desired_prototype) {
		prototype = desired_prototype
	}
	C.JSObjectSetPrototype(host.runtime.context, object, prototype)
	record.object = object
	host.records[native] = record
	if kind == .signal { host.runtime.bind_event_target(object, unsafe { &dom.EventTarget(native) })! }
	return object
}

fn (host &AbortSignalHost) record(value voidptr, kind AbortSignalHostKind) !&AbortSignalHostRecord {
	if host.closed { return error('AbortSignal binding is closed') }
	data := host.runtime.native_stream_wrapper_record(value)
	if data == unsafe { nil } { return error('TypeError: Illegal Abort interface receiver') }
	record := unsafe { &AbortSignalHostRecord(data) }
	if voidptr(record.host) != voidptr(host) || record.kind != kind { return error('TypeError: Illegal Abort interface receiver') }
	return record
}

pub fn (runtime &Runtime) native_abort_signal(value voidptr) !&dom.AbortSignal {
	host := abort_signal_bindings_[voidptr(runtime)] or { return error('AbortSignal binding is unavailable') }
	record := host.record(value, .signal)!
	return unsafe { &dom.AbortSignal(record.native) }
}

// Generated controller getters wrap the same DOM signal, preserving its native
// reason, event target and actual engine wrapper identity.
pub fn (mut runtime Runtime) javascript_abort_signal(signal &dom.AbortSignal) !voidptr {
	runtime.require_javascript_value_context()!
	mut host := abort_signal_bindings_[voidptr(&runtime)] or { return error('AbortSignal binding is unavailable') }
	return host.wrap(.signal, voidptr(signal), unsafe { nil })
}

pub fn (runtime &Runtime) native_abort_controller(value voidptr) !&dom.AbortController {
	host := abort_signal_bindings_[voidptr(runtime)] or { return error('AbortController binding is unavailable') }
	record := host.record(value, .controller)!
	return unsafe { &dom.AbortController(record.native) }
}

fn (mut host AbortSignalHost) operate(args []voidptr) !voidptr {
	if host.closed { return error('AbortSignal binding is closed') }
	op := host.runtime.binding_dom_string(host.argument(args, 0))!
	value := host.argument(args, 1)
	parameter := host.argument(args, 2)
	match op {
		'construct' {
			controller := dom.AbortController.construct_impl()!
			return host.wrap(.controller, voidptr(controller), value)
		}
		'abort-static' {
			signal := dom.AbortSignal.abort(dom.js_webidl_value(host.runtime.webidl_value(value)!))!
			return host.wrap(.signal, voidptr(signal), unsafe { nil })
		}
		'timeout' {
			mut exception := unsafe { nil }
			number := C.vox_jsc_JSValueToNumber(host.runtime.context, value, &exception)
			if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
			milliseconds := u64(webidl.convert_to_int(webidl.number_value(number), 64, false, .yes, .no)!)
			signal := html.abort_signal_timeout(host.settings, milliseconds)!
			return host.wrap(.signal, voidptr(signal), unsafe { nil })
		}
		'validate' { host.record(value, .signal)!; return C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
		'any' {
			length := host.runtime.binding_property(value, 'length')!
			mut exception := unsafe { nil }
			count := int(C.vox_jsc_JSValueToNumber(host.runtime.context, length, &exception))
			if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
			mut signals := []&dom.AbortSignal{cap: count}
			for index in 0 .. count {
				actual := C.vox_jsc_JSObjectGetPropertyAtIndex(host.runtime.context, value, u32(index), &exception)
				if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
				record := host.record(actual, .signal)!
				signals << unsafe { &dom.AbortSignal(record.native) }
			}
			signal := dom.AbortSignal.any(signals)!
			return host.wrap(.signal, voidptr(signal), unsafe { nil })
		}
		'signal' {
			record := host.record(value, .controller)!
			controller := unsafe { &dom.AbortController(record.native) }
			return host.wrap(.signal, voidptr(controller.signal()), unsafe { nil })
		}
		'abort' {
			record := host.record(value, .controller)!
			mut controller := unsafe { &dom.AbortController(record.native) }
			settings := host.settings
			controller.abort_with_clock(dom.js_webidl_value(host.runtime.webidl_value(parameter)!), fn [settings] () f64 {
				return settings.global_relative_event_timestamp()
			})
			host.runtime.mark_document_state_dirty()
			return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
		}
		else {}
	}
	record := host.record(value, .signal)!
	signal := unsafe { &dom.AbortSignal(record.native) }
	match op {
		'aborted' { return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, signal.aborted()) }
		'reason' { return host.value(signal.reason().as_webidl_value()!) }
		'throw' { signal.throw_if_aborted()!; return C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
		'onabort-get' { return host.runtime.javascript_event_handler(unsafe { &dom.EventTarget(signal) }, 'abort') }
		'onabort-set' {
			host.runtime.set_javascript_event_handler(unsafe { &dom.EventTarget(signal) }, 'abort', parameter)!
			return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
		}
		else { return error('TypeError: Unknown AbortSignal operation') }
	}
}

const abort_signal_native_bootstrap = r'(function(operate){
 const define=Object.defineProperty,create=Object.create,setPrototypeOf=Object.setPrototypeOf,EventTarget=globalThis.EventTarget,TypeError=globalThis.TypeError,ConstructProxy=Proxy;
 const AbortSignal=new ConstructProxy(function AbortSignal(){throw new TypeError("AbortSignal constructor requires new")},{construct(){throw new TypeError("Illegal constructor")}});
 AbortSignal.prototype=create(EventTarget.prototype);setPrototypeOf(AbortSignal,EventTarget);
 define(AbortSignal.prototype,"constructor",{value:AbortSignal,writable:true,configurable:true});
 const AbortController=new ConstructProxy(function AbortController(){throw new TypeError("AbortController constructor requires new")},{construct(target,args,newTarget){const prototype=newTarget.prototype;return operate("construct",prototype)}});
 define(AbortController.prototype,"constructor",{value:AbortController,writable:true,configurable:true});
 define(AbortController.prototype,"signal",{get:function(){return operate("signal",this)},enumerable:true,configurable:true});
 define(AbortController.prototype,"abort",{value:function abort(reason){return operate("abort",this,reason)},writable:true,enumerable:true,configurable:true});
 for(const name of ["aborted","reason"])define(AbortSignal.prototype,name,{get:function(){return operate(name,this)},enumerable:true,configurable:true});
 define(AbortSignal.prototype,"throwIfAborted",{value:function throwIfAborted(){return operate("throw",this)},writable:true,enumerable:true,configurable:true});
 define(AbortSignal.prototype,"onabort",{get:function(){return operate("onabort-get",this)},set:function(value){operate("onabort-set",this,value)},enumerable:true,configurable:true});
 define(AbortSignal,"abort",{value:function abort(reason){return operate("abort-static",reason)},writable:true,enumerable:true,configurable:true});
 define(AbortSignal,"timeout",{value:function timeout(milliseconds){if(arguments.length<1)throw new TypeError("AbortSignal.timeout requires 1 argument");return operate("timeout",+milliseconds)},writable:true,enumerable:true,configurable:true});
 define(AbortSignal,"any",{value:function any(signals){if(arguments.length<1)throw new TypeError("AbortSignal.any requires 1 argument");if((typeof signals!=="object"||signals===null)&&typeof signals!=="function")throw new TypeError("AbortSignal.any requires an iterable object");let sequence=[],index=0;for(const signal of signals){operate("validate",signal);define(sequence,index++,{value:signal,enumerable:true,writable:true,configurable:true})}return operate("any",sequence)},writable:true,enumerable:true,configurable:true});
 define(AbortController.prototype.abort,"length",{value:0,configurable:true});define(AbortSignal.abort,"length",{value:0,configurable:true});
 for(const [name,ctor] of [["AbortSignal",AbortSignal],["AbortController",AbortController]]){
  define(ctor,"prototype",{writable:false});define(ctor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  define(globalThis,name,{value:ctor,writable:true,configurable:true});
 }
 return [AbortSignal.prototype,AbortController.prototype]
})'
