// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn includes_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-includes.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:10000})
}

fn test_array_includes_uses_same_value_zero_holes_and_signed_from_index() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert includes_eval(mut vm, '[NaN].includes(NaN)&&[-0].includes(0)&&Array(2).includes(undefined)&&![1].includes("1")&&[1,2,3].includes(2,-2)&&![1,2,3].includes(1,-2)&&[1].includes(1,-Infinity)&&![1].includes(1,Infinity)')!.as_bool()
}

fn test_array_includes_gets_inherited_values_and_skips_from_index_conversion_for_empty_receiver() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert includes_eval(mut vm, 'var a=Object.create({1:42});a.length=2;var reads=0;a[0]=1;Array.prototype.includes.call(a,42)&&![].includes(1,{valueOf(){reads++;throw 1}})&&reads===0')!.as_bool()
}
