// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Validator.cpp GC struct/array handlers and Types.h StorageType helpers.
module webassembly

fn (type_ BinaryValueType) is_packed_storage() bool { return type_.kind in [.i8, .i16] }

fn (type_ BinaryValueType) unpacked_storage() BinaryValueType {
	return if type_.is_packed_storage() { BinaryValueType{ kind: .i32 } } else { type_ }
}

fn (type_ BinaryValueType) is_defaultable_storage() bool {
	return !type_.is_reference() || type_.nullable
}

fn (validator &BinaryInstructionValidator) struct_for_index(index u32, operation string) !BinaryDefinedType {
	validate_binary_type_index(index, validator.context.types)!
	type_ := validator.context.types[index]
	if type_.kind != .struct_ { return error('CompileError: invalid ${operation} type') }
	return type_
}

fn (validator &BinaryInstructionValidator) array_field_type(index u32, operation string, requires_mutable bool) !BinaryFieldType {
	validate_binary_type_index(index, validator.context.types)!
	type_ := validator.context.types[index]
	if type_.kind != .array { return error('CompileError: invalid ${operation} type') }
	field := type_.fields[0]
	if requires_mutable && !field.mutable_ {
		return error('CompileError: invalid ${operation}, requires a mutable array type')
	}
	return field
}

fn binary_typed_reference(index u32, nullable bool) BinaryValueType {
	return BinaryValueType{ kind: .type_use_reference, type_index: index, nullable: nullable }
}

fn validate_binary_gc_aggregate_instruction(instruction BinaryInstruction, validator &BinaryInstructionValidator, mut stack BinaryValidationStack) !bool {
	match instruction.opcode {
		binary_op_struct_new, binary_op_struct_new_default {
			arg := instruction.arguments as BinaryIndexArgument
			operation := if instruction.opcode == binary_op_struct_new {
				'struct.new'
			} else {
				'struct.new_default'
			}
			type_ := validator.struct_for_index(arg.index, operation)!
			if instruction.opcode == binary_op_struct_new {
				for i := type_.fields.len; i > 0; i-- {
					stack.take(type_.fields[i - 1].type_.unpacked_storage())!
				}
			} else {
				for field in type_.fields {
					if !field.type_.is_defaultable_storage() {
						return error('CompileError: invalid struct.new_default field type, must be defaultable')
					}
				}
			}
			stack.append_type(binary_typed_reference(arg.index, false))
			return true
		}
		binary_op_struct_get, binary_op_struct_get_s, binary_op_struct_get_u, binary_op_struct_set {
			arg := instruction.arguments as BinaryStructFieldArguments
			setter := instruction.opcode == binary_op_struct_set
			operation := if setter { 'struct.set' } else { 'struct.get' }
			type_ := validator.struct_for_index(arg.type_index, operation)!
			if u64(arg.field_index) >= u64(type_.fields.len) {
				return error('CompileError: invalid ${operation} field index')
			}
			field := type_.fields[arg.field_index]
			if setter {
				if !field.mutable_ {
					return error('CompileError: invalid struct.set field, must be mutable')
				}
				stack.take(field.type_.unpacked_storage())!
				stack.take(binary_typed_reference(arg.type_index, true))!
			} else {
				if field.type_.is_packed_storage() != (instruction.opcode != binary_op_struct_get) {
					return error('CompileError: invalid struct.get signedness, present iff the field type is packed')
				}
				stack.take(binary_typed_reference(arg.type_index, true))!
				stack.append_type(field.type_.unpacked_storage())
			}
		}
		binary_op_array_new, binary_op_array_new_default, binary_op_array_get,
		binary_op_array_get_s, binary_op_array_get_u, binary_op_array_set, binary_op_array_fill {
			arg := instruction.arguments as BinaryIndexArgument
			operation := match instruction.opcode {
				binary_op_array_new { 'array.new' }
				binary_op_array_new_default { 'array.new_default' }
				binary_op_array_set { 'array.set' }
				binary_op_array_fill { 'array.fill' }
				else { 'array.get' }
			}
			field := validator.array_field_type(arg.index, operation, instruction.opcode in [
				binary_op_array_set,
				binary_op_array_fill,
			])!
			match instruction.opcode {
				binary_op_array_new, binary_op_array_new_default {
					if instruction.opcode == binary_op_array_new_default && !field.type_.is_defaultable_storage() {
						return error('CompileError: invalid array.new_default element type, must be defaultable')
					}
					stack.take(BinaryValueType{ kind: .i32 })!
					if instruction.opcode == binary_op_array_new {
						stack.take(field.type_.unpacked_storage())!
					}
					stack.append_type(binary_typed_reference(arg.index, false))
					return true
				}
				binary_op_array_get, binary_op_array_get_s, binary_op_array_get_u {
					if field.type_.is_packed_storage() != (instruction.opcode != binary_op_array_get) {
						return error('CompileError: invalid array.get signedness, present iff the element type is packed')
					}
					stack.take(BinaryValueType{ kind: .i32 })!
					stack.take(binary_typed_reference(arg.index, true))!
					stack.append_type(field.type_.unpacked_storage())
				}
				else {
					if instruction.opcode == binary_op_array_fill {
						stack.take(BinaryValueType{ kind: .i32 })!
					}
					stack.take(field.type_.unpacked_storage())!
					stack.take(BinaryValueType{ kind: .i32 })!
					stack.take(binary_typed_reference(arg.index, true))!
				}
			}
		}
		binary_op_array_new_fixed {
			arg := instruction.arguments as BinaryArrayFixedArguments
			field := validator.array_field_type(arg.type_index, 'array.new_fixed', false)!
			for _ in 0 .. arg.count { stack.take(field.type_.unpacked_storage())! }
			stack.append_type(binary_typed_reference(arg.type_index, false))
			return true
		}
		binary_op_array_new_data, binary_op_array_init_data {
			arg := instruction.arguments as BinaryArrayDataArguments
			init := instruction.opcode == binary_op_array_init_data
			operation := if init { 'array.init_data' } else { 'array.new_data' }
			field := validator.array_field_type(arg.type_index, operation, init)!
			if field.type_.is_reference() {
				return error('CompileError: invalid ${operation} element type')
			}
			if validator.context.data_count == none {
				return error('CompileError: invalid ${operation}, requires data count section')
			}
			validator.validate_data_index(arg.data_index)!
			stack.take_kinds([BinaryValueKind.i32, .i32])!
			if init {
				stack.take(BinaryValueType{ kind: .i32 })!
				stack.take(binary_typed_reference(arg.type_index, true))!
			} else {
				stack.append_type(binary_typed_reference(arg.type_index, false))
			}
		}
		binary_op_array_new_elem, binary_op_array_init_elem {
			arg := instruction.arguments as BinaryArrayElementArguments
			init := instruction.opcode == binary_op_array_init_elem
			operation := if init { 'array.init_elem' } else { 'array.new_elem' }
			field := validator.array_field_type(arg.type_index, operation, init)!
			if !field.type_.is_reference() {
				return error('CompileError: invalid ${operation} element type')
			}
			validator.validate_element_index(arg.element_index)!
			if !matches_binary_reference_type(validator.context.elements[arg.element_index], field.type_, stack.type_context()) {
				return error('CompileError: invalid ${operation} element segment type')
			}
			stack.take_kinds([BinaryValueKind.i32, .i32])!
			if init {
				stack.take(BinaryValueType{ kind: .i32 })!
				stack.take(binary_typed_reference(arg.type_index, true))!
			} else {
				stack.append_type(binary_typed_reference(arg.type_index, false))
			}
		}
		binary_op_array_len {
			stack.take(BinaryValueType{ kind: .array_reference })!
			stack.append_type(BinaryValueType{ kind: .i32 })
		}
		binary_op_array_copy {
			arg := instruction.arguments as BinaryArrayCopyArguments
			destination := validator.array_field_type(arg.destination_type_index, 'array.copy destination', true)!
			source := validator.array_field_type(arg.source_type_index, 'array.copy source', false)!
			if !matches_binary_field_type(BinaryFieldType{ type_: source.type_ }, BinaryFieldType{ type_: destination.type_ }, stack.type_context()) {
				return error('CompileError: invalid array.copy source element type')
			}
			stack.take_kinds([BinaryValueKind.i32, .i32])!
			stack.take(binary_typed_reference(arg.source_type_index, true))!
			stack.take(BinaryValueType{ kind: .i32 })!
			stack.take(binary_typed_reference(arg.destination_type_index, true))!
		}
		else { return error('instruction is outside the GC aggregate validation slice') }
	}
	return false
}
