// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Rust bytecode/codegen.rs::generate_array_binding_pattern. Elisions perform
// IteratorStep without reading value; defaults distinguish exhaustion from a
// yielded undefined, and both normal and abrupt completion close as required.
fn (mut generator BytecodeGenerator) array_binding_pattern(mut vm VM, pattern BindingPattern, value Operand, lexical bool) ! {
	generator.check_compile_stack()!
	iterator := generator.temporary()
	generator.emit(Instruction{ op: .get_sync_iterator, dst: iterator, lhs: value })
	start := u32(generator.executable.instructions.len)
	depth := generator.scope_depth
	generator.loops << BytecodeLoop{is_iteration: false, scope_depth: depth, iterator: iterator}
	for entry in pattern.entries {
		if entry.alias.kind == .none_kind && entry.name.kind == .none_kind {
			generator.emit(Instruction{ op: .sync_iterator_elide, lhs: iterator })
			continue
		}
		item := generator.temporary()
		generator.emit(Instruction{ op: if entry.is_rest {
			OpCode.sync_iterator_to_array
		} else {
			OpCode.sync_iterator_step_value
		}, dst: item, lhs: iterator })
		if initializer := entry.initializer {
			missing := generator.temporary()
			generator.emit(Instruction{ op: .strict_equals, dst: missing, lhs: item, rhs: generator.constant(js_undefined()) })
			skip := generator.emit(Instruction{ op: .jump_if_false, lhs: missing })
			mut initial := Operand{}
			if initializer.kind.tag == .function_expr && generator.executable.parsed_source.function_table.get(initializer.kind.function_id).name == none && generator.binding_entry_name(entry) != none {
				name := generator.binding_entry_name(entry) or { return error('Missing default binding name') }
				initial = generator.temporary()
				generator.emit(Instruction{ op: .new_function_with_name, dst: initial, identifier: initializer.kind.function_id.id, lhs: generator.constant(Value.from_string(vm.create_string(name))) })
			} else {
				initial = generator.expression(mut vm, &initializer)!
			}
			generator.emit(Instruction{ op: .mov, dst: item, lhs: initial })
			generator.patch(skip)
		}
		generator.initialize_binding_entry(mut vm, entry, item, lexical)!
	}
	cleanup := generator.loops.pop()
	end := u32(generator.executable.instructions.len)
	generator.emit(Instruction{ op: .close_sync_iterator, lhs: iterator })
	finished := generator.emit(Instruction{ op: .jump })
	catch_start := u32(generator.executable.instructions.len)
	caught := generator.temporary()
	generator.emit(Instruction{ op: .catch_op, dst: caught })
	generator.emit(Instruction{ op: .close_sync_iterator_throw, lhs: iterator, rhs: caught })
	generator.emit(Instruction{ op: .throw_op, lhs: caught })
	generator.emit_pattern_iterator_returns(iterator, cleanup.returns, depth)
	generator.patch(finished)
	generator.protect_range(start, end, catch_start, depth)
}

// A yield inside a pattern initializer can resume with ReturnCompletion. Route
// that return through IteratorClose just like a return from a for-of body.
fn (mut generator BytecodeGenerator) emit_pattern_iterator_returns(iterator Operand, returns []LoopReturnExit, depth int) {
	for exit in returns {
		generator.patch(exit.jump)
		for _ in depth .. exit.scope_depth { generator.emit(Instruction{op: .leave_scope}) }
		generator.emit(Instruction{op: .close_sync_iterator, lhs: iterator})
		generator.emit_return(exit.value)
	}
}
