module browserjs

import dom
import html
import streams
import webidl

fn test_native_generic_callback_invokes_when_callable_without_adding_caller_script_gate() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{value: 'https://callback-order.example.test/'}
	document := &dom.Document{url: url, origin_: url.origin()}
	mut host := WritableStreamHost.create(document)!
	host.install(mut runtime)!
	settings := host.settings
	owner_handle := voidptr(runtime)
	runtime.define_value_host_function('__actualGenericCallbackContext', fn [owner_handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		owner := unsafe { &Runtime(owner_handle) }
		assert !settings.realm().can_run
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return C.vox_jsc_JSValueMakeBoolean(owner.context, true)
	})!
	function := runtime.evaluate_host_value('globalThis.actualGenericCallbackCalls=0;(function(value){actualGenericCallbackCalls++;if(!__actualGenericCallbackContext())throw "missing context";return value})')!
	argument := runtime.webidl_value(runtime.evaluate_host_value('({actual:"argument"})')!)!
	callback := runtime.webidl_callback(function, fn [owner_handle] (value webidl.Value) !voidptr {
		owner := unsafe { &Runtime(owner_handle) }
		if value.kind == .undefined { return C.vox_jsc_JSValueMakeUndefined(owner.context) }
		return owner.actual_webidl_value(value)
	})!
	runtime.evaluate_host('globalThis.actualSizeCalls=0;globalThis.actualSizeWritable=new WritableStream({}, {size(){actualSizeCalls++;if(!__actualGenericCallbackContext())throw "missing size context";return 1}})')!
	mut native := runtime.native_writable_stream(runtime.evaluate_host_value('actualSizeWritable')!)!
	mut writer := native.get_writer()!
	mut realm := settings.realm()
	realm.can_run = false
	defer { realm.can_run = true }
	assert html.can_run_script_for_settings(settings) == .do_not_run
	result := webidl.invoke_callback(callback, webidl.undefined_value(), [argument])!
	assert runtime.actual_webidl_value(result)! == runtime.actual_webidl_value(argument)!
	request := writer.write(streams.runtime_value(argument))
	assert request.state() == .pending || request.state() == .fulfilled
	assert realm.script_execution_depth == 0 && realm.callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.evaluate_host('actualGenericCallbackCalls===1&&actualSizeCalls===1')! == 'true'
}
