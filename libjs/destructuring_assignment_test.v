// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn destructuring_assignment_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'assignment-patterns.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_assignment_patterns_return_rhs_once_and_store_nested_defaults_rest_and_symbols() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert destructuring_assignment_eval(mut vm, 'let x,y,rest,calls=0;var original={a:20,b:{},keep:7};function source(){calls++;return original}var result=({a:x,b:{c:y=22},...rest}=source());result===original&&calls===1&&x+y===42&&rest.keep===7&&!("a" in rest)&&!("b" in rest)')!.as_bool()
	assert destructuring_assignment_eval(mut vm, 'let first,tail;[first,,...tail]="A😀BC";first==="A"&&tail.length===2&&tail[0]==="B"&&tail[1]==="C"')!.as_bool()
	assert destructuring_assignment_eval(mut vm, 'var symbol=Symbol("pick"),source2={a:1};source2[symbol]=42;let picked,remainder;({[symbol]:picked,...remainder}=source2);picked===42&&remainder.a===1&&!(symbol in remainder)')!.as_bool()
	assert destructuring_assignment_eval(mut vm, 'let f,g;[f=function(){return 42}]=[];({missing:g=()=>42}={});f.name==="f"&&g.name==="g"&&f()+g()===84')!.as_bool()
}

fn test_object_assignment_prepares_member_before_getter_default_and_deferred_key_coercion() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert destructuring_assignment_eval(mut vm, 'var log="",stored=0,target={set value(v){log+="set;";stored=v}},key={toString(){log+="coerce;";return "value"}},source={get x(){log+="get;";return undefined}};function base(){log+="base;";return target}({[(log+="source-key;","x")]:base()[(log+="target-key;",key)]=(log+="default;",42)}=source);stored===42&&log==="source-key;base;target-key;get;default;coerce;set;"')!.as_bool()
	assert destructuring_assignment_eval(mut vm, 'log="";var target2={},source3={get x(){log+="get;";return 42}};function restBase(){log+="base;";return target2}({...restBase().copy}=source3);target2.copy.x===42&&log==="base;get;"')!.as_bool()
}

fn test_assignment_keeps_original_identifier_reference_across_source_side_effects() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert destructuring_assignment_eval(mut vm, '"use strict";var source={get value(){Object.defineProperty(globalThis,"lateAssignment",{value:0,writable:true,configurable:true});return 42}},caught=false;try{({value:lateAssignment}=source)}catch(e){caught=e instanceof ReferenceError}caught&&globalThis.lateAssignment===0')!.as_bool()
	assert destructuring_assignment_eval(mut vm, 'var reads=0,rejected=false;try{const fixed=1;({a:fixed,b:ignored}={get a(){reads++;return 42},get b(){reads++;return 2}})}catch(e){rejected=e instanceof TypeError}rejected&&reads===1')!.as_bool()
}

fn test_array_assignment_prepares_targets_before_next_and_rest_collection() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert destructuring_assignment_eval(mut vm, 'var log="",n=0,target={},source={};source[Symbol.iterator]=function(){log+="iterator;";return {next(){n++;log+="next"+n+";";return {done:n>2,value:n*21}},return(){log+="close;";return {}}}};function base(){log+="base;";return target}[base().first,...base().rest]=source;target.first===21&&target.rest.length===1&&target.rest[0]===42&&log==="iterator;base;next1;base;next2;next3;"')!.as_bool()
	assert destructuring_assignment_eval(mut vm, 'var reads=0,closed=0,elided={};elided[Symbol.iterator]=function(){return {next(){return {done:false,get value(){reads++;throw 1}}},return(){closed++;return {}}}};[,]=elided;reads===0&&closed===1')!.as_bool()
}

fn test_array_assignment_closes_on_target_errors_and_preserves_original_exception() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert destructuring_assignment_eval(mut vm, 'var closed=0,nexts=0,marker={},source={};source[Symbol.iterator]=function(){return {next(){nexts++;return {value:42}},return(){closed++;throw 9}}};function fail(){throw marker}var same=false;try{[fail().value]=source}catch(e){same=e===marker}same&&nexts===0&&closed===1')!.as_bool()
	assert destructuring_assignment_eval(mut vm, 'closed=0;var target={set value(v){throw marker}};try{[target.value]=source}catch(e){same=e===marker}same&&closed===1&&nexts===1')!.as_bool()
	assert destructuring_assignment_eval(mut vm, 'closed=0;source[Symbol.iterator]=function(){return {next(){throw marker},return(){closed++;return {}}}};let value;try{[value]=source}catch(e){same=e===marker}same&&closed===0')!.as_bool()
}

fn test_assignment_patterns_in_for_in_and_for_of_resolve_outer_lexical_bindings() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert destructuring_assignment_eval(mut vm, 'let result=0;{let result=1;for(result of [20,42]){}if(result!==42)throw 1}result===0')!.as_bool()
	assert destructuring_assignment_eval(mut vm, 'let a=0,b=0;for([a,b=22] of [[20]]){}a+b===42')!.as_bool()
	assert destructuring_assignment_eval(mut vm, 'let size=0,letter="";for({length:size,0:letter} in {ab:1}){}size===2&&letter==="a"')!.as_bool()
	assert destructuring_assignment_eval(mut vm, 'let outer="";{let outer="";for(outer in {answer:1}){}if(outer!=="answer")throw 1}outer===""')!.as_bool()
}

fn test_assignment_patterns_support_private_and_super_targets_with_actual_receiver() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert destructuring_assignment_eval(mut vm, 'class A{set value(v){this.saved=v}}class B extends A{#value=0;run(){({x:this.#value}={x:20});[super.value]=[22];for(this.#value of [21]){}for(super.value of [21]){}return this.#value+this.saved}}new B().run()===42')!.as_bool()
}

fn test_cached_assignment_patterns_reuse_native_code_with_compiler_disabled() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-assignment-patterns-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert destructuring_assignment_eval(mut vm, 'let left,right,rest;function run(){({left,right=22,...rest}={left:20,keep:1});for([left,right] of [[left,right]]){}return left+right}run()===42&&rest.keep===1')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
