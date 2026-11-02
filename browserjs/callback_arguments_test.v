module browserjs

fn test_small_callback_argument_lists_preserve_strict_receivers_values_and_arity() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	callback := runtime.evaluate_host_value('(function(){"use strict";return this===expectedReceiver&&arguments.length===expectedCount&&(arguments.length===0||arguments[0]===expectedValue)&&(arguments.length<2||arguments[1]===undefined)})')!
	value := runtime.evaluate_host_value('globalThis.expectedValue=Symbol("actual argument")')!
	undefined := runtime.evaluate_host_value('undefined')!
	for source in ['undefined', 'null', 'true', '42', '"receiver"', '1n', 'Symbol("receiver")', '({owner:true})', '(function(){})'] {
		receiver := runtime.evaluate_host_value('globalThis.expectedReceiver=${source}')!
		for count in 0 .. 3 {
			_ = runtime.evaluate_host('globalThis.expectedCount=${count}')!
			arguments := match count {
				0 { []voidptr{} }
				1 { [value] }
				else { [value, undefined] }
			}
			result := runtime.call_javascript_function(callback, receiver, arguments)!
			assert C.JSValueToBoolean(runtime.context, result)
		}
	}
}

fn test_small_callback_calls_keep_private_intrinsics_proxy_calls_and_original_exceptions() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	callback := runtime.evaluate_host_value(r'(globalThis.calls=[],new Proxy(function(){},{apply(target,receiver,args){calls.push([receiver,args.length,args[0]]);if(args[0]===reason)throw reason;return args.length}}))')!
	receiver := runtime.evaluate_host_value('globalThis.receiver=Symbol("proxy receiver")')!
	reason := runtime.evaluate_host_value('globalThis.reason=Object.freeze({original:true})')!
	_ = runtime.evaluate_host('Reflect.apply=()=>{throw "author apply"};globalThis.Array=function(){throw "author Array"};true')!
	assert js_string_to_v(runtime.context, runtime.call_javascript_function(callback, receiver, [])!)! == '0'
	if _ := runtime.call_javascript_function(callback, receiver, [reason]) {
		assert false
	} else {
		if err is JavaScriptValueException {
			assert err.value == reason
		} else {
			assert false
		}
	}
	assert runtime.evaluate_host('calls.length===2&&calls[0][0]===receiver&&calls[0][1]===0&&calls[0][2]===undefined&&calls[1][0]===receiver&&calls[1][1]===1&&calls[1][2]===reason')! == 'true'
	runtime.close()
	if _ := runtime.call_javascript_function(callback, receiver, []) {
		assert false
	} else {
		assert err.msg().contains('closed')
	}
}
