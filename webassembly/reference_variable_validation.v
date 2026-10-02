// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// AbstractMachine/Validator.cpp: reference, parametric and variable handlers.
module webassembly

fn validate_binary_reference_variable_instruction(instruction BinaryInstruction, mut validator BinaryInstructionValidator, mut stack BinaryValidationStack) !bool {
	match instruction.opcode {
		binary_op_ref_null {
			stack.append_type(instruction.arguments as BinaryValueType)
			return true
		}
		binary_op_ref_is_null {
			// The source checks the physical vector before the polymorphic pop.
			if stack.is_empty() || !stack.last().is_reference() {
				return error('CompileError: invalid stack state, expected reference')
			}
			stack.take_last()!
			stack.append_type(BinaryValueType{ kind: .i32 })
		}
		binary_op_ref_func {
			argument := instruction.arguments as BinaryIndexArgument
			index := argument.index
			if u64(index) >= u64(validator.context.functions.len) {
				return error('CompileError: invalid FunctionIndex')
			}
			if index !in validator.context.references {
				return error('CompileError: invalid function reference')
			}
			mut type_ := BinaryValueType{ kind: .function_reference, nullable: false }
			type_index := validator.context.function_type_indices[index]
			if value := type_index {
				type_ = BinaryValueType{ kind: .type_use_reference, type_index: value, nullable: false }
			}
			stack.append_type(type_)
			return true
		}
		binary_op_drop { stack.take_last()! }
		binary_op_select {
			stack.take(BinaryValueType{ kind: .i32 })!
			arg0 := stack.take_last()!
			arg1 := stack.take_last()!
			if !arg0.matches_entry(arg1) || arg0.concrete_type.is_reference() || arg1.concrete_type.is_reference() {
				return error('CompileError: invalid select argument types')
			}
			stack.append(if arg0.is_known { arg0 } else { arg1 })
		}
		binary_op_select_typed {
			argument := instruction.arguments as BinaryValueTypeVector
			if argument.types.len != 1 {
				return error('CompileError: invalid select types, expected exactly one type')
			}
			required := argument.types[0]
			validate_binary_value_type(required, validator.context.types)!
			stack.take(BinaryValueType{ kind: .i32 })!
			stack.take(required)!
			stack.take(required)!
			stack.append_type(required)
		}
		binary_op_local_get, binary_op_local_set, binary_op_local_tee {
			index := instruction.local_index
			if u64(index) >= u64(validator.context.locals.len) {
				return error('CompileError: invalid LocalIndex')
			}
			type_ := validator.context.locals[index]
			if instruction.opcode == binary_op_local_get {
				if !validator.local_initialized[index] {
					return error('CompileError: invalid local.get of an uninitialized non-defaultable local')
				}
				stack.append_type(type_)
			} else {
				stack.take(type_)!
				validator.mark_local_initialized(index)
				if instruction.opcode == binary_op_local_tee { stack.append_type(type_) }
			}
		}
		binary_op_global_get, binary_op_global_set {
			argument := instruction.arguments as BinaryIndexArgument
			if u64(argument.index) >= u64(validator.context.globals.len) {
				return error('CompileError: invalid GlobalIndex')
			}
			global := validator.context.globals[argument.index]
			if instruction.opcode == binary_op_global_get {
				stack.append_type(global.type_)
				return !global.mutable_
			}
			if !global.mutable_ {
				return error('CompileError: invalid global variable for global.set')
			}
			stack.take(global.type_)!
		}
		else { return error('instruction is outside the reference and variable validation slice') }
	}
	return false
}
