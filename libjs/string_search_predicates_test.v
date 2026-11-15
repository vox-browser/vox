// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn search_predicate_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'string-search-predicates.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_string_search_predicates_positions_defaults_generic_receivers_and_utf16() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert search_predicate_eval(mut vm, '"hello friends".includes("hello")&&!"hello friends".includes("hello",100)&&"hello friends".includes("friends",6)&&"hello friends".startsWith("friends",6)&&"hello friends".endsWith("hello",5)&&"hello false 10 undefined".includes(false)&&"hello false 10 undefined".includes(10)&&"hello false 10 undefined".includes()')!.as_bool()
	assert search_predicate_eval(mut vm, '"😀".includes("\\ud83d")&&"😀".includes("\\ude00",1)&&"😀".startsWith("\\ude00",1)&&"😀".endsWith("\\ud83d",1)&&"😀".endsWith("\\ude00")&&!"😀".startsWith("😀",1)')!.as_bool()
	assert search_predicate_eval(mut vm, '"abc".includes("",Infinity)&&!"abc".includes("a",Infinity)&&"abc".includes("a",-Infinity)&&"abc".startsWith("a",NaN)&&"abc".endsWith("c",Infinity)&&!"abc".endsWith("a",-Infinity)&&"abc".endsWith("",-Infinity)&&"abc".endsWith("c",undefined)&&"abc".startsWith("b",1.9)&&String.prototype.includes.call(12345,34)&&String.prototype.endsWith.call(12345,45)')!.as_bool()
}

fn test_string_search_predicates_regexp_detection_precedes_needle_and_position_conversion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for name in ['includes', 'startsWith', 'endsWith'] {
		assert search_predicate_eval(mut vm, 'var n=0;try{"abc".'+name+'(/a/)}catch(e){if(e instanceof TypeError)n++}var r=/a/;Object.defineProperty(r,Symbol.match,{value:undefined,configurable:true});try{"abc".'+name+'(r)}catch(e){if(e instanceof TypeError)n++}var fake={};fake[Symbol.match]=true;try{"abc".'+name+'(fake)}catch(e){if(e instanceof TypeError)n++}Object.defineProperty(r,Symbol.match,{value:false,configurable:true});r.toString=function(){return "abc"};n===3&&"abc".'+name+'(r)')!.as_bool()
	}
}

fn test_string_search_predicates_coercion_order_original_throws_and_null_receivers() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for name in ['includes', 'startsWith', 'endsWith'] {
		assert search_predicate_eval(mut vm, 'var log="",receiver={},needle={},position={},marker={};receiver[Symbol.toPrimitive]=function(h){log+="r"+h;return "abc"};Object.defineProperty(needle,Symbol.match,{get(){log+="m";return false}});needle[Symbol.toPrimitive]=function(h){log+="n"+h;return "a"};position[Symbol.toPrimitive]=function(h){log+="p"+h;throw marker};var caught=false;try{String.prototype.'+name+'.call(receiver,needle,position)}catch(e){caught=e===marker}caught&&log==="rstringmnstringpnumber"')!.as_bool()
		assert search_predicate_eval(mut vm, 'log="";var count=0;for(var receiver of [null,undefined])try{String.prototype.'+name+'.call(receiver,needle,position)}catch(e){if(e instanceof TypeError)count++}count===2&&log===""')!.as_bool()
	}
}

fn test_string_search_predicate_intrinsic_metadata_and_symbol_errors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert search_predicate_eval(mut vm, 'var ok=true,n=0;for(var name of ["includes","startsWith","endsWith"]){var d=Object.getOwnPropertyDescriptor(String.prototype,name);ok=ok&&d.value.length===1&&d.value.name===name&&d.writable&&d.configurable&&!d.enumerable;try{"abc"[name](Symbol())}catch(e){if(e instanceof TypeError)n++}}ok&&n===3')!.as_bool()
}

fn test_cached_string_search_predicate_executes_in_fresh_vm_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-string-search-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert search_predicate_eval(mut vm, 'function search(s){return s.includes("popover")&&s.startsWith(":")&&s.endsWith("open")}search(":popover-open")')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
