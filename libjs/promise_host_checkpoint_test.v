// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn checkpoint_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'promise-host-checkpoint.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})!
}

fn test_host_callback_finishes_native_work_before_getter_queued_jobs_run() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	checkpoint_eval(mut vm, 'var order="",o={get value(){order+="g";Promise.resolve().then(function(){order+="j"});return 42}}')!
	callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		mut global := vm.global_object()
		object := global.get(mut vm, PropertyName.from_str('o'))!.as_object()
		value := object.get(mut vm, PropertyName.from_str('value'))!
		previous := global.get(mut vm, PropertyName.from_str('order'))!.as_string().str()
		global.set(mut vm, PropertyName.from_str('order'), Value.from_string(vm.create_string_from_str(previous + 'n')), .yes)!
		return value
	}, 0, PropertyName.from_str('nativeCheckpoint'), none).object
	assert vm.call_with_limits(Value.from_object(callback), js_undefined(), [], ExecutionLimits{max_instructions: 1000})!.number == 42
	assert checkpoint_eval(mut vm, 'order')!.as_string().str() == 'gnj'
	assert vm.promise_job_count() == 0 && vm.take_promise_job_errors().len == 0
}

fn test_host_callback_drains_promise_jobs_after_throw_and_preserves_original_exception() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	function := checkpoint_eval(mut vm, 'var ran=false;function callback(){Promise.resolve().then(function(){ran=true});throw 42};callback')!
	if _ := vm.call_with_limits(function, js_undefined(), [], ExecutionLimits{max_instructions: 1000}) { assert false }
	else { assert is_throw_completion(err) && thrown_value(err).number == 42 }
	assert checkpoint_eval(mut vm, 'ran')!.as_bool()
}

fn test_unsupported_promise_callbacks_are_retained_for_embedding_diagnostics() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	checkpoint_eval(mut vm, 'Promise.resolve().then(async function(){})')!
	errors := vm.take_promise_job_errors()
	assert errors.len == 1 && errors[0].msg().contains('async function execution is not translated')
	assert vm.take_promise_job_errors().len == 0 && vm.promise_job_count() == 0
}

fn test_queued_job_exception_values_remain_heap_roots_until_diagnostics_are_taken() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	object := Object.create(vm.realm(), none)
	value := Value.from_object(object)
	vm.enqueue_promise_job(fn [value] () !Value { return throw_completion(value) }, none)
	vm.run_queued_promise_jobs()
	assert vm.heap_roots().contains(voidptr(object))
	errors := vm.take_promise_job_errors()
	assert errors.len == 1 && is_throw_completion(errors[0])
	assert voidptr(thrown_value(errors[0]).as_object()) == voidptr(object)
	assert !vm.heap_roots().contains(voidptr(object))
}
