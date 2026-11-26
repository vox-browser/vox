// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn find_positions_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-find-positions.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:10000})
}

fn test_directional_array_search_visits_holes_with_snapshot_length_and_actual_receiver() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert find_positions_eval(mut vm, 'var a=[1,,3,4],order="",receiver={};a.findLastIndex(function(v,i,o){if(this!==receiver||o!==a)throw 1;order+=i;if(i===3)delete a[2];return v===undefined},receiver)===2&&order==="32"&&a.findIndex(v=>v===undefined)===1&&a.findLast(v=>v<4)===1&&[].findLastIndex(()=>true)===-1')!.as_bool()
	assert find_positions_eval(mut vm, '[1,2,3].at(-1)===3&&[1].at(-2)===undefined&&[].at(0)===undefined&&[1].at(Infinity)===undefined&&Array.prototype.at.call({0:42,length:1},0)===42')!.as_bool()
}
