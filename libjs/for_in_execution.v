// SPDX-License-Identifier: BSD-2-Clause
module libjs

// codegen.rs::generate_for_in_of_statement, synchronous for-in branch. The
// inaccessible PropertyNameIterator needs no user-visible IteratorClose.
fn (mut generator BytecodeGenerator) for_in_statement(mut vm VM, statement &Statement) ! {
	kind := statement.kind
	if kind.for_in_of_kind != .for_in { return generator.unsupported('for-of loop') }
	lhs := kind.for_in_of_lhs or { return error('Missing for-in target') }
	mut lexical := false
	if lhs is ForInOfLhsDeclaration {
		declaration := lhs.statement
		if declaration.kind.declarations.len != 1 {
			return error('Invalid for-in declaration count')
		}
		lexical = declaration.kind.decl_kind != .var_kind
		if lexical {
			// Bound names are in TDZ while evaluating the RHS, independently of
			// the new environment created for each subsequent iteration.
			generator.emit(Instruction{ op: .enter_scope })
			generator.scope_depth++
			generator.lexical_declarations([*declaration], false)!
		} else if initializer := declaration.kind.declarations[0].init {
			value := generator.expression(mut vm, &initializer)!
			generator.initialize_declaration_target(mut vm, declaration.kind.declarations[0].target, value, false)!
		}
	} else if lhs is ForInOfLhsPattern {
		return generator.unsupported('for-in destructuring assignment')
	}
	value := generator.expression(mut vm, kind.rhs or { return error('Missing for-in value') })!
	if lexical {
		generator.scope_depth--
		generator.emit(Instruction{ op: .leave_scope })
	}
	generator.clear_completion()
	nullish := generator.emit(Instruction{ op: .jump_if_nullish, lhs: value })
	iterator := generator.temporary()
	generator.emit(Instruction{ op: .get_object_property_iterator, dst: iterator, lhs: value })
	start := u32(generator.executable.instructions.len)
	key := generator.temporary()
	finished := generator.emit(Instruction{ op: .property_name_iterator_next, dst: key, lhs: iterator })
	base_depth := generator.scope_depth
	if lhs is ForInOfLhsDeclaration {
		if lexical {
			generator.emit(Instruction{ op: .enter_scope })
			generator.scope_depth++
			generator.lexical_declarations([*lhs.statement], false)!
		}
		generator.initialize_declaration_target(mut vm, lhs.statement.kind.declarations[0].target, key, lexical)!
	} else if lhs is ForInOfLhsExpression {
		target := lhs.expression
		if target.kind.tag == .member {
			base, property := generator.member_reference(mut vm, target)!
			generator.emit(Instruction{ op: .put_property, lhs: base, rhs: property, src: key, strict: generator.strict })
		} else {
			name := identifier_name(target) or { return generator.unsupported('for-in assignment target') }
			generator.emit(Instruction{ op: .set_variable, lhs: key, identifier: generator.identifier(name), strict: generator.strict })
		}
	}
	generator.loops << BytecodeLoop{ scope_depth: base_depth }
	generator.statement(mut vm, kind.body or { return error('Missing for-in body') })!
	loop := generator.loops.pop()
	if lexical {
		generator.scope_depth--
		generator.emit(Instruction{ op: .leave_scope })
	}
	generator.emit(Instruction{ op: .jump, target: start })
	generator.patch(nullish)
	generator.patch(finished)
	for jump in loop.breaks { generator.patch(jump) }
	for jump in loop.continues { generator.executable.instructions[jump].target = start }
}
