// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn settled_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'promise-all-settled.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100000})
}

fn test_all_settled_preserves_input_order_and_original_rejection_values() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	settled_eval(mut vm, 'var marker={},result,empty;Promise.allSettled([Promise.resolve(42),Promise.reject(marker),undefined]).then(v=>result=v);Promise.allSettled([]).then(v=>empty=v)')!
	assert settled_eval(mut vm, 'result.length===3&&result[0].status==="fulfilled"&&result[0].value===42&&result[1].status==="rejected"&&result[1].reason===marker&&result[2].status==="fulfilled"&&result[2].value===undefined&&Object.keys(result[1]).join(":")==="status:reason"&&empty.length===0')!.as_bool()
}

fn test_all_settled_handlers_share_a_once_record_for_custom_thenables() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	settled_eval(mut vm, 'class P extends Promise{}P.resolve=x=>({then(yes,no){no(x);yes(99);no(100)}});var value,result=P.allSettled([1,2]);result.then(v=>value=v)')!
	assert settled_eval(mut vm, 'result instanceof P&&value.length===2&&value[0].reason===1&&value[1].reason===2&&value[0].status==="rejected"&&value[1].status==="rejected"')!.as_bool()
}
