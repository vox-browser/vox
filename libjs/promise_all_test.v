// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn all_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'promise-all.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100000})
}

fn test_promise_all_preserves_input_order_and_waits_for_every_value() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	all_eval(mut vm, 'var value,first,second;var a=new Promise(r=>first=r),b=new Promise(r=>second=r);Promise.all([a,2,b]).then(v=>value=v);second(3)')!
	assert all_eval(mut vm, 'value===undefined')!.as_bool()
	all_eval(mut vm, 'first(1)')!
	assert all_eval(mut vm, 'Array.isArray(value)&&value.join(":")==="1:2:3"')!.as_bool()
	all_eval(mut vm, 'var empty;Promise.all([]).then(v=>empty=v)')!
	assert all_eval(mut vm, 'Array.isArray(empty)&&empty.length===0')!.as_bool()
}

fn test_promise_all_rejects_with_original_values_and_converts_iterator_failures_to_rejection() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	all_eval(mut vm, 'var marker={},reason,bad;Promise.all([Promise.reject(marker),1]).catch(e=>reason=e);Promise.all(null).catch(e=>bad=e)')!
	assert all_eval(mut vm, 'reason===marker&&bad instanceof TypeError')!.as_bool()
}

fn test_promise_all_generic_thenables_are_guarded_once_per_element_and_use_constructor_resolve() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	all_eval(mut vm, 'class P extends Promise{}var reads=0,calls=0,result,value;Object.defineProperty(P,"resolve",{get(){reads++;return function(x){if(this!==P)throw 1;calls++;return {then(resolve){resolve(x);resolve(99)}}}}});result=P.all([1,2]);result.then(v=>value=v)')!
	assert all_eval(mut vm, 'result instanceof P&&reads===1&&calls===2&&value.join(":")==="1:2"')!.as_bool()
}

fn test_promise_all_closes_iterators_on_resolve_or_then_failures_but_not_step_failures() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	all_eval(mut vm, 'var marker={},closed=0,reason;class P extends Promise{}P.resolve=function(){throw marker};var source={[Symbol.iterator](){return {next(){return {value:1,done:false}},return(){closed++;throw 99}}}};P.all(source).catch(e=>reason=e)')!
	assert all_eval(mut vm, 'closed===1&&reason===marker')!.as_bool()
	all_eval(mut vm, 'var reason2,closed2=0;Promise.all({[Symbol.iterator](){return {next(){throw marker},return(){closed2++;return {}}}}}).catch(e=>reason2=e)')!
	assert all_eval(mut vm, 'closed2===0&&reason2===marker')!.as_bool()
}
