// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Validator.cpp GC reference conversion/test/cast and nullable branch handlers.
module webassembly

fn validate_binary_gc_reference_instruction(mut instruction BinaryInstruction, validator &BinaryInstructionValidator, mut stack BinaryValidationStack) !bool {
	match instruction.opcode {
		binary_op_ref_eq {
			stack.take(BinaryValueType{ kind: .eq_reference })!
			stack.take(BinaryValueType{ kind: .eq_reference })!
			stack.append_type(BinaryValueType{ kind: .i32 })
		}
		binary_op_ref_as_non_null {
			entry := stack.take_last()!
			if entry.is_known && !entry.concrete_type.is_reference() {
				return error('CompileError: invalid stack state, expected reference')
			}
			if entry.is_known {
				stack.append_type(BinaryValueType{ ...entry.concrete_type, nullable: false })
			} else {
				stack.append(entry)
			}
		}
		binary_op_br_on_null {
			mut args := instruction.arguments as BinaryBranchArguments
			target := validator.frame_for_label(args.label)!
			entry := stack.take_last()!
			if entry.is_known && !entry.concrete_type.is_reference() {
				return error('CompileError: invalid stack state, expected reference')
			}
			labels := target.labels()
			binary_take_reverse(labels, mut stack)!
			for label in labels { stack.append_type(label) }
			if entry.is_known {
				stack.append_type(BinaryValueType{ ...entry.concrete_type, nullable: false })
			} else {
				stack.append(entry)
			}
			args.has_stack_adjustment = target.initial_size != stack.size()
			instruction.arguments = args
		}
		binary_op_br_on_non_null {
			mut args := instruction.arguments as BinaryBranchArguments
			target := validator.frame_for_label(args.label)!
			labels := target.labels()
			if labels.len == 0 || !labels.last().is_reference() {
				return error('CompileError: invalid br_on_non_null label type')
			}
			stack.take(BinaryValueType{ ...labels.last(), nullable: true })!
			binary_take_reverse(labels[..labels.len - 1], mut stack)!
			for label in labels[..labels.len - 1] { stack.append_type(label) }
			args.has_stack_adjustment = target.initial_size != stack.size()
			instruction.arguments = args
		}
		binary_op_ref_test, binary_op_ref_test_null, binary_op_ref_cast, binary_op_ref_cast_null {
			type_ := instruction.arguments as BinaryValueType
			validate_binary_value_type(type_, validator.context.types)!
			stack.take(BinaryValueType{ kind: top_of_binary_heap_type(type_, stack.type_context()) })!
			if instruction.opcode in [binary_op_ref_test, binary_op_ref_test_null] {
				stack.append_type(BinaryValueType{ kind: .i32 })
			} else {
				stack.append_type(type_)
			}
		}
		binary_op_br_on_cast, binary_op_br_on_cast_fail {
			mut args := instruction.arguments as BinaryBranchCastArguments
			target := validator.frame_for_label(args.branch.label)!
			validate_binary_value_type(args.source_type, validator.context.types)!
			validate_binary_value_type(args.target_type, validator.context.types)!
			if !matches_binary_reference_type(args.target_type, args.source_type, stack.type_context()) {
				return error('CompileError: invalid br_on_cast target type')
			}
			labels := target.labels()
			if labels.len == 0 || !labels.last().is_reference() {
				return error('CompileError: invalid br_on_cast label type')
			}
			difference := if args.target_type.nullable {
				BinaryValueType{ ...args.source_type, nullable: false }
			} else {
				args.source_type
			}
			failure := instruction.opcode == binary_op_br_on_cast_fail
			branched := if failure { difference } else { args.target_type }
			if !matches_binary_reference_type(branched, labels.last(), stack.type_context()) {
				return error('CompileError: invalid br_on_cast label type')
			}
			stack.take(args.source_type)!
			binary_take_reverse(labels[..labels.len - 1], mut stack)!
			for label in labels[..labels.len - 1] { stack.append_type(label) }
			stack.append_type(if failure { args.target_type } else { difference })
			args.branch.has_stack_adjustment = target.initial_size != stack.size()
			instruction.arguments = args
		}
		binary_op_any_convert_extern, binary_op_extern_convert_any {
			entry := stack.take_last()!
			required_kind := if instruction.opcode == binary_op_any_convert_extern {
				BinaryValueKind.extern_reference
			} else {
				BinaryValueKind.any_reference
			}
			mut nullable := false
			if entry.is_known {
				if !matches_binary_value_type(entry.concrete_type, BinaryValueType{ kind: required_kind }, stack.type_context()) {
					return error('CompileError: invalid reference conversion operand')
				}
				nullable = entry.concrete_type.nullable
			}
			stack.append_type(BinaryValueType{ kind: if instruction.opcode == binary_op_any_convert_extern {
				BinaryValueKind.any_reference
			} else {
				BinaryValueKind.extern_reference
			}, nullable: nullable })
			return true
		}
		binary_op_ref_i31 {
			stack.take(BinaryValueType{ kind: .i32 })!
			stack.append_type(BinaryValueType{ kind: .i31_reference, nullable: false })
			return true
		}
		binary_op_i31_get_s, binary_op_i31_get_u {
			stack.take(BinaryValueType{ kind: .i31_reference })!
			stack.append_type(BinaryValueType{ kind: .i32 })
		}
		else { return error('instruction is outside the GC reference validation slice') }
	}
	return false
}
