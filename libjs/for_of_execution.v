// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Rust bytecode/codegen.rs::generate_for_in_of_statement's synchronous branch.
// Cleanup stubs live outside the loop's protected body. An IteratorClose error
// therefore reaches surrounding handlers, rather than a catch inside the body.
struct LoopReturnExit {
	jump        u32
	value       Operand
	scope_depth int
}

fn (mut generator BytecodeGenerator) emit_return(value Operand) {
	mut iterator := -1
	for i := generator.loops.len - 1; i >= 0; i-- {
		if generator.loops[i].iterator != none {
			iterator = i
			break
		}
	}
	if generator.finalizers.len > 0 {
		last := generator.finalizers.len - 1
		if iterator < generator.finalizers[last].loop_depth {
			jump := generator.emit(Instruction{op: .jump})
			generator.finalizers[last].returns << LoopReturnExit{jump: jump, value: value, scope_depth: generator.scope_depth}
			return
		}
	}
	if iterator >= 0 {
		jump := generator.emit(Instruction{op: .jump})
		generator.loops[iterator].returns << LoopReturnExit{jump: jump, value: value, scope_depth: generator.scope_depth}
		return
	}
	generator.emit(Instruction{ op: .end, lhs: value })
}

fn (mut generator BytecodeGenerator) for_of_statement(mut vm VM, statement &Statement) ! {
	kind := statement.kind
	lhs := kind.for_in_of_lhs or { return error('Missing for-of target') }
	mut lexical := false
	if lhs is ForInOfLhsDeclaration {
		declaration := lhs.statement
		if declaration.kind.declarations.len != 1 {
			return error('Invalid for-of declaration count')
		}
		lexical = declaration.kind.decl_kind != .var_kind
		if lexical {
			generator.emit(Instruction{ op: .enter_scope })
			generator.scope_depth++
			generator.lexical_declarations([*declaration], false)!
		}
	} else if lhs is ForInOfLhsPattern {
		return generator.unsupported('for-of destructuring assignment')
	}
	value := generator.expression(mut vm, kind.rhs or { return error('Missing for-of value') })!
	if lexical {
		generator.scope_depth--
		generator.emit(Instruction{ op: .leave_scope })
	}
	generator.clear_completion()
	iterator := generator.temporary()
	generator.emit(Instruction{ op: .get_sync_iterator, dst: iterator, lhs: value })
	start := u32(generator.executable.instructions.len)
	item := generator.temporary()
	finished := generator.emit(Instruction{ op: .sync_iterator_next, dst: item, lhs: iterator })
	base_depth := generator.scope_depth
	if lhs is ForInOfLhsDeclaration {
		if lexical {
			generator.emit(Instruction{ op: .enter_scope })
			generator.scope_depth++
			generator.lexical_declarations([*lhs.statement], false)!
		}
		generator.initialize_declaration_target(mut vm, lhs.statement.kind.declarations[0].target, item, lexical)!
	} else if lhs is ForInOfLhsExpression {
		target := lhs.expression
		if target.kind.tag == .member {
			base, property := generator.member_reference(mut vm, target)!
			generator.emit(Instruction{ op: .put_property, lhs: base, rhs: property, src: item, strict: generator.strict })
		} else {
			name := identifier_name(target) or { return generator.unsupported('for-of assignment target') }
			generator.emit(Instruction{ op: .set_variable, lhs: item, identifier: generator.identifier(name), strict: generator.strict })
		}
	}
	generator.loops << BytecodeLoop{ scope_depth: base_depth, iterator: iterator }
	generator.statement(mut vm, kind.body or { return error('Missing for-of body') })!
	loop := generator.loops.pop()
	if lexical {
		generator.scope_depth--
		generator.emit(Instruction{ op: .leave_scope })
	}
	generator.emit(Instruction{ op: .jump, target: start })
	end := u32(generator.executable.instructions.len)
	close := u32(generator.executable.instructions.len)
	generator.emit(Instruction{ op: .close_sync_iterator, lhs: iterator })
	closed := generator.emit(Instruction{ op: .jump })
	catch_start := u32(generator.executable.instructions.len)
	caught := generator.temporary()
	generator.emit(Instruction{ op: .catch_op, dst: caught })
	generator.emit(Instruction{ op: .close_sync_iterator_throw, lhs: iterator, rhs: caught })
	generator.emit(Instruction{ op: .throw_op, lhs: caught })
	for exit in loop.returns {
		generator.patch(exit.jump)
		for _ in base_depth .. exit.scope_depth { generator.emit(Instruction{ op: .leave_scope }) }
		generator.emit(Instruction{ op: .close_sync_iterator, lhs: iterator })
		generator.emit_return(exit.value)
	}
	for exit in loop.abrupts {
		generator.patch(exit.jump)
		for _ in base_depth .. exit.scope_depth { generator.emit(Instruction{ op: .leave_scope }) }
		generator.emit(Instruction{ op: .close_sync_iterator, lhs: iterator })
		generator.emit_loop_control(exit.target_loop, exit.target_label, exit.is_continue)!
	}
	generator.patch(finished)
	generator.patch(closed)
	for jump in loop.breaks { generator.executable.instructions[jump].target = close }
	for jump in loop.continues { generator.executable.instructions[jump].target = start }
	generator.protect_range(start, end, catch_start, base_depth)
}
