// SPDX-License-Identifier: BSD-2-Clause
module libjs

// DestructuringAssignmentEvaluation / Rust codegen.rs binding-pattern assignment
// mode. Resolve references before GetV/IteratorStepValue, then retain them across
// getters and default expressions. A declaration's InitializeBinding is distinct.
struct PreparedAssignmentTarget {
	is_binding bool
	binding Operand
	base Operand
	key Operand
	property_op OpCode = .put_property
	pattern ?BindingPattern
}

fn (mut generator BytecodeGenerator) prepare_identifier_assignment(name Utf16String) PreparedAssignmentTarget {
	reference := generator.temporary()
	generator.emit(Instruction{op: .get_binding_reference, dst: reference, identifier: generator.identifier(name), strict: generator.strict})
	return PreparedAssignmentTarget{is_binding: true, binding: reference}
}

fn (mut generator BytecodeGenerator) prepare_expression_assignment(mut vm VM, expression &Expression) !PreparedAssignmentTarget {
	if expression.kind.tag == .member {
		base, key := generator.member_reference(mut vm, expression)!
		return PreparedAssignmentTarget{base: base, key: key, property_op: member_property_opcode(expression, .put_property)}
	}
	if name := identifier_name(expression) { return generator.prepare_identifier_assignment(name) }
	return generator.unsupported('assignment target')
}

fn (mut generator BytecodeGenerator) prepare_assignment_entry(mut vm VM, entry BindingEntry) !PreparedAssignmentTarget {
	if pattern := entry.alias.binding_pattern { return PreparedAssignmentTarget{pattern: pattern} }
	if expression := entry.alias.expression { return generator.prepare_expression_assignment(mut vm, &expression) }
	if name := generator.binding_entry_name(entry) { return generator.prepare_identifier_assignment(name) }
	return error('Missing destructuring assignment target')
}

fn (mut generator BytecodeGenerator) store_assignment_target(mut vm VM, target PreparedAssignmentTarget, value Operand) ! {
	if pattern := target.pattern { return generator.assignment_pattern(mut vm, pattern, value) }
	if target.is_binding {
		generator.emit(Instruction{op: .put_binding_reference, lhs: target.binding, rhs: value})
	} else {
		generator.emit(Instruction{op: target.property_op, lhs: target.base, rhs: target.key, src: value, strict: generator.strict})
	}
}

fn (mut generator BytecodeGenerator) assignment_entry_default(mut vm VM, entry BindingEntry, value Operand) ! {
	if initializer := entry.initializer {
		missing := generator.temporary()
		generator.emit(Instruction{op: .strict_equals, dst: missing, lhs: value, rhs: generator.constant(js_undefined())})
		skip := generator.emit(Instruction{op: .jump_if_false, lhs: missing})
		mut initial := Operand{}
		if initializer.kind.tag == .function_expr && generator.executable.parsed_source.function_table.get(initializer.kind.function_id).name == none && generator.binding_entry_name(entry) != none {
			name := generator.binding_entry_name(entry) or { return error('Missing default assignment name') }
			initial = generator.temporary()
			generator.emit(Instruction{op: .new_function_with_name, dst: initial, identifier: initializer.kind.function_id.id, lhs: generator.constant(Value.from_string(vm.create_string(name)))})
		} else { initial = generator.expression(mut vm, &initializer)! }
		generator.emit(Instruction{op: .mov, dst: value, lhs: initial})
		generator.patch(skip)
	}
}

fn (mut generator BytecodeGenerator) assignment_pattern(mut vm VM, pattern BindingPattern, value Operand) ! {
	generator.check_compile_stack()!
	if pattern.kind == .array { return generator.array_assignment_pattern(mut vm, pattern, value) }
	generator.emit(Instruction{op: .require_object_coercible, lhs: value})
	mut excluded := []Operand{}
	for entry in pattern.entries {
		if entry.is_rest {
			target := generator.prepare_assignment_entry(mut vm, entry)!
			rest := generator.temporary()
			generator.emit(Instruction{op: .copy_object_excluding_keys, dst: rest, lhs: value, arguments: excluded.clone()})
			generator.store_assignment_target(mut vm, target, rest)!
			break
		}
		raw_key := if identifier := entry.name.identifier {
			generator.constant(Value.from_string(vm.create_string(identifier.name)))
		} else if expression := entry.name.expression {
			generator.expression(mut vm, &expression)!
		} else { return error('Missing assignment property name') }
		key := generator.temporary()
		generator.emit(Instruction{op: .to_property_key, dst: key, lhs: raw_key})
		excluded << key
		target := generator.prepare_assignment_entry(mut vm, entry)!
		property := generator.temporary()
		generator.emit(Instruction{op: .get_property, dst: property, lhs: value, rhs: key, strict: generator.strict})
		generator.assignment_entry_default(mut vm, entry, property)!
		generator.store_assignment_target(mut vm, target, property)!
	}
}

fn (mut generator BytecodeGenerator) array_assignment_pattern(mut vm VM, pattern BindingPattern, value Operand) ! {
	iterator := generator.temporary()
	generator.emit(Instruction{op: .get_sync_iterator, dst: iterator, lhs: value})
	start := u32(generator.executable.instructions.len)
	depth := generator.scope_depth
	generator.loops << BytecodeLoop{is_iteration: false, scope_depth: depth, iterator: iterator}
	for entry in pattern.entries {
		if entry.alias.kind == .none_kind && entry.name.kind == .none_kind {
			generator.emit(Instruction{op: .sync_iterator_elide, lhs: iterator})
			continue
		}
		target := generator.prepare_assignment_entry(mut vm, entry)!
		item := generator.temporary()
		generator.emit(Instruction{op: if entry.is_rest { OpCode.sync_iterator_to_array } else { OpCode.sync_iterator_step_value }, dst: item, lhs: iterator})
		generator.assignment_entry_default(mut vm, entry, item)!
		generator.store_assignment_target(mut vm, target, item)!
		if entry.is_rest { break }
	}
	cleanup := generator.loops.pop()
	end := u32(generator.executable.instructions.len)
	generator.emit(Instruction{op: .close_sync_iterator, lhs: iterator})
	finished := generator.emit(Instruction{op: .jump})
	catch_start := u32(generator.executable.instructions.len)
	caught := generator.temporary()
	generator.emit(Instruction{op: .catch_op, dst: caught})
	generator.emit(Instruction{op: .close_sync_iterator_throw, lhs: iterator, rhs: caught})
	generator.emit(Instruction{op: .throw_op, lhs: caught})
	generator.emit_pattern_iterator_returns(iterator, cleanup.returns, depth)
	generator.patch(finished)
	generator.protect_range(start, end, catch_start, depth)
}
