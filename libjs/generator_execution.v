// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Generator.cpp / Rust generate_yield_expression. A generator owns its saved
// frame rather than holding a reservation in the bounded interpreter stack.
enum GeneratorState { suspended_start suspended_yield executing completed }
enum GeneratorResumeKind { normal return_ throw_ }

@[heap]
pub struct GeneratorExecution {
	realm &Realm
mut:
	function ?&ECMAScriptFunction
	state GeneratorState
	context ?&ExecutionContext
}

fn (mut execution GeneratorExecution) suspend(mut frame ExecutionContext, state GeneratorState) {
	frame.frame_initialized = true
	frame.yield_continuation = frame.program_counter + 1
	mut saved := frame.copy()
	saved.program_counter = frame.yield_continuation
	execution.context = saved
	execution.state = state
}

fn (mut execution GeneratorExecution) resume(mut vm VM, value Value, kind GeneratorResumeKind) !Value {
	outer := vm.run_executable_depth == 0 && vm.external_budget_depth == 0
	vm.external_budget_depth++
	defer {
		if outer { vm.run_queued_promise_jobs() }
		vm.external_budget_depth--
	}
	if execution.state == .executing { return vm.throw_error(.type_error, 'Generator is already executing') }
	if execution.state == .suspended_start && kind != .normal {
		execution.state = .completed
		execution.context = none
	}
	if execution.state == .completed {
		if kind == .throw_ { return throw_completion(value) }
		return Value.from_object(create_iterator_result_object(vm.realm(), if kind == .return_ { value } else { js_undefined() }, true, vm.realm().object_prototype))
	}
	execution.state = .executing
	returned := execution.resume_frame(mut vm, value, kind) or {
		execution.state = .completed
		execution.context = none
		return err
	}
	done := execution.state != .suspended_yield
	if !done {
		if saved := execution.context {
			if saved.yield_value_is_iterator_result { return returned }
		}
	}
	if done { execution.state = .completed; execution.context = none }
	return Value.from_object(create_iterator_result_object(vm.realm(), returned, done, vm.realm().object_prototype))
}

fn (mut execution GeneratorExecution) resume_frame(mut vm VM, value Value, kind GeneratorResumeKind) !Value {
	saved := execution.context or { return error('Generator has no suspended frame') }
	executable := saved.executable or { return error('Generator has no executable') }
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
	frame.generator_resuming = true
	frame.generator_resume_kind = kind
	frame.generator_resume_value = value
	frame.yield_continuation = no_yield_continuation
	execution.context = none
	vm.push_execution_context_checked(mut frame)!
	defer { vm.pop_execution_context() }
	return vm.run_executable(mut frame, executable, saved.program_counter, ExecutionLimits{})
}

fn (mut generator BytecodeGenerator) yield_expression(mut vm VM, expression &Expression) !Operand {
	if !generator.generator_function { return generator.unsupported('yield outside a synchronous generator') }
	value := if argument := expression.kind.argument { generator.expression(mut vm, argument)! } else { generator.constant(js_undefined()) }
	if expression.kind.is_yield_from { return generator.yield_from_expression(mut vm, value) }
	generator.emit(Instruction{op: .yield_value, lhs: value})
	received := generator.temporary()
	kind := generator.temporary()
	generator.emit(Instruction{op: .get_generator_resume_value, dst: received})
	generator.emit(Instruction{op: .get_generator_resume_kind, dst: kind})
	throwing := generator.temporary()
	generator.emit(Instruction{op: .strict_equals, dst: throwing, lhs: kind, rhs: generator.constant(Value.from_i32(i32(GeneratorResumeKind.throw_)))})
	not_throw := generator.emit(Instruction{op: .jump_if_false, lhs: throwing})
	generator.emit(Instruction{op: .throw_op, lhs: received})
	generator.patch(not_throw)
	returning := generator.temporary()
	generator.emit(Instruction{op: .strict_equals, dst: returning, lhs: kind, rhs: generator.constant(Value.from_i32(i32(GeneratorResumeKind.return_)))})
	not_return := generator.emit(Instruction{op: .jump_if_false, lhs: returning})
	generator.emit_return(received)
	generator.patch(not_return)
	return received
}
