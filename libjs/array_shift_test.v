// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn shift_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-shift.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:10000})
}

fn test_shift_preserves_sparse_and_inherited_indices_and_mutates_real_length() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert shift_eval(mut vm, 'var a=[1,,3];a.shift()===1&&a.length===2&&!(0 in a)&&a[1]===3&&[].shift()===undefined')!.as_bool()
	assert shift_eval(mut vm, 'var a=Object.create({1:42});a[0]=1;a.length=2;Array.prototype.shift.call(a)===1&&a[0]===42&&a.length===1&&!Object.prototype.hasOwnProperty.call(a,"1")')!.as_bool()
}

fn test_shift_preserves_abrupt_getter_identity_before_mutation() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert shift_eval(mut vm, 'var marker={},a={get 0(){throw marker},length:2},same=false;try{Array.prototype.shift.call(a)}catch(e){same=e===marker}same&&a.length===2')!.as_bool()
}
