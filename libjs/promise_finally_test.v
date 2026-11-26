// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn finally_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'promise-finally.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100000})
}

fn test_promise_finally_preserves_values_and_reasons_and_waits_for_cleanup() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	finally_eval(mut vm, 'var value,reason,marker={},order="",release;var cleanup=new Promise(r=>release=r);Promise.resolve(42).finally(function(){"use strict";if(this!==undefined||arguments.length!==0)throw 1;order+="f";return cleanup}).then(v=>{value=v;order+="v"});Promise.reject(marker).finally(()=>7).catch(e=>reason=e)')!
	assert finally_eval(mut vm, 'order==="f"&&value===undefined&&reason===marker')!.as_bool()
	finally_eval(mut vm, 'release()')!
	assert finally_eval(mut vm, 'value===42&&order==="fv"')!.as_bool()
}

fn test_promise_finally_cleanup_errors_replace_original_settlement_and_noncallables_pass_through() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	finally_eval(mut vm, 'var marker={},a,b,c,d;Promise.resolve(1).finally(()=>{throw marker}).catch(e=>a=e);Promise.reject(2).finally(()=>Promise.reject(marker)).catch(e=>b=e);Promise.resolve(42).finally(7).then(v=>c=v);Promise.reject(marker).finally(null).catch(e=>d=e)')!
	assert finally_eval(mut vm, 'a===marker&&b===marker&&c===42&&d===marker')!.as_bool()
}

fn test_promise_finally_generic_receiver_observes_species_and_then_arguments() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert finally_eval(mut vm, 'var order="",receiver={get constructor(){order+="c";return {[Symbol.species]:Promise}},get then(){order+="t";return function(a,b){return this===receiver&&a===7&&b===7}}};Promise.prototype.finally.call(receiver,7)&&order==="ct"')!.as_bool()
	finally_eval(mut vm, 'class P extends Promise{}var result=P.resolve(42).finally(()=>1),seen;result.then(v=>seen=v)')!
	assert finally_eval(mut vm, 'result instanceof P&&seen===42')!.as_bool()
}
