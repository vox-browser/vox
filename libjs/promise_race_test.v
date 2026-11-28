// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn race_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'promise-race.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100000})
}

fn test_promise_race_keeps_first_settlement_and_empty_iterable_pending() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	race_eval(mut vm, 'var winner,reason,empty=false,marker={};Promise.race([Promise.resolve(42),Promise.reject(marker)]).then(v=>winner=v);Promise.race([Promise.reject(marker),Promise.resolve(42)]).catch(e=>reason=e);Promise.race([]).then(()=>empty=true,()=>empty=true)')!
	assert race_eval(mut vm, 'winner===42&&reason===marker&&!empty')!.as_bool()
}

fn test_promise_race_uses_custom_constructor_resolve_and_closes_abrupt_iterators() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	race_eval(mut vm, 'class P extends Promise{}var reads=0,seen=0,value;Object.defineProperty(P,"resolve",{get(){reads++;return function(x){seen++;return {then(resolve){resolve(x)}}}}});var p=P.race([1,2]);p.then(v=>value=v)')!
	assert race_eval(mut vm, 'p instanceof P&&reads===1&&seen===2&&value===1')!.as_bool()
	race_eval(mut vm, 'var marker={},closed=0,reason;class Q extends Promise{}Q.resolve=()=>{throw marker};Q.race({[Symbol.iterator](){return {next(){return {value:1,done:false}},return(){closed++;return {}}}}}).catch(e=>reason=e)')!
	assert race_eval(mut vm, 'closed===1&&reason===marker')!.as_bool()
}
