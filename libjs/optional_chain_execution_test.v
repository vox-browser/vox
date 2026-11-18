// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn optional_chain_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'optional-chains.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_optional_chains_short_circuit_only_nullish_values_and_skip_entire_tails() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert optional_chain_eval(mut vm, 'var calls=0;var n=null;n?.[calls++]?.method(calls++).deep;calls')!.number == 0
	assert optional_chain_eval(mut vm, 'var u;u?.(calls++).field;calls')!.number == 0
	assert optional_chain_eval(mut vm, 'var a={x:{answer:42}};a?.x.answer+":"+a.x?.answer+":"+a.missing?.answer')!.as_string().str() == '42:42:undefined'
	assert optional_chain_eval(mut vm, 'var key={toString:function(){calls++;return "answer"}};var o={answer:42};o?.[key]+":"+calls+":"+(0?.missing)+":"+(false?.missing)')!.as_string().str() == '42:1:undefined:undefined'
	assert optional_chain_eval(mut vm, '"abc"?.length+":"+"abc"?.[1]')!.as_string().str() == '3:b'
	assert optional_chain_eval(mut vm, 'var count=0;function base(){count++;return {answer:42}};base()?.answer+count')!.number == 43
}

fn test_optional_calls_preserve_method_receivers_and_capture_them_before_arguments() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert optional_chain_eval(mut vm, 'var o={answer:42,method:function(){"use strict";return this.answer}};o?.method()+":"+o.method?.()+":"+(o?.method)()+":"+(o?.method)?.()')!.as_string().str() == '42:42:42:42'
	assert optional_chain_eval(mut vm, 'var saved=o;var receiver=o;receiver?.method(receiver=null)+":"+(receiver===null)+":"+saved?.["method"]()')!.as_string().str() == '42:true:42'
	assert optional_chain_eval(mut vm, 'var f=function(){"use strict";return this};f?.()===undefined && (0,o.method)?.call(o)===42')!.as_bool()
	assert optional_chain_eval(mut vm, 'var calls=0;var holder={};Object.defineProperty(holder,"m",{get:function(){calls++;return function(){"use strict";return this}}});holder.m?.()===holder && calls===1')!.as_bool()
	assert optional_chain_eval(mut vm, 'var nested={method:function(){return function(){"use strict";return this}}};nested?.method()()===undefined')!.as_bool()
}

fn test_retained_optional_chain_preserves_functions_in_the_base_and_references() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	closure := optional_chain_eval(mut vm, 'function make(){return function(input){return (()=>input)()?.[(()=>"method")()]?.(()=>2) ?? 7}};make()')!
	for _ in 0 .. 20 {
		assert optional_chain_eval(mut vm, '({item:1})?.["item"]')!.number == 1
	}
	receiver := optional_chain_eval(mut vm, '({answer:40,method:function(fn){return this.answer+fn()}})')!
	assert call(mut vm, closure, js_undefined(), [receiver])!.number == 42
	assert call(mut vm, closure, js_undefined(), [js_null()])!.number == 7
}

fn test_optional_chain_errors_grouping_and_getters_retain_normal_behavior() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for source in ['missing?.x', 'var o={a:null};o?.a.b', '(null?.x).y', '(null?.method)()',
		'var o={method:42};o.method?.()'] {
		optional_chain_eval(mut vm, source) or {
			kind := thrown_value(err).as_object().error_kind()?
			assert kind == .type_error || kind == .reference_error
			assert optional_chain_eval(mut vm, '6*7')!.number == 42
			continue
		}
		assert false, source
	}
	assert optional_chain_eval(mut vm, 'var object={};Object.defineProperty(object,"bad",{get:function(){throw 42}});try{object?.bad}catch(e){e}')!.number == 42
	assert optional_chain_eval(mut vm, 'var ignored=0;try{null?.a;({a:null})?.a[ignored++]}catch(e){};ignored')!.number == 1
}

fn test_optional_delete_skips_getters_and_preserves_strict_property_failures() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert optional_chain_eval(mut vm, 'var calls=0;var o={};Object.defineProperty(o,"x",{get:function(){calls++;return 42},configurable:true});(delete o?.x)+":"+calls+":"+Object.hasOwn(o,"x")+":"+(delete null?.[calls++])+":"+calls')!.as_string().str() == 'true:0:false:true:0'
	assert optional_chain_eval(mut vm, 'var x={method:function(){calls++;return 1}};(delete x?.method())+":"+calls+":"+Object.hasOwn(x,"method")')!.as_string().str() == 'true:1:true'
	assert optional_chain_eval(mut vm, 'var locked={};Object.defineProperty(locked,"x",{value:42});delete locked?.x')!.as_bool() == false
	assert optional_chain_eval(mut vm, 'var threw=false;function remove(){"use strict";return delete locked?.x};try{remove()}catch(e){threw=e instanceof TypeError};threw')!.as_bool()
}

fn test_optional_chains_run_in_modules_and_still_reject_invalid_assignment_syntax() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut record := SourceTextModule.parse('const o={answer:42};export const result=o?.answer;export default o.missing?.value;', vm.realm(), 'optional.mjs', unsafe { nil })!
	record.link(mut vm)!
	assert record.evaluate(mut vm)!.promise.state == .fulfilled
	assert record.export_value(mut vm, utf16_string('result'))!.number == 42
	assert record.export_value(mut vm, utf16_string('default'))!.is_undefined()
	Script.parse('var o={};o?.x=42;', vm.realm(), 'invalid-optional.js', unsafe { nil }) or {
		assert err is ScriptParseError
		return
	}
	assert false, 'Optional-chain assignment must remain a syntax error'
}
