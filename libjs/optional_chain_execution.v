// SPDX-License-Identifier: BSD-2-Clause
module libjs

// codegen.rs::generate_optional_chain: retain both the value and Reference's
// receiver. Parentheses terminate short-circuiting but preserve a method's this.
fn (mut generator BytecodeGenerator) call_reference(mut vm VM, expression &Expression) !(Operand, Operand) {
	if expression.kind.tag == .optional_chain {
		return generator.optional_chain_reference(mut vm, expression, false)
	}
	if expression.kind.tag == .member {
		base, key := generator.member_reference(mut vm, expression)!
		value := generator.temporary()
		generator.emit(Instruction{ op: .get_property, dst: value, lhs: base, rhs: key, strict: generator.strict })
		return value, base
	}
	if expression.kind.tag == .identifier_expr {
		value, receiver := generator.temporary(), generator.temporary()
		generator.emit(Instruction{
			op:         .get_callee_and_this
			dst:        value
			rhs:        receiver
			identifier: generator.identifier(identifier_name(expression)!)
			strict:     generator.strict
		})
		return value, receiver
	}
	return generator.expression(mut vm, expression)!, generator.constant(js_undefined())
}

fn (mut generator BytecodeGenerator) optional_chain_reference(mut vm VM, expression &Expression, deleting bool) !(Operand, Operand) {
	generator.check_compile_stack()!
	if expression.kind.references.len == 0 { return error('Optional chain has no references') }
	base := expression.kind.base or { return error('Missing optional-chain base') }
	initial, initial_receiver := generator.call_reference(mut vm, base)!
	value, receiver := generator.temporary(), generator.temporary()
	generator.emit(Instruction{ op: .mov, dst: value, lhs: initial })
	generator.emit(Instruction{ op: .mov, dst: receiver, lhs: initial_receiver })
	mut exits := []u32{}
	for index, reference in expression.kind.references {
		optional := match reference {
			OptionalChainCall { reference.mode == .optional }
			OptionalChainComputedRef { reference.mode == .optional }
			OptionalChainMemberRef { reference.mode == .optional }
			OptionalChainPrivateMemberRef {
				return generator.unsupported('private optional-chain access')
			}
		}
		if optional { exits << generator.emit(Instruction{ op: .jump_if_nullish, lhs: value }) }
		if reference is OptionalChainCall {
			mut call_arguments := []Operand{cap: reference.arguments.len}
			for argument in reference.arguments {
				if argument.is_spread { return generator.unsupported('spread call arguments') }
				call_arguments << generator.expression(mut vm, &argument.value)!
			}
			generator.emit(Instruction{ op: .call, dst: value, lhs: value, rhs: receiver, arguments: call_arguments })
			generator.emit(Instruction{ op: .mov, dst: receiver, lhs: generator.constant(js_undefined()) })
		} else {
			key := match reference {
				OptionalChainComputedRef { generator.expression(mut vm, &reference.expression)! }
				OptionalChainMemberRef {
					generator.constant(Value.from_string(vm.create_string(reference.identifier.name)))
				}
				else { return generator.unsupported('optional-chain reference') }
			}
			generator.emit(Instruction{ op: .mov, dst: receiver, lhs: value })
			generator.emit(Instruction{
				op:     if deleting && index == expression.kind.references.len - 1 {
					OpCode.delete_property
				} else {
					OpCode.get_property
				}
				dst:    value
				lhs:    value
				rhs:    key
				strict: generator.strict
			})
		}
	}
	if deleting {
		if expression.kind.references.last() is OptionalChainCall {
			generator.emit(Instruction{ op: .mov, dst: value, lhs: generator.constant(Value.from_bool(true)) })
		}
	}
	end := generator.emit(Instruction{ op: .jump })
	for exit in exits { generator.patch(exit) }
	generator.emit(Instruction{ op: .mov, dst: value, lhs: generator.constant(if deleting {
		Value.from_bool(true)
	} else {
		js_undefined()
	}) })
	generator.emit(Instruction{ op: .mov, dst: receiver, lhs: generator.constant(js_undefined()) })
	generator.patch(end)
	return value, receiver
}
