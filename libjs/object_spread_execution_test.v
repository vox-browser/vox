// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn object_spread_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'object-spread.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_object_spread_enumerable_own_values_symbols_order_and_data_descriptors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert object_spread_eval(mut vm, 'var symbol=Symbol("s"),source=Object.create({inherited:7}),reads=0;source[0]="zero";Object.defineProperty(source,"a",{get(){reads++;return this===source?42:0},enumerable:true});Object.defineProperty(source,"hidden",{value:9});source[symbol]=8;var result={before:1,...source,after:2},d=Object.getOwnPropertyDescriptor(result,"a");Object.keys(result).join(",")==="0,before,a,after"&&reads===1&&result.a===42&&result[symbol]===8&&!("inherited" in result)&&!("hidden" in result)&&d.value===42&&d.get===undefined&&d.writable&&d.enumerable&&d.configurable')!.as_bool()
	assert object_spread_eval(mut vm, 'var log="",a={get value(){log+="a";return 1}},b={get value(){log+="b";return 2}};var result={...a,value:3,...b,last:(log+="c")};result.value===2&&log==="abc"')!.as_bool()
}

fn test_object_spread_nullish_primitives_and_proto_key_do_not_invoke_setters() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert object_spread_eval(mut vm, 'var result={...null,...undefined,...42,...true,..."a😀"};Object.keys(result).join(",")==="0,1,2"&&result[0]==="a"&&result[1].charCodeAt(0)===55357&&result[2].charCodeAt(0)===56832')!.as_bool()
	assert object_spread_eval(mut vm, 'var base={get x(){throw 1},set y(v){throw 2}},source={x:20,y:22};Object.defineProperty(source,"__proto__",{value:"data",enumerable:true});var result={__proto__:base,...source};Object.getPrototypeOf(result)===base&&Object.getOwnPropertyDescriptor(result,"__proto__").value==="data"&&result.x+result.y===42')!.as_bool()
}

fn test_object_spread_snapshots_keys_but_rechecks_live_descriptors_and_original_throws() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert object_spread_eval(mut vm, 'var source={get a(){delete this.b;this.d=4;Object.defineProperty(this,"c",{enumerable:false});return 1},b:2,c:3};var result={...source};Object.keys(result).join(",")==="a"&&result.a===1&&source.d===4')!.as_bool()
	assert object_spread_eval(mut vm, 'var marker={},changed=0,source={get a(){throw marker}},caught=false;try{({before:(changed=1),...source,after:(changed=2)})}catch(e){caught=e===marker}caught&&changed===1')!.as_bool()
}

fn test_object_spread_properties_share_execution_budget_and_restore_vm_after_throw() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	object_spread_eval(mut vm, 'var source={};for(var i=0;i<100;i++)source["k"+i]=i')!
	mut script := Script.parse('({...source})', vm.realm(), 'object-spread-budget.js', unsafe { nil })!
	if _ := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 20}) { assert false }
	else { assert thrown_value(err).as_object().error_message()?.contains('instruction budget') }
	assert object_spread_eval(mut vm, '({...{value:42}}).value')!.number == 42
	assert vm.interpreter_stack().depth() == 0 && vm.execution_context_stack().len == 1
}

fn test_object_spread_cached_native_entry_runs_in_fresh_vm_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-object-spread-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert object_spread_eval(mut vm, 'function copy(value){return {...value,total:42}}var value=copy({a:20,b:22});value.a+value.b===value.total')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
