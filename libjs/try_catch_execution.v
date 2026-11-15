// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Rust bytecode/codegen.rs::generate_try_statement, synchronous catch path.
// The V stream flattens protected ranges and restores lexical environments by
// scope depth; it does not share upstream's packed bytecode/environment cells.
fn (mut generator BytecodeGenerator) try_catch_statement(mut vm VM,statement &Statement) ! {
	data := statement.kind.try_data or { return error('Missing try statement') }
	if finalizer := data.finalizer { return generator.try_finally_statement(mut vm, data, &finalizer) }
	generator.try_catch_body(mut vm, data)!
}

fn (mut generator BytecodeGenerator) try_catch_body(mut vm VM, data &TryStatementData) ! {
	handler := data.handler or {
		generator.clear_completion()
		generator.statement(mut vm, &data.block)!
		return
	}
	generator.clear_completion()
	depth := generator.scope_depth
	start := u32(generator.executable.instructions.len)
	generator.statement(mut vm,&data.block)!
	end := u32(generator.executable.instructions.len)
	finished := generator.emit(Instruction{op:.jump})
	catch_start := u32(generator.executable.instructions.len)
	caught := generator.temporary()
	generator.emit(Instruction{op:.catch_op,dst:caught})
	generator.clear_completion()
	if parameter := handler.parameter {
		generator.emit(Instruction{op:.enter_scope})
		generator.scope_depth++
		if parameter is CatchBindingIdentifier {
			identifier := generator.identifier(parameter.identifier.name)
			generator.emit(Instruction{op:.create_mutable_binding,identifier:identifier})
			generator.emit(Instruction{op:.initialize_binding,identifier:identifier,lhs:caught})
		} else {
			pattern := (parameter as CatchBindingPattern).pattern
			mut names := []Utf16String{}
			collect_pattern_names(pattern, mut names)
			for name in names { generator.emit(Instruction{op: .create_mutable_binding, identifier: generator.identifier(name)}) }
			generator.binding_pattern(mut vm, pattern, caught, true)!
		}
	}
	generator.statement(mut vm,&handler.body)!
	if handler.parameter!=none {
		generator.scope_depth--
		generator.emit(Instruction{op:.leave_scope})
	}
	generator.patch(finished)
	generator.protect_range(start, end, catch_start, depth)
}

fn (mut generator BytecodeGenerator) protect_range(start u32, end u32, catch_start u32, depth int) {
	// Inner handlers already own their protected intervals. Fill the remaining
	// intervals with the outer handler, including inner catch bodies.
	mut protected := generator.executable.exception_handlers.clone()
	protected.sort(a.start_offset<b.start_offset)
	mut cursor := start
	for entry in protected {
		if entry.end_offset<=start || entry.start_offset>=end { continue }
		if cursor<entry.start_offset { generator.executable.exception_handlers << ExceptionHandlers{start_offset:cursor,end_offset:entry.start_offset,handler_offset:catch_start,catches_exception:true,restore_scope_depth:u32(depth)} }
		if entry.end_offset>cursor { cursor=entry.end_offset }
	}
	if cursor<end { generator.executable.exception_handlers << ExceptionHandlers{start_offset:cursor,end_offset:end,handler_offset:catch_start,catches_exception:true,restore_scope_depth:u32(depth)} }
	generator.executable.exception_handlers.sort(a.start_offset<b.start_offset)
}
