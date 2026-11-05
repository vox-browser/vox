module browserjs

import dom
import html
import math
import requestidlecallback
import time
import webidl

pub fn (mut host IdleCallbackHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	if host.installed {
		if voidptr(host.runtime) != voidptr(&runtime) {
			return error('requestIdleCallback already belongs to another runtime')
		}
		return
	}
	host.runtime = &runtime
	host_handle := voidptr(&host)
	operation := runtime.make_value_host_function(fn [host_handle] (_ voidptr, arguments []voidptr) !voidptr {
		mut host := unsafe { &IdleCallbackHost(host_handle) }
		return host.operate(arguments) or {
			host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	installer := runtime.evaluate_host_value(idle_callback_host_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		operation,
	])!
	runtime.add_close_handler(fn [host_handle] () {
		mut host := unsafe { &IdleCallbackHost(host_handle) }
		host.close()
	})
	host.installed = true
}

fn (mut host IdleCallbackHost) finish(record &IdleCallbackHostRecord) {
	host.records.delete(record.handle)
	host.runtime.release_javascript_value(record.function)
}

fn (mut host IdleCallbackHost) report(exception IError) {
	mut realm := unsafe { &html.ScriptingRealm(host.settings.realm()) }
	if exception is JavaScriptValueException {
		value := host.runtime.webidl_value(exception.value) or { return }
		html.report_exception(dom.js_webidl_value(value), mut realm)
		return
	}
	html.report_exception(dom.js_webidl_value(webidl.exception_value(exception)), mut realm)
}

// IdleDeadline.cpp::time_remaining: the deadline the event loop computes now,
// coarsened to whole milliseconds and never negative.
fn idle_callback_time_remaining() f64 {
	now := f64(time.sys_mono_now()) / 1_000_000.0
	remaining := html.main_thread_event_loop().compute_deadline() - now
	return if remaining < 0 { 0 } else { math.ceil(remaining) }
}

fn (mut host IdleCallbackHost) operate(arguments []voidptr) !voidptr {
	if host.closed { return error('requestIdleCallback binding is closed') }
	if arguments.len < 1 { return error('TypeError: Invalid IdleRequestCallback operation') }
	op := host.runtime.binding_dom_string(arguments[0])!
	mut window := unsafe { &html.WindowModel(host.window) }
	if op == 'remaining' {
		return C.vox_jsc_JSValueMakeNumber(host.runtime.context, idle_callback_time_remaining())
	}
	if arguments.len != 3 { return error('TypeError: Invalid IdleRequestCallback operation') }
	mut exception := unsafe { nil }
	number := C.vox_jsc_JSValueToNumber(host.runtime.context, arguments[2], &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	if op == 'cancel' {
		id := u32(webidl.convert_to_int(webidl.number_value(number), 32, false, .no, .no)!)
		window.cancel_idle_callback(id)
		if record := host.records[id] { host.finish(record) }
		return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
	}
	if op != 'request' { return error('TypeError: Invalid IdleRequestCallback operation') }
	timeout := u32(webidl.convert_to_int(webidl.number_value(number), 32, false, .no, .no)!)
	host_handle := voidptr(&host)
	function := arguments[1]
	callback := host.runtime.webidl_callback(function, fn [host_handle] (value webidl.Value) !voidptr {
		host := unsafe { &IdleCallbackHost(host_handle) }
		return match value.kind {
			.undefined { C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
			.boolean { C.vox_jsc_JSValueMakeBoolean(host.runtime.context, value.boolean_value) }
			.number { C.vox_jsc_JSValueMakeNumber(host.runtime.context, value.number_value) }
			else { host.runtime.actual_webidl_value(value)! }
		}
	})!
	mut record := &IdleCallbackHostRecord{
		function: function
	}
	record.handle = window.request_idle_callback(fn [host_handle, record, callback] (deadline requestidlecallback.IdleDeadline) ! {
		mut host := unsafe { &IdleCallbackHost(host_handle) }
		if host.closed || host.runtime.closed { return }
		defer { host.finish(record) }
		// The bootstrap wraps the author callback so it receives a fresh
		// IdleDeadline; the native side passes only didTimeout.
		result := webidl.invoke_callback(callback, none, [webidl.boolean_value(deadline.did_timeout())]) or {
			if replay := host.replay { replay(host.runtime) or {} }
			host.report(err)
			return
		}
		if actual := result.runtime_value_ { host.runtime.release_javascript_value(actual.value) }
		if replay := host.replay { replay(host.runtime) or { host.report(err) } }
	}, requestidlecallback.IdleRequestOptions{ timeout: timeout })
	host.records[record.handle] = record
	return C.vox_jsc_JSValueMakeNumber(host.runtime.context, record.handle)
}

// RequestIdleCallback.idl: a required callable callback, an optional
// IdleRequestOptions dictionary whose timeout is an unsigned long, and an
// IdleDeadline exposing timeRemaining() and didTimeout.
const idle_callback_host_bootstrap = r'(function(operate){
 "use strict";
 const global=globalThis,define=Object.defineProperty,TypeError=global.TypeError;
 function receiver(value){if(value!==undefined&&value!==null&&value!==global)throw new TypeError("requestIdleCallback requires a Window receiver")}
 function IdleDeadline(){throw new TypeError("Illegal constructor")}
 const timeouts=new WeakMap;
 define(IdleDeadline.prototype,"timeRemaining",{value:function timeRemaining(){if(!timeouts.has(this))throw new TypeError("Illegal invocation");return operate("remaining")},writable:true,enumerable:true,configurable:true});
 define(IdleDeadline.prototype,"didTimeout",{get:function(){if(!timeouts.has(this))throw new TypeError("Illegal invocation");return timeouts.get(this)},enumerable:true,configurable:true});
 define(IdleDeadline.prototype,Symbol.toStringTag,{value:"IdleDeadline",configurable:true});
 function requestIdleCallback(callback,options){receiver(this);if(arguments.length<1)throw new TypeError("requestIdleCallback requires 1 argument");if(typeof callback!=="function")throw new TypeError("IdleRequestCallback is not callable");
  let timeout=0;if(options!==undefined&&options!==null){if(typeof options!=="object"&&typeof options!=="function")throw new TypeError("IdleRequestOptions must be an object");const value=options.timeout;if(value!==undefined)timeout=Number(value)}
  if(!Number.isFinite(timeout)||timeout<0)timeout=0;
  return operate("request",function(didTimeout){const deadline=Object.create(IdleDeadline.prototype);timeouts.set(deadline,!!didTimeout);return callback.call(undefined,deadline)},timeout)}
 function cancelIdleCallback(handle){receiver(this);if(arguments.length<1)throw new TypeError("cancelIdleCallback requires 1 argument");operate("cancel",undefined,+handle)}
 define(global,"IdleDeadline",{value:IdleDeadline,writable:true,configurable:true});
 for(const [name,method] of [["requestIdleCallback",requestIdleCallback],["cancelIdleCallback",cancelIdleCallback]])define(global,name,{value:method,writable:true,enumerable:true,configurable:true});
})'
