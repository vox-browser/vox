// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn tagged_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'tagged.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})
}

fn test_tagged_templates_preserve_raw_cooked_invalid_escapes_and_uncoerced_values() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert tagged_eval(mut vm, 'var symbol=Symbol(),object={toString(){throw 1}},seen=false;function tag(s,a,b){seen=s.length===3&&s[0]==="line\\n"&&s.raw[0]==="line\\\\n"&&s[1]===""&&s[2]==="end"&&a===symbol&&b===object;return 42}tag`line\\n\${symbol}\${object}end`===42&&seen')!.as_bool()
	assert tagged_eval(mut vm, 'function invalid(s){return s[0]===undefined&&s.raw[0]==="\\\\unicode"&&s[1]===""&&s.raw[1]===""}invalid`\\unicode\${42}`')!.as_bool()
	assert tagged_eval(mut vm, 'function units(s){return s[0].charCodeAt(0)===55296&&s.raw[0]==="\\\\ud800"}units`\\ud800`&&((s)=>s.length===1&&s[0]===""&&s.raw[0]==="")``')!.as_bool()
}

fn test_tagged_template_objects_are_intrinsic_frozen_arrays_with_stable_site_identity() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert tagged_eval(mut vm, 'function tag(s){return s}function f(){return tag`same`}function g(){return tag`same`}function factory(){return ()=>tag`same`}var a=f(),b=factory()(),c=factory()(),raw=Object.getOwnPropertyDescriptor(a,"raw");a===f()&&a!==g()&&a!==b&&b===c&&Array.isArray(a)&&Array.isArray(a.raw)&&Object.getPrototypeOf(a)===Array.prototype&&Object.isFrozen(a)&&Object.isFrozen(a.raw)&&!raw.writable&&!raw.enumerable&&!raw.configurable&&!Object.getOwnPropertyDescriptor(a,"0").writable')!.as_bool()
	assert tagged_eval(mut vm, 'var array=Array,freeze=Object.freeze,setters=0;Array=function(){throw 1};Object.freeze=function(){throw 2};Object.defineProperty(array.prototype,"0",{set(){setters++},configurable:true});var a=tag`fresh`;delete array.prototype[0];Array=array;Object.freeze=freeze;a[0]==="fresh"&&setters===0&&Object.isFrozen(a)')!.as_bool()
}

fn test_tagged_template_calls_capture_method_receivers_and_evaluate_substitutions_in_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert tagged_eval(mut vm, 'var log="",owner={get tag(){log+="g";return function(s,a,b){if(this!==owner)throw 1;log+="t";return a+b}}};function value(n){log+=n;owner.tag=42;return n}owner.tag`a\${value(1)}b\${value(2)}c`===3&&log==="g12t"')!.as_bool()
	assert tagged_eval(mut vm, 'function tag(s){"use strict";if(this!==undefined)throw 1;return function(t){"use strict";return this===undefined&&s[0]==="a"&&t[0]==="b"}}tag`a``b`')!.as_bool()
	assert tagged_eval(mut vm, 'var marker={},same=false,touched=0;function tag(){touched=99}try{tag`a\${(()=>{throw marker})()}\${touched=1}`}catch(e){same=e===marker}same&&touched===0')!.as_bool()
	assert tagged_eval(mut vm, 'var f=42,touched=false,caught=false;try{f`\${touched=true}`}catch(e){caught=e instanceof TypeError}caught&&touched')!.as_bool()
	assert tagged_eval(mut vm, 'class A{#tag(s,v){return this.value+v}value=40;run(){return this.#tag`\${2}`}}new A().run()===42')!.as_bool()
}

fn test_tagged_site_identity_tracks_actual_parsed_source_and_current_realm() {
	text := 'function tag(s){return s}tag`same`'
	parsed := parse_source(text, .script)
	mut previous := unsafe { &Object(nil) }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mut first := Script{realm: vm.realm(), filename: 'shared.js', parsed: parsed}
		mut second := Script{realm: vm.realm(), filename: 'shared.js', parsed: parsed}
		object := vm.run_with_limits(mut first, ExecutionLimits{max_instructions: 10000})!.as_object()
		assert voidptr(vm.run_with_limits(mut second, ExecutionLimits{max_instructions: 10000})!.as_object()) == voidptr(object)
		assert voidptr(tagged_eval(mut vm, text)!.as_object()) != voidptr(object)
		if visit == 1 { assert voidptr(previous) != voidptr(object) }
		previous = object
	}
}

fn test_template_object_creation_shares_budget_and_await_preserves_template_operand() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	source := 'function tag(s){return s[0]}tag`' + 'x\${0}'.repeat(6000) + '`'
	if _ := tagged_eval(mut vm, source) { assert false }
	assert vm.realm().template_objects.len == 0
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
	assert tagged_eval(mut vm, 'tag`recovered`==="recovered"')!.as_bool()
	tagged_eval(mut vm, 'var result;function add(s,v){return s[0]+v+s[1]}async function f(){return add`a\${await Promise.resolve(42)}b`}f().then(v=>result=v)')!
	assert tagged_eval(mut vm, 'result==="a42b"')!.as_bool()
}

fn test_tagged_templates_execute_persisted_native_entries_without_compiler() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-tagged-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert tagged_eval(mut vm, 'function tag(s,v){return s[0]+v+s[1]}function f(x){return tag`a\${x}b`}f(42)==="a42b"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 3 && stats.compiler_invocations == 0 && activity.entries >= 3 }
		vm.close_native_code()!
	}
}
