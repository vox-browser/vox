// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// AbstractMachine/Validator.cpp: structured control, branches and exceptions.
module webassembly

fn (validator &BinaryInstructionValidator) validate_block_type(block BinaryBlockType) !BinaryDefinedType {
	match block.kind {
		.empty_ { return BinaryDefinedType{ kind: .function_ } }
		.value_type {
			validate_binary_value_type(block.value_type, validator.context.types)!
			return BinaryDefinedType{ kind: .function_, results: [block.value_type] }
		}
		.type_index {
			validate_binary_type_index(block.type_index, validator.context.types)!
			type_ := validator.context.types[block.type_index]
			if type_.kind != .function_ { return error('CompileError: invalid BlockType') }
			return type_
		}
	}
}

fn (validator &BinaryInstructionValidator) frame_for_label(label u32) !BinaryValidationFrame {
	if u64(label) >= u64(validator.frames.len) { return error('CompileError: invalid LabelIndex') }
	return validator.frames[validator.frames.len - 1 - int(label)]
}

fn (validator &BinaryInstructionValidator) exception_tag_function(index u32, operation string) !BinaryDefinedType {
	if u64(index) >= u64(validator.context.tags.len) {
		return error('CompileError: invalid TagIndex')
	}
	tag := validator.context.tags[index]
	validate_binary_type_index(tag.type_index, validator.context.types)!
	type_ := validator.context.types[tag.type_index]
	if type_.kind != .function_ || type_.results.len != 0 {
		return error('CompileError: invalid ${operation} type')
	}
	return type_
}

fn binary_take_reverse(types []BinaryValueType, mut stack BinaryValidationStack) ! {
	for i := types.len; i > 0; i-- { stack.take(types[i - 1])! }
}

fn (mut validator BinaryInstructionValidator) make_current_frame_unreachable(mut stack BinaryValidationStack) {
	index := validator.frames.len - 1
	validator.frames[index].unreachable = true
	stack.resize(validator.frames[index].initial_size)
}

fn (mut validator BinaryInstructionValidator) validate_structured_else(mut stack BinaryValidationStack) ! {
	if validator.frames.len == 0 || validator.frames.last().kind != .if_ {
		return error('CompileError: invalid usage of structured else')
	}
	index := validator.frames.len - 1
	frame := validator.frames[index]
	binary_take_reverse(frame.type_.results, mut stack)!
	if stack.size() != frame.initial_size { return error('CompileError: stack height mismatch') }
	validator.frames[index].kind = .else_
	validator.frames[index].unreachable = false
	validator.roll_back_local_initializations(frame.local_init_log_height)
	for parameter in frame.type_.parameters { stack.append_type(parameter) }
}

fn validate_binary_control_instruction(mut instruction BinaryInstruction, mut validator BinaryInstructionValidator, mut stack BinaryValidationStack) !bool {
	match instruction.opcode {
		binary_op_unreachable { validator.make_current_frame_unreachable(mut stack) }
		binary_op_structured_else { validator.validate_structured_else(mut stack)! }
		binary_op_structured_end {
			if validator.frames.len == 0 {
				return error('CompileError: invalid usage of structured end')
			}
			if validator.frames.last().kind == .if_ {
				validator.validate_structured_else(mut stack)!
			}
			frame := validator.frames.last()
			binary_take_reverse(frame.type_.results, mut stack)!
			if stack.size() != frame.initial_size {
				return error('CompileError: stack height mismatch')
			}
			for result in frame.type_.results { stack.append_type(result) }
			validator.roll_back_local_initializations(frame.local_init_log_height)
			validator.frames.pop()
		}
		binary_op_block, binary_op_loop, binary_op_if_ {
			mut args := instruction.arguments as BinaryStructuredArguments
			type_ := validator.validate_block_type(args.block_type)!
			if instruction.opcode == binary_op_if_ { stack.take(BinaryValueType{ kind: .i32 })! }
			binary_take_reverse(type_.parameters, mut stack)!
			tier := instruction.opcode == binary_op_loop && type_.parameters.len == 0 && stack.size() == 0
			kind := match instruction.opcode {
				binary_op_block { BinaryValidationFrameKind.block }
				binary_op_loop { BinaryValidationFrameKind.loop }
				else { BinaryValidationFrameKind.if_ }
			}
			validator.push_frame(BinaryValidationFrame{ type_: type_, kind: kind, initial_size: stack.size() })
			for parameter in type_.parameters { stack.append_type(parameter) }
			args.meta = BinaryStructuredMeta{ arity: u32(type_.results.len), parameter_count: u32(type_.parameters.len), tier_up_eligible: tier }
			instruction.arguments = args
		}
		binary_op_throw_ {
			args := instruction.arguments as BinaryIndexArgument
			type_ := validator.exception_tag_function(args.index, 'throw')!
			binary_take_reverse(type_.parameters, mut stack)!
			validator.make_current_frame_unreachable(mut stack)
		}
		binary_op_throw_ref {
			stack.take(BinaryValueType{ kind: .exception_reference })!
			validator.make_current_frame_unreachable(mut stack)
		}
		binary_op_try_table {
			mut args := instruction.arguments as BinaryTryTableArguments
			type_ := validator.validate_block_type(args.block_type)!
			// Catch labels resolve before the try_table's own label is pushed.
			for catch_ in args.catches {
				target := validator.frame_for_label(catch_.label_index)!
				mut expected := []BinaryValueType{}
				if tag := catch_.tag_index {
					function := validator.exception_tag_function(tag, 'catch tag')!
					expected << function.parameters
				}
				if catch_.capture_reference {
					expected << BinaryValueType{ kind: .exception_reference, nullable: false }
				}
				if !matches_binary_result_types(expected, target.labels(), stack.type_context()) {
					return error('CompileError: non-conforming catch types')
				}
			}
			binary_take_reverse(type_.parameters, mut stack)!
			args.meta = BinaryStructuredMeta{ arity: u32(type_.results.len), parameter_count: u32(type_.parameters.len) }
			instruction.arguments = args
			validator.push_frame(BinaryValidationFrame{ type_: type_, kind: .try_table, initial_size: stack.size() })
			for parameter in type_.parameters { stack.append_type(parameter) }
		}
		binary_op_br, binary_op_br_if {
			mut args := instruction.arguments as BinaryBranchArguments
			target := validator.frame_for_label(args.label)!
			if instruction.opcode == binary_op_br_if { stack.take(BinaryValueType{ kind: .i32 })! }
			labels := target.labels()
			binary_take_reverse(labels, mut stack)!
			if instruction.opcode == binary_op_br_if {
				// Source re-appends label types, rather than popped subtypes.
				for label in labels { stack.append_type(label) }
			}
			args.has_stack_adjustment = target.initial_size != stack.size()
			instruction.arguments = args
			if instruction.opcode == binary_op_br {
				validator.make_current_frame_unreachable(mut stack)
			}
		}
		binary_op_br_table {
			args := instruction.arguments as BinaryTableBranchArguments
			default_frame := validator.frame_for_label(args.default_label)!
			for label in args.labels { validator.frame_for_label(label)! }
			stack.take(BinaryValueType{ kind: .i32 })!
			default_types := default_frame.labels()
			for label in args.labels {
				target := validator.frame_for_label(label)!
				labels := target.labels()
				if labels.len != default_types.len {
					return error('CompileError: invalid br_table label arity mismatch')
				}
				mut popped := []BinaryStackEntry{}
				for i := labels.len; i > 0; i-- { popped << stack.take(labels[i - 1])! }
				for i := popped.len; i > 0; i-- { stack.append(popped[i - 1]) }
			}
			binary_take_reverse(default_types, mut stack)!
			validator.make_current_frame_unreachable(mut stack)
		}
		binary_op_return_ {
			binary_take_reverse(validator.frames[0].type_.results, mut stack)!
			validator.make_current_frame_unreachable(mut stack)
		}
		else { return error('instruction is outside the structured control validation slice') }
	}
	return false
}
