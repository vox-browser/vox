module browserjs

import dom
import html
import webidl


pub fn (mut host AnimationFrameHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	if host.installed {
		if voidptr(host.runtime) != voidptr(&runtime) {
			return error('AnimationFrameProvider already belongs to another runtime')
		}
		return
	}
	host.runtime = &runtime
	host_handle := voidptr(&host)
	operation := runtime.make_value_host_function(fn [host_handle] (_ voidptr, arguments []voidptr) !voidptr {
		mut host := unsafe { &AnimationFrameHost(host_handle) }
		return host.operate(arguments) or {
			host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	installer := runtime.evaluate_host_value(animation_frame_host_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		operation,
	])!
	runtime.add_close_handler(fn [host_handle] () {
		mut host := unsafe { &AnimationFrameHost(host_handle) }
		host.close()
	})
	host.installed = true
}

fn (mut host AnimationFrameHost) finish(record &AnimationFrameHostRecord) {
	host.records.delete(record.handle)
	host.runtime.release_javascript_value(record.function)
}

fn (mut host AnimationFrameHost) replay_callback() ! {
	if replay := host.replay { replay(host.runtime)! }
}

fn (mut host AnimationFrameHost) report(exception IError) {
	mut realm := unsafe { &html.ScriptingRealm(host.settings.realm()) }
	if exception is JavaScriptValueException {
		value := host.runtime.webidl_value(exception.value) or { return }
		html.report_exception(dom.js_webidl_value(value), mut realm)
		return
	}
	html.report_exception(dom.js_webidl_value(webidl.exception_value(exception)), mut realm)
}

fn (mut host AnimationFrameHost) operate(arguments []voidptr) !voidptr {
	if host.closed { return error('AnimationFrameProvider binding is closed') }
	if arguments.len != 2 { return error('TypeError: Invalid AnimationFrameProvider operation') }
	op := host.runtime.binding_dom_string(arguments[0])!
	mut window := unsafe { &html.WindowModel(host.window) }
	if op == 'cancel' {
		mut exception := unsafe { nil }
		number := C.vox_jsc_JSValueToNumber(host.runtime.context, arguments[1], &exception)
		if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
		id := u32(webidl.convert_to_int(webidl.number_value(number), 32, false, .no, .no)!)
		pending := window.has_pending_animation_frame_callback(id)
		window.cancel_animation_frame(id)
		if pending {
			if record := host.records[id] { host.finish(record) }
		}
		return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
	}
	if op != 'request' { return error('TypeError: Invalid AnimationFrameProvider operation') }
	host_handle := voidptr(&host)
	function := arguments[1]
	callback := host.runtime.webidl_callback(function, fn [host_handle] (value webidl.Value) !voidptr {
		host := unsafe { &AnimationFrameHost(host_handle) }
		return match value.kind {
			.undefined { C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
			.number { C.vox_jsc_JSValueMakeNumber(host.runtime.context, value.number_value) }
			else { host.runtime.actual_webidl_value(value)! }
		}
	})!
	mut record := &AnimationFrameHostRecord{
		function: function
	}
	record.handle = window.request_animation_frame(fn [host_handle, record, callback] (now f64) {
		mut host := unsafe { &AnimationFrameHost(host_handle) }
		// The driver can already hold an executing snapshot when the realm closes.
		if host.closed || host.runtime.closed { return }
		defer { host.finish(record) }
		// Window.cpp: undefined receiver, synchronous InvokeCallback, no Promise
		// Resolve/then access. Report the original abrupt completion and continue.
		result := webidl.invoke_callback(callback, none, [webidl.number_value(now)]) or {
			host.replay_callback() or {}
			host.report(err)
			return
		}
		if actual := result.runtime_value_ { host.runtime.release_javascript_value(actual.value) }
		host.replay_callback() or { host.report(err) }
	})
	host.records[record.handle] = record
	return C.vox_jsc_JSValueMakeNumber(host.runtime.context, record.handle)
}

// AnimationFrameProvider.idl: required callable callback, unsigned-long handle,
// and the actual Window global receiver. ToNumber runs before native transport,
// preserving author conversion exceptions and rejecting BigInt/Symbol values.
const animation_frame_host_bootstrap = r'(function(operate){
 "use strict";
 const global=globalThis,define=Object.defineProperty,TypeError=global.TypeError;
 function receiver(value){if(value!==undefined&&value!==null&&value!==global)throw new TypeError("AnimationFrameProvider requires a Window receiver")}
 function requestAnimationFrame(callback){receiver(this);if(arguments.length<1)throw new TypeError("requestAnimationFrame requires 1 argument");if(typeof callback!=="function")throw new TypeError("FrameRequestCallback is not callable");return operate("request",callback)}
 function cancelAnimationFrame(handle){receiver(this);if(arguments.length<1)throw new TypeError("cancelAnimationFrame requires 1 argument");return operate("cancel",+handle)}
 for(const [name,method] of [["requestAnimationFrame",requestAnimationFrame],["cancelAnimationFrame",cancelAnimationFrame]])define(global,name,{value:method,writable:true,enumerable:true,configurable:true});
})'
