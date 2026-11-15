// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn json_stringify_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'json-stringify.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 200000})
}

fn test_json_stringify_primitives_omitted_values_holes_and_number_formatting() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert json_stringify_eval(mut vm, r'JSON.stringify.length===3&&JSON.stringify()===undefined&&JSON.stringify(undefined)===undefined&&JSON.stringify(Symbol())===undefined&&JSON.stringify(function(){})===undefined&&JSON.stringify(null)==="null"&&JSON.stringify(true)==="true"&&JSON.stringify(-0)==="0"&&JSON.stringify([NaN,Infinity,-Infinity,1e21,1e-7])==="[null,null,null,1e+21,1e-7]"')!.as_bool()
	assert json_stringify_eval(mut vm, r'JSON.stringify([undefined,,function(){},Symbol()])==="[null,null,null,null]"&&JSON.stringify({a:undefined,b:function(){},c:Symbol(),answer:42})==="{\"answer\":42}"')!.as_bool()
	assert json_stringify_eval(mut vm, r'Array.prototype[1]=42;var result=JSON.stringify([1,,3]);delete Array.prototype[1];result==="[1,42,3]"')!.as_bool()
}

fn test_json_stringify_quotes_code_units_without_losing_surrogates_or_control_characters() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert json_stringify_eval(mut vm, r'var text="\"\\\b\f\n\r\t\u0000\u001f/\ud800\udc00\ud800\udc01\udfff\u2028\u2029",encoded=JSON.stringify(text);JSON.parse(encoded)===text&&JSON.stringify("\ud800")==="\"\\ud800\""&&JSON.stringify("\udc00")==="\"\\udc00\""&&JSON.stringify("😀")==="\"😀\""&&encoded.includes("\\u0000")&&encoded.includes("\\u001f")&&!encoded.includes("\\/")')!.as_bool()
	assert json_stringify_eval(mut vm, r'var value={};value["\ud800"]=1;value["\ud801"]=2;var copy=JSON.parse(JSON.stringify(value));copy["\ud800"]===1&&copy["\ud801"]===2&&Object.keys(copy).length===2')!.as_bool()
}

fn test_json_stringify_to_json_and_replacer_are_interleaved_with_original_receivers() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert json_stringify_eval(mut vm, r'var log=[],source={a:{toJSON(k){if(this!==source.a)throw 1;log.push("j:"+k);return {z:1}}}},root;var result=JSON.stringify(source,function(k,v){log.push("r:"+k);if(k===""){root=this;if(this[k]!==source)throw 2}if(k==="a"&&this!==source)throw 3;return v});result==="{\"a\":{\"z\":1}}"&&log.join()==="r:,j:a,r:a,r:z"&&Object.getPrototypeOf(root)===Object.prototype')!.as_bool()
	assert json_stringify_eval(mut vm, r'JSON.stringify(undefined,(k,v)=>k===""?42:v)==="42"&&JSON.stringify({toJSON(){return {ignored:1}}},(k,v)=>k===""?{answer:42}:v)==="{\"answer\":42}"&&JSON.stringify(new Date(0))==="\"1970-01-01T00:00:00.000Z\""&&JSON.stringify(new Date(NaN))==="null"')!.as_bool()
}

fn test_json_stringify_property_lists_convert_dedupe_and_include_inherited_non_enumerable_keys() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert json_stringify_eval(mut vm, r'var object=Object.create({inherited:7});object.a=1;object[1]=2;Object.defineProperty(object,"hidden",{value:42});var list=[new String("hidden"),"inherited",1,"1","a","a",true,null,Symbol()];JSON.stringify(object,list)==="{\"hidden\":42,\"inherited\":7,\"1\":2,\"a\":1}"&&JSON.stringify({a:1},[])==="{}"&&JSON.stringify([1,2],[])==="[1,2]"')!.as_bool()
	assert json_stringify_eval(mut vm, r'var log="",list=new Proxy(["b","a","b"],{get(t,k,r){log+=k+";";return Reflect.get(t,k,r)}});JSON.stringify({a:1,b:2},list)==="{\"b\":2,\"a\":1}"&&log==="length;0;1;2;"')!.as_bool()
}

fn test_json_stringify_indentation_clamps_and_preserves_utf16_gap_units() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert json_stringify_eval(mut vm, r'JSON.stringify({a:[1,{}],empty:[]},null,2)==="{\n  \"a\": [\n    1,\n    {}\n  ],\n  \"empty\": []\n}"&&JSON.stringify({a:1},null,Infinity)==="{\n          \"a\": 1\n}"&&JSON.stringify({a:1},null,-1)==="{\"a\":1}"')!.as_bool()
	assert json_stringify_eval(mut vm, r'var space=new String("unused"),calls=0;space.toString=function(){calls++;return "abcdefghijk"};JSON.stringify({x:1},null,space)==="{\nabcdefghij\"x\": 1\n}"&&calls===1&&JSON.stringify({},null,2)==="{}"&&JSON.stringify([],null,2)==="[]"')!.as_bool()
}

fn test_json_stringify_unboxes_only_primitive_wrappers_and_allows_bigint_hooks() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert json_stringify_eval(mut vm, r'var n=new Number(1),s=new String("old"),b=new Boolean(true);n.valueOf=function(){return 42};s.toString=function(){return "new"};b.valueOf=function(){throw 1};JSON.stringify([n,s,b,Object(Symbol())])==="[42,\"new\",true,{}]"')!.as_bool()
	assert json_stringify_eval(mut vm, r'var errors=0;for(var value of [1n,Object(2n),{x:3n}])try{JSON.stringify(value)}catch(e){if(e instanceof TypeError)errors++}var text=JSON.stringify({x:3n},(k,v)=>typeof v==="bigint"?v.toString():v);BigInt.prototype.toJSON=function(k){return k+":"+this.toString()};var hooked=JSON.stringify({x:4n});delete BigInt.prototype.toJSON;errors===3&&text==="{\"x\":\"3\"}"&&hooked==="{\"x\":\"x:4\"}"')!.as_bool()
}

fn test_json_stringify_snapshots_keys_and_array_length_but_gets_live_values() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert json_stringify_eval(mut vm, r'var object={get a(){delete object.b;object.c=3;return 1},b:2};JSON.stringify(object)==="{\"a\":1}"')!.as_bool()
	assert json_stringify_eval(mut vm, r'var array=[1,2,3];JSON.stringify(array,function(k,v){if(k==="0"){array.length=1;array[3]=4}return v})==="[1,null,null]"')!.as_bool()
}

fn test_json_stringify_proxies_use_checked_reflection_and_property_lists_skip_enumeration() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert json_stringify_eval(mut vm, r'var log="",p=new Proxy({a:1,b:2},{ownKeys(){log+="keys;";return ["b","a"]},getOwnPropertyDescriptor(t,k){log+="desc:"+k+";";return Reflect.getOwnPropertyDescriptor(t,k)},get(t,k,r){log+="get:"+k+";";return Reflect.get(t,k,r)}});JSON.stringify(p)==="{\"b\":2,\"a\":1}"&&log==="get:toJSON;keys;desc:b;desc:a;get:b;get:a;"')!.as_bool()
	assert json_stringify_eval(mut vm, r'var p=new Proxy({a:42},{ownKeys(){throw 1},getOwnPropertyDescriptor(){throw 2}});JSON.stringify(p,["a"])==="{\"a\":42}"&&JSON.stringify(new Proxy([1,,3],{}))==="[1,null,3]"')!.as_bool()
}

fn test_json_stringify_rejects_cycles_but_allows_shared_children_and_reentrant_calls() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert json_stringify_eval(mut vm, r'var object={a:1};object.self=object;var array=[];array.push(array);var errors=0;for(var value of [object,array])try{JSON.stringify(value)}catch(e){if(e instanceof TypeError)errors++}var child={n:42};errors===2&&JSON.stringify([child,child])==="[{\"n\":42},{\"n\":42}]"&&JSON.stringify(object,(k,v)=>k==="self"?undefined:v)==="{\"a\":1}"')!.as_bool()
	assert json_stringify_eval(mut vm, r'JSON.stringify({toJSON(){return JSON.stringify({answer:42})}})==="\"{\\\"answer\\\":42}\""')!.as_bool()
}

fn test_json_stringify_preserves_original_hook_exceptions_and_shares_the_instruction_budget() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert json_stringify_eval(mut vm, r'var marker={},errors=0;for(var f of [()=>JSON.stringify({get a(){throw marker}}),()=>JSON.stringify({toJSON(){throw marker}}),()=>JSON.stringify({},()=>{throw marker}),()=>JSON.stringify(new Proxy({},{ownKeys(){throw marker}}))])try{f()}catch(e){if(e===marker)errors++}errors===4')!.as_bool()
	mut script := Script.parse('JSON.stringify(new Proxy([], {get(t,k){return k==="length"?9007199254740991:undefined}}))', vm.realm(), 'json-budget.js', unsafe { nil })!
	if _ := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100}) { assert false }
	else { assert thrown_value(err).as_object().error_message()?.contains('instruction budget') }
	assert json_stringify_eval(mut vm, 'JSON.stringify({answer:42})')!.as_string().str() == '{"answer":42}'
	assert vm.proxy_operation_depth == 0 && vm.interpreter_stack().depth() == 0
}

fn test_json_stringify_executes_through_reused_native_code_without_a_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-json-stringify-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert json_stringify_eval(mut vm, r'function serialize(value){return JSON.stringify(value,(k,v)=>typeof v==="bigint"?v.toString():v)}serialize({answer:42,large:1n})==="{\"answer\":42,\"large\":\"1\"}"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}

fn test_json_stringify_charges_budget_for_surrogate_pairs_after_an_odd_length_prefix() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	json_stringify_eval(mut vm, 'var longText="x"+"😀".repeat(10000)')!
	mut script := Script.parse('JSON.stringify(longText)', vm.realm(), 'json-surrogate-budget.js', unsafe { nil })!
	if _ := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100}) { assert false }
	else { assert thrown_value(err).as_object().error_message()?.contains('instruction budget') }
	assert json_stringify_eval(mut vm, 'JSON.stringify("x😀")')!.as_string().str() == '"x😀"'
}
