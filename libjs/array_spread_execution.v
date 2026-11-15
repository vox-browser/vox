// SPDX-License-Identifier: BSD-2-Clause
module libjs

// ArrayAccumulation uses the ordinary synchronous iterator protocol. Lower it
// into existing bytecode so each next/value read and append remains ordered,
// exception-aware and charged to the same execution budget in both tiers.
fn (mut generator BytecodeGenerator) array_literal_with_spread(mut vm VM, elements []?Expression) !Operand {
	array := generator.temporary()
	zero := generator.constant(Value.from_i32(0))
	one := generator.constant(Value.from_i32(1))
	index := generator.temporary()
	generator.emit(Instruction{op: .new_array, dst: array, lhs: zero})
	generator.emit(Instruction{op: .mov, dst: index, lhs: zero})
	for element in elements {
		if expression := element {
			if expression.kind.tag == .spread {
				operand := expression.kind.operand or { return error('Missing array spread operand') }
				value := generator.expression(mut vm, operand)!
				iterator := generator.temporary()
				generator.emit(Instruction{op: .get_sync_iterator, dst: iterator, lhs: value})
				loop_start := u32(generator.executable.instructions.len)
				item := generator.temporary()
				finished := generator.emit(Instruction{op: .sync_iterator_next, dst: item, lhs: iterator})
				generator.emit(Instruction{op: .define_property, lhs: array, rhs: index, src: item})
				generator.emit(Instruction{op: .add, dst: index, lhs: index, rhs: one})
				generator.emit(Instruction{op: .jump, target: loop_start})
				generator.patch(finished)
				continue
			}
			value := generator.expression(mut vm, &expression)!
			generator.emit(Instruction{op: .define_property, lhs: array, rhs: index, src: value})
		}
		// An elision advances length without creating an indexed property.
		generator.emit(Instruction{op: .add, dst: index, lhs: index, rhs: one})
	}
	// DefineProperty grows length for values; a trailing elision still needs
	// the final length write. Array literals always create intrinsic arrays.
	generator.emit(Instruction{op: .put_property, lhs: array, rhs: generator.constant(Value.from_string(vm.create_string_from_str('length'))), src: index, strict: true})
	return array
}
