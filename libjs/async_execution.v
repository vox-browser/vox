// SPDX-License-Identifier: BSD-2-Clause
module libjs

// AsyncFunctionStart/Await, using this port's instruction-index execution
// contexts. Suspended frames live outside the bounded interpreter stack; each
// resumption acquires a fresh checked stack frame and keeps the saved scopes.
@[heap]
struct AsyncExecution {
	capability &JSPromiseCapability
	realm &Realm
mut:
	context ?&ExecutionContext
	fulfilled Value
	rejected Value
	done bool
}

fn (mut function ECMAScriptFunction) call_async(mut vm VM, this_value Value, arguments []Value) !Value {
	capability := new_promise_capability(mut vm, Value.from_object(function.realm_.promise_constructor_record()))!
	mut execution := &AsyncExecution{capability: capability, realm: function.realm_}
	returned := function.call_body(mut vm, this_value, arguments, js_undefined(), none, execution) or {
		if !is_throw_completion(err) { return err }
		execution.complete(mut vm, thrown_value(err), true)!
		return capability.promise
	}
	if !returned.is_special_empty_value() { execution.complete(mut vm, returned, false)! }
	return capability.promise
}

fn (mut execution AsyncExecution) complete(mut vm VM, value Value, rejected bool) ! {
	if execution.done { return }
	execution.done = true
	execution.context = none
	call(mut vm, if rejected { execution.capability.reject } else { execution.capability.resolve }, js_undefined(), [value])!
}

fn (mut execution AsyncExecution) suspend(mut vm VM, mut frame ExecutionContext, value Value) ! {
	promise_value := promise_resolve(mut vm, Value.from_object(execution.realm.promise_constructor_record()), value)!
	mut promise := promise_value.as_object().promise_record or { return error('Await PromiseResolve did not produce a Promise') }
	frame.frame_initialized = true
	frame.yield_is_await = true
	mut saved := frame.copy()
	saved.program_counter = frame.program_counter + 1
	execution.context = saved
	if execution.fulfilled.is_undefined() {
		owner := &execution
		execution.fulfilled = Value.from_object(NativeFunction.create(mut vm, execution.realm, execution.realm.function_prototype, fn [owner] (mut vm VM) !Value {
			mut execution := unsafe { &AsyncExecution(owner) }
			return execution.resume(mut vm, vm.argument(0), false)
		}, 1, PropertyName.from_str(''), none).object)
		execution.rejected = Value.from_object(NativeFunction.create(mut vm, execution.realm, execution.realm.function_prototype, fn [owner] (mut vm VM) !Value {
			mut execution := unsafe { &AsyncExecution(owner) }
			return execution.resume(mut vm, vm.argument(0), true)
		}, 1, PropertyName.from_str(''), none).object)
	}
	perform_promise_then(mut vm, mut promise, execution.fulfilled, execution.rejected, unsafe { nil })
}

fn (mut execution AsyncExecution) resume(mut vm VM, value Value, rejected bool) !Value {
	if execution.done { return js_undefined() }
	returned := execution.resume_body(mut vm, value, rejected) or {
		if !is_throw_completion(err) { return err }
		execution.complete(mut vm, thrown_value(err), true)!
		return js_undefined()
	}
	if !returned.is_special_empty_value() { execution.complete(mut vm, returned, false)! }
	return js_undefined()
}

fn (mut execution AsyncExecution) resume_body(mut vm VM, value Value, rejected bool) !Value {
	saved := execution.context or { return error('Async continuation has no suspended frame') }
	executable := saved.executable or { return error('Async continuation has no executable') }
	mut stack := vm.interpreter_stack()
	mark := stack.top()
	mut frame := stack.allocate(executable.registers_and_locals_count, executable.constants, saved.argument_count) or {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	defer { stack.deallocate(mark) }
	offset, id := frame.stack_offset, frame.frame_id
	unsafe { *frame = *saved }
	frame.stack_offset = offset
	frame.frame_id = id
	frame.stack_allocated = true
	frame.async_resuming = true
	frame.yield_is_await = false
	frame.async_resume_value = value
	frame.async_resume_rejected = rejected
	execution.context = none
	vm.push_execution_context_checked(mut frame)!
	defer { vm.pop_current_context() }
	returned := vm.run_executable(mut frame, executable, saved.program_counter, ExecutionLimits{})!
	return if frame.yield_is_await { js_special_empty_value() } else { returned }
}
