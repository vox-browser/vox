// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn filter_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-filter.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:10000})
}

fn test_array_filter_observes_live_sparse_indices_and_retains_original_selected_values() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert filter_eval(mut vm, 'var a=[1,,3,4],seen=[],receiver={},out=a.filter(function(v,i,o){if(this!==receiver||o!==a)throw 1;seen.push(i);if(i===0){a[1]=2;delete a[2];a.push(99)}return v%2===0},receiver);seen.join(":")==="0:1:3"&&out.join(":")==="2:4"&&out.length===2')!.as_bool()
	assert filter_eval(mut vm, 'var source=Object.create({1:42});source.length=3;Array.prototype.filter.call(source,v=>v===42).join(":")==="42"')!.as_bool()
}

fn test_array_filter_species_receives_zero_and_defines_without_inherited_setters() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert filter_eval(mut vm, 'var length=-1,setters=0;function Result(n){length=n}Object.defineProperty(Result.prototype,"0",{set(){setters++},configurable:true});class A extends Array{static get [Symbol.species](){return Result}}var a=new A(1,2,3),r=a.filter(v=>v>1);r instanceof Result&&r[0]===2&&r[1]===3&&length===0&&setters===0')!.as_bool()
}
