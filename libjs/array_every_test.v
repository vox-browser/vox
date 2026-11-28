// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn every_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-every.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:10000})
}

fn test_every_skips_holes_observes_mutation_and_stops_before_later_getters() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert every_eval(mut vm, 'var calls="",a=[1,,3,4],receiver={};var ok=a.every(function(v,i,o){if(this!==receiver||o!==a)throw 1;calls+=i;if(i===0){a[1]=2;delete a[2]}return true},receiver);ok&&calls==="013"&&[].every(()=>false)')!.as_bool()
	assert every_eval(mut vm, 'var a={0:1,get 1(){throw 99},length:2};Array.prototype.every.call(a,()=>false)===false')!.as_bool()
}

fn test_every_validates_callback_for_empty_arrays_without_species_access() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert every_eval(mut vm, 'var n=0,a=[];Object.defineProperty(a,"constructor",{get(){throw 99}});try{a.every(null)}catch(e){if(e instanceof TypeError)n++}n===1&&a.every(()=>true)')!.as_bool()
}
