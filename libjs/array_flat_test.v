// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn flat_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-flat.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_flat_defaults_depth_zero_infinity_and_sparse_nested_arrays() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert flat_eval(mut vm, 'var a=[1,,[2,,[3,,[4]]]],one=a.flat();one.length===3&&one[0]===1&&one[1]===2&&one[2][0]===3&&one[2][2][0]===4&&a.flat(Infinity).join(":")==="1:2:3:4"')!.as_bool()
	assert flat_eval(mut vm, 'var a=[1,,[2]];var zero=a.flat(-1);zero.length===2&&zero[1]===a[2]&&a.flat(NaN)[1]===a[2]&&a.flat(1.9).join(":")==="1:2"')!.as_bool()
}

fn test_flat_snapshots_length_before_depth_conversion_and_observes_later_properties() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert flat_eval(mut vm, 'var log="",source={get length(){log+="length;";return 2},0:[20],1:[22]},depth={valueOf(){log+="depth;";source[2]=[99];return 1}};Array.prototype.flat.call(source,depth).join(":")==="20:22"&&log==="length;depth;"')!.as_bool()
	assert flat_eval(mut vm, 'var child=[1,,3];Object.defineProperty(child,"0",{get(){child[1]=2;delete child[2];return 1}});[child].flat().join(":")==="1:2"')!.as_bool()
}

fn test_flat_uses_species_and_ignores_array_like_concat_spreadability() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert flat_eval(mut vm, 'var size=-1;function Result(n){size=n}class A extends Array{static get [Symbol.species](){return Result}}var a=new A([20],[22]),out=a.flat();out instanceof Result&&size===0&&out[0]+out[1]===42&&!Object.hasOwn(out,"length")')!.as_bool()
	assert flat_eval(mut vm, 'var object={0:42,length:1};object[Symbol.isConcatSpreadable]=true;var a=[object];a.flat()[0]===object&&a.flat().length===1')!.as_bool()
}

fn test_flat_shares_execution_budget_and_recovers_from_cyclic_infinite_depth() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	flat_eval(mut vm, 'var cyclic=[];cyclic[0]=cyclic')!
	mut script := Script.parse('cyclic.flat(Infinity)', vm.realm(), 'flat-budget.js', unsafe { nil })!
	vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100}) or {
		assert thrown_value(err).as_object().error_message()?.contains('instruction budget')
		assert flat_eval(mut vm, '6*7')!.number == 42
		return
	}
	assert false, 'Recursive flattening must consume the caller execution budget'
}
