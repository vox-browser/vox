// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn array_sort_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-sort-intrinsic.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100000})
}

fn test_installed_array_sort_is_stable_preserves_holes_and_returns_same_receiver() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert array_sort_eval(mut vm, 'var a=[3,undefined,,1,2];a.sort()===a&&a[0]===1&&a[1]===2&&a[2]===3&&a[3]===undefined&&!(4 in a)&&a.length===5')!.as_bool()
	assert array_sort_eval(mut vm, 'var a=[{key:1,id:"a"},{key:0,id:"b"},{key:1,id:"c"}];a.sort((x,y)=>x.key-y.key).map(x=>x.id).join("")==="bac"')!.as_bool()
}

fn test_array_sort_validates_comparator_before_length_and_preserves_abrupt_identity() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert array_sort_eval(mut vm, 'var reads=0,object={get length(){reads++;throw 1}},caught=false;try{Array.prototype.sort.call(object,null)}catch(e){caught=e instanceof TypeError}caught&&reads===0')!.as_bool()
	assert array_sort_eval(mut vm, 'var marker={},a=[2,1],same=false;try{a.sort(()=>{throw marker})}catch(e){same=e===marker}same&&a[0]===2&&a[1]===1')!.as_bool()
}
