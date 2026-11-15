// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn native_observation_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'native-promise-observation.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 200000})
}

fn test_internal_promise_observation_ignores_public_then_constructor_and_species() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	native_observation_eval(mut vm, 'var p=Promise.resolve(42),result=0,reads=0;function settled(v){result=v}Object.defineProperty(p,"then",{get(){reads++;throw 1}});Object.defineProperty(p,"constructor",{get(){reads++;throw 2}})')!
	promise := vm.global_object().get(mut vm, PropertyName.from_str('p'))!
	handler := vm.global_object().get(mut vm, PropertyName.from_str('settled'))!
	observe_promise_settlement(mut vm, promise, handler, js_undefined())!
	assert native_observation_eval(mut vm, 'result===0&&reads===0')!.as_bool()
	vm.run_queued_promise_jobs()
	assert native_observation_eval(mut vm, 'result===42&&reads===0')!.as_bool()
}

fn test_internal_promise_observation_keeps_fifo_with_ordinary_reactions() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	native_observation_eval(mut vm, 'var resolve,p=new Promise(r=>resolve=r),order=[];function first(){order.push("first")}function last(){order.push("last")}')!
	p := vm.global_object().get(mut vm, PropertyName.from_str('p'))!
	first := vm.global_object().get(mut vm, PropertyName.from_str('first'))!
	last := vm.global_object().get(mut vm, PropertyName.from_str('last'))!
	observe_promise_settlement(mut vm, p, first, js_undefined())!
	native_observation_eval(mut vm, 'p.then(()=>order.push("ordinary"))')!
	observe_promise_settlement(mut vm, p, last, js_undefined())!
	native_observation_eval(mut vm, 'resolve(1)')!
	assert native_observation_eval(mut vm, 'order.join()==="first,ordinary,last"')!.as_bool()
}

fn test_internal_promise_observation_preserves_rejected_value_identity() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	native_observation_eval(mut vm, 'var reject,p=new Promise((a,b)=>reject=b),marker=Symbol("native"),same=false;function failed(v){same=v===marker}')!
	p := vm.global_object().get(mut vm, PropertyName.from_str('p'))!
	handler := vm.global_object().get(mut vm, PropertyName.from_str('failed'))!
	observe_promise_settlement(mut vm, p, js_undefined(), handler)!
	native_observation_eval(mut vm, 'reject(marker)')!
	assert native_observation_eval(mut vm, 'same')!.as_bool()
	record := p.as_object().promise_record?
	assert record.is_handled
}

fn test_internal_promise_observation_rejects_non_promises_without_getters() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	native_observation_eval(mut vm, 'var reads=0,bad={get then(){reads++;throw 1}}')!
	bad := vm.global_object().get(mut vm, PropertyName.from_str('bad'))!
	mut failed := false
	observe_promise_settlement(mut vm, bad, js_undefined(), js_undefined()) or {
		failed = true
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert failed
	assert native_observation_eval(mut vm, 'reads===0')!.as_bool()
}
