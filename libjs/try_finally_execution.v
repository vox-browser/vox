// SPDX-License-Identifier: BSD-2-Clause
module libjs

struct BytecodeFinally {
	scope_depth int
	loop_depth int
	label_depth int
mut:
	returns []LoopReturnExit
	abrupts []LoopAbruptExit
}

// Rust bytecode/codegen.rs::generate_try_statement's FinallyContext, adapted to
// instruction indices. One body receives a saved completion type and value;
// its own abrupt completion overrides the pending one. Monotonic registers keep
// those values independent of Catch and live across an async suspension.
fn (mut generator BytecodeGenerator) try_finally_statement(mut vm VM, data &TryStatementData, finalizer &Statement) ! {
	depth := generator.scope_depth
	status := generator.temporary()
	value := generator.temporary()
	generator.finalizers << BytecodeFinally{scope_depth: depth, loop_depth: generator.loops.len, label_depth: generator.labels.len}
	start := u32(generator.executable.instructions.len)
	generator.try_catch_body(mut vm, data)!
	end := u32(generator.executable.instructions.len)
	context := generator.finalizers.pop()
	generator.emit(Instruction{op: .mov, dst: value, lhs: generator.completion_value()})
	generator.emit(Instruction{op: .mov, dst: status, lhs: generator.constant(Value.from_i32(0))})
	mut entries := [generator.emit(Instruction{op: .jump})]

	catch_start := u32(generator.executable.instructions.len)
	generator.emit(Instruction{op: .catch_op, dst: value})
	generator.emit(Instruction{op: .mov, dst: status, lhs: generator.constant(Value.from_i32(1))})
	entries << generator.emit(Instruction{op: .jump})
	for exit in context.returns {
		generator.patch(exit.jump)
		for _ in depth .. exit.scope_depth { generator.emit(Instruction{op: .leave_scope}) }
		generator.emit(Instruction{op: .mov, dst: value, lhs: exit.value})
		generator.emit(Instruction{op: .mov, dst: status, lhs: generator.constant(Value.from_i32(2))})
		entries << generator.emit(Instruction{op: .jump})
	}
	for index, exit in context.abrupts {
		generator.patch(exit.jump)
		for _ in depth .. exit.scope_depth { generator.emit(Instruction{op: .leave_scope}) }
		generator.emit(Instruction{op: .mov, dst: value, lhs: generator.completion_value()})
		generator.emit(Instruction{op: .mov, dst: status, lhs: generator.constant(Value.from_i32(i32(index + 3)))})
		entries << generator.emit(Instruction{op: .jump})
	}
	for jump in entries { generator.patch(jump) }
	generator.protect_range(start, end, catch_start, depth)
	// Finalizer completion is separate from the saved try/catch completion.
	generator.clear_completion()
	generator.statement(mut vm, finalizer)!
	mut dispatch := []u32{}
	for index in 0 .. context.abrupts.len + 2 {
		is_case := generator.temporary()
		generator.emit(Instruction{op: .strict_equals, dst: is_case, lhs: status, rhs: generator.constant(Value.from_i32(i32(index + 1)))})
		dispatch << generator.emit(Instruction{op: .jump_if_true, lhs: is_case})
	}
	generator.emit(Instruction{op: .mov, dst: Operand.register(register_accumulator), lhs: value})
	finished := generator.emit(Instruction{op: .jump})
	generator.patch(dispatch[0])
	generator.emit(Instruction{op: .throw_op, lhs: value})
	generator.patch(dispatch[1])
	generator.emit_return(value)
	for index, exit in context.abrupts {
		generator.patch(dispatch[index + 2])
		generator.emit(Instruction{op: .mov, dst: Operand.register(register_accumulator), lhs: value})
		generator.emit_loop_control(exit.target_loop, exit.target_label, exit.is_continue)!
	}
	generator.patch(finished)
}
