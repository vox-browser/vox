// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm Parser/Parser.cpp::Instruction/BlockType/Catch::parse and Types.h
// operands. These are decoding records; they do not execute instructions.
module webassembly

import math

pub enum BinaryBlockKind {
	empty_
	value_type
	type_index
}
pub struct BinaryBlockType {
pub:
	kind       BinaryBlockKind
	value_type BinaryValueType
	type_index u32
}

pub struct BinaryCatch {
pub:
	capture_reference bool
	tag_index         ?u32
	label_index       u32
}

pub struct BinaryStructuredMeta {
pub mut:
	arity            u32
	parameter_count  u32
	tier_up_eligible bool
}

pub struct BinaryStructuredArguments {
pub:
	block_type BinaryBlockType
pub mut:
	end_ip  u32
	else_ip ?u32
	meta    BinaryStructuredMeta
}

pub struct BinaryTryTableArguments {
pub:
	block_type BinaryBlockType
	catches    []BinaryCatch
pub mut:
	end_ip u32
	meta   BinaryStructuredMeta
}

pub struct BinaryNoArguments {}

pub struct BinaryBranchArguments {
pub:
	label u32
pub mut:
	has_stack_adjustment bool
}

pub struct BinaryTableBranchArguments {
pub:
	labels        []u32
	default_label u32
}

pub enum BinaryIndexKind {
	tag
	label
	function_
	type_
	global
	table
	data
	element
}
pub struct BinaryIndexArgument {
pub:
	kind  BinaryIndexKind
	index u32
}

pub struct BinaryIndirectCallArguments {
pub:
	type_index  u32
	table_index u32
}

pub struct BinaryMemoryArgument {
pub:
	align        u32
	offset       u64
	memory_index u32
}

pub struct BinaryMemoryLaneArgument {
pub:
	memory BinaryMemoryArgument
	lane   u8
}

pub struct BinaryMemoryIndexArgument {
pub:
	memory_index u32
}

pub struct BinaryI32Constant {
pub:
	value i32
}

pub struct BinaryI64Constant {
pub:
	value i64
}

pub struct BinaryF32Constant {
pub:
	value f32
}

pub struct BinaryF64Constant {
pub:
	value f64
}

pub struct BinaryValueTypeVector {
pub:
	types []BinaryValueType
}

pub struct BinaryMemoryInitArguments {
pub:
	data_index   u32
	memory_index u32
}

pub struct BinaryMemoryCopyArguments {
pub:
	src_index u32
	dst_index u32
}

pub struct BinaryTableElementArguments {
pub:
	element_index u32
	table_index   u32
}

pub struct BinaryTableTableArguments {
pub:
	lhs u32
	rhs u32
}

pub struct BinaryStructFieldArguments {
pub:
	type_index  u32
	field_index u32
}

pub struct BinaryArrayFixedArguments {
pub:
	type_index u32
	count      u32
}

pub struct BinaryArrayDataArguments {
pub:
	type_index u32
	data_index u32
}

pub struct BinaryArrayElementArguments {
pub:
	type_index    u32
	element_index u32
}

pub struct BinaryArrayCopyArguments {
pub:
	destination_type_index u32
	source_type_index      u32
}

pub struct BinaryBranchCastArguments {
pub:
	branch      BinaryBranchArguments
	source_type BinaryValueType
	target_type BinaryValueType
}

pub struct BinaryVectorConstant {
pub:
	bytes [16]u8
}

pub struct BinaryShuffleArgument {
pub:
	lanes [16]u8
}

pub struct BinaryLaneArgument {
pub:
	lane u8
}

pub type BinaryInstructionArguments = BinaryNoArguments
	| BinaryStructuredArguments
	| BinaryTryTableArguments
	| BinaryBranchArguments
	| BinaryTableBranchArguments
	| BinaryIndexArgument
	| BinaryIndirectCallArguments
	| BinaryMemoryArgument
	| BinaryMemoryLaneArgument
	| BinaryMemoryIndexArgument
	| BinaryI32Constant
	| BinaryI64Constant
	| BinaryF32Constant
	| BinaryF64Constant
	| BinaryValueTypeVector
	| BinaryValueType
	| BinaryMemoryInitArguments
	| BinaryMemoryCopyArguments
	| BinaryTableElementArguments
	| BinaryTableTableArguments
	| BinaryStructFieldArguments
	| BinaryArrayFixedArguments
	| BinaryArrayDataArguments
	| BinaryArrayElementArguments
	| BinaryArrayCopyArguments
	| BinaryBranchCastArguments
	| BinaryVectorConstant
	| BinaryShuffleArgument
	| BinaryLaneArgument

pub struct BinaryInstruction {
pub:
	opcode      u32
	local_index u32
pub mut:
	arguments BinaryInstructionArguments = BinaryNoArguments{}
}

fn parse_binary_block_type(mut decoder Decoder) !BinaryBlockType {
	tag := decoder.byte()!
	if tag == 0x40 { return BinaryBlockType{} }
	if tag in [u8(0x7f), 0x7e, 0x7d, 0x7c, 0x7b, 0x63, 0x64] {
		decoder.offset--
		return BinaryBlockType{
			kind:       .value_type
			value_type: parse_binary_value_type(mut decoder)!
		}
	}
	if kind := abstract_heap_type_from_tag(tag) {
		return BinaryBlockType{
			kind:       .value_type
			value_type: BinaryValueType{
				kind: kind
			}
		}
	}
	decoder.offset--
	index := decoder.signed_leb(33)!
	if index < 0 || index > i64(max_u32) { return error('CompileError: invalid block type index') }
	return BinaryBlockType{
		kind:       .type_index
		type_index: u32(index)
	}
}

fn parse_binary_catch(mut decoder Decoder) !BinaryCatch {
	kind := decoder.byte()!
	if kind > 3 { return error('CompileError: invalid catch kind') }
	tag := if kind < 2 { ?u32(decoder.u32_leb()!) } else { ?u32(none) }
	return BinaryCatch{
		capture_reference: kind & 1 != 0
		tag_index:         tag
		label_index:       decoder.u32_leb()!
	}
}

fn parse_binary_memory_argument(mut decoder Decoder) !BinaryMemoryArgument {
	mut align := decoder.u32_leb()!
	mut memory_index := u32(0)
	if align & 0x40 != 0 {
		align &= ~u32(0x40)
		memory_index = decoder.u32_leb()!
	}
	return BinaryMemoryArgument{
		align:        align
		memory_index: memory_index
		offset:       decoder.u64_leb()!
	}
}

fn (mut decoder Decoder) little_endian(bits u32) !u64 {
	mut value := u64(0)
	for i in u32(0) .. bits / 8 {
		value |= u64(decoder.byte()!) << (8 * i)
	}
	return value
}

fn (mut decoder Decoder) fixed_16_bytes() ![16]u8 {
	mut bytes := [16]u8{}
	for i in 0 .. 16 {
		bytes[i] = decoder.byte()!
	}
	return bytes
}

fn parse_binary_instruction(mut decoder Decoder) !BinaryInstruction {
	byte := decoder.byte()!
	mut opcode := u32(byte)
	if byte in [u8(0xfb), 0xfc, 0xfd] {
		selector := decoder.u32_leb()!
		if selector > 0xffffff { return error('CompileError: unknown instruction') }
		opcode = u32(byte) << 24 | selector
	}
	mut arguments := BinaryInstructionArguments(BinaryNoArguments{})
	mut local_index := u32(0)
	match opcode {
		binary_op_block, binary_op_loop, binary_op_if_ {
			arguments = BinaryStructuredArguments{
				block_type: parse_binary_block_type(mut decoder)!
			}
		}
		binary_op_try_table {
			block_type := parse_binary_block_type(mut decoder)!
			count := decoder.u32_leb()!
			mut catches := []BinaryCatch{}
			for _ in 0 .. count {
				catches << parse_binary_catch(mut decoder)!
			}
			arguments = BinaryTryTableArguments{
				block_type: block_type
				catches:    catches
			}
		}
		binary_op_throw_ {
			arguments = BinaryIndexArgument{
				kind:  .tag
				index: decoder.u32_leb()!
			}
		}
		binary_op_br, binary_op_br_if, binary_op_br_on_null, binary_op_br_on_non_null {
			arguments = BinaryBranchArguments{
				label: decoder.u32_leb()!
			}
		}
		binary_op_br_table {
			count := decoder.u32_leb()!
			mut labels := []u32{}
			for _ in 0 .. count {
				labels << decoder.u32_leb()!
			}
			arguments = BinaryTableBranchArguments{
				labels:        labels
				default_label: decoder.u32_leb()!
			}
		}
		binary_op_call, binary_op_return_call, binary_op_ref_func {
			arguments = BinaryIndexArgument{
				kind:  .function_
				index: decoder.u32_leb()!
			}
		}
		binary_op_call_indirect, binary_op_return_call_indirect {
			arguments = BinaryIndirectCallArguments{
				type_index:  decoder.u32_leb()!
				table_index: decoder.u32_leb()!
			}
		}
		binary_op_call_ref, binary_op_return_call_ref, binary_op_struct_new,
		binary_op_struct_new_default, binary_op_array_new, binary_op_array_new_default,
		binary_op_array_get, binary_op_array_get_s, binary_op_array_get_u, binary_op_array_set,
		binary_op_array_fill {
			arguments = BinaryIndexArgument{
				kind:  .type_
				index: decoder.u32_leb()!
			}
		}
		binary_op_i32_load, binary_op_i64_load, binary_op_f32_load, binary_op_f64_load,
		binary_op_i32_load8_s, binary_op_i32_load8_u, binary_op_i32_load16_s,
		binary_op_i32_load16_u, binary_op_i64_load8_s, binary_op_i64_load8_u,
		binary_op_i64_load16_s, binary_op_i64_load16_u, binary_op_i64_load32_s,
		binary_op_i64_load32_u, binary_op_i32_store, binary_op_i64_store, binary_op_f32_store,
		binary_op_f64_store, binary_op_i32_store8, binary_op_i32_store16, binary_op_i64_store8,
		binary_op_i64_store16, binary_op_i64_store32, binary_op_v128_load,
		binary_op_v128_load8x8_s, binary_op_v128_load8x8_u, binary_op_v128_load16x4_s,
		binary_op_v128_load16x4_u, binary_op_v128_load32x2_s, binary_op_v128_load32x2_u,
		binary_op_v128_load8_splat, binary_op_v128_load16_splat, binary_op_v128_load32_splat,
		binary_op_v128_load64_splat, binary_op_v128_load32_zero, binary_op_v128_load64_zero,
		binary_op_v128_store {
			arguments = parse_binary_memory_argument(mut decoder)!
		}
		binary_op_local_get, binary_op_local_set, binary_op_local_tee {
			// Types.h's LocalIndex constructor stores this operand separately
			// and leaves its ordinary argument variant at the empty value.
			local_index = decoder.u32_leb()!
		}
		binary_op_global_get, binary_op_global_set {
			arguments = BinaryIndexArgument{
				kind:  .global
				index: decoder.u32_leb()!
			}
		}
		binary_op_memory_size, binary_op_memory_grow, binary_op_memory_fill {
			arguments = BinaryMemoryIndexArgument{
				memory_index: decoder.u32_leb()!
			}
		}
		binary_op_i32_const {
			arguments = BinaryI32Constant{
				value: i32(decoder.signed_leb(32)!)
			}
		}
		binary_op_i64_const {
			arguments = BinaryI64Constant{
				value: decoder.signed_leb(64)!
			}
		}
		binary_op_f32_const {
			arguments = BinaryF32Constant{
				value: math.f32_from_bits(u32(decoder.little_endian(32)!))
			}
		}
		binary_op_f64_const {
			arguments = BinaryF64Constant{
				value: math.f64_from_bits(decoder.little_endian(64)!)
			}
		}
		binary_op_table_get, binary_op_table_set, binary_op_table_grow, binary_op_table_size,
		binary_op_table_fill {
			arguments = BinaryIndexArgument{
				kind:  .table
				index: decoder.u32_leb()!
			}
		}
		binary_op_select_typed {
			arguments = BinaryValueTypeVector{
				types: parse_binary_value_type_vector(mut decoder)!
			}
		}
		binary_op_ref_null {
			arguments = parse_heap_type(mut decoder)!
		}
		binary_op_memory_init {
			arguments = BinaryMemoryInitArguments{
				data_index:   decoder.u32_leb()!
				memory_index: decoder.u32_leb()!
			}
		}
		binary_op_data_drop {
			arguments = BinaryIndexArgument{
				kind:  .data
				index: decoder.u32_leb()!
			}
		}
		binary_op_memory_copy {
			destination := decoder.u32_leb()!
			source := decoder.u32_leb()!
			arguments = BinaryMemoryCopyArguments{
				src_index: source
				dst_index: destination
			}
		}
		binary_op_table_init {
			arguments = BinaryTableElementArguments{
				element_index: decoder.u32_leb()!
				table_index:   decoder.u32_leb()!
			}
		}
		binary_op_elem_drop {
			arguments = BinaryIndexArgument{
				kind:  .element
				index: decoder.u32_leb()!
			}
		}
		binary_op_table_copy {
			arguments = BinaryTableTableArguments{
				lhs: decoder.u32_leb()!
				rhs: decoder.u32_leb()!
			}
		}
		binary_op_struct_get, binary_op_struct_get_s, binary_op_struct_get_u, binary_op_struct_set {
			arguments = BinaryStructFieldArguments{
				type_index:  decoder.u32_leb()!
				field_index: decoder.u32_leb()!
			}
		}
		binary_op_array_new_fixed {
			arguments = BinaryArrayFixedArguments{
				type_index: decoder.u32_leb()!
				count:      decoder.u32_leb()!
			}
		}
		binary_op_array_new_data, binary_op_array_init_data {
			arguments = BinaryArrayDataArguments{
				type_index: decoder.u32_leb()!
				data_index: decoder.u32_leb()!
			}
		}
		binary_op_array_new_elem, binary_op_array_init_elem {
			arguments = BinaryArrayElementArguments{
				type_index:    decoder.u32_leb()!
				element_index: decoder.u32_leb()!
			}
		}
		binary_op_array_copy {
			arguments = BinaryArrayCopyArguments{
				destination_type_index: decoder.u32_leb()!
				source_type_index:      decoder.u32_leb()!
			}
		}
		binary_op_ref_test, binary_op_ref_test_null, binary_op_ref_cast, binary_op_ref_cast_null {
			type_ := parse_heap_type(mut decoder)!
			arguments = BinaryValueType{
				...type_
				nullable: opcode in [binary_op_ref_test_null, binary_op_ref_cast_null]
			}
		}
		binary_op_br_on_cast, binary_op_br_on_cast_fail {
			cast_op := decoder.byte()!
			if cast_op > 3 { return error('CompileError: invalid cast immediate') }
			label := decoder.u32_leb()!
			source := parse_heap_type(mut decoder)!
			target := parse_heap_type(mut decoder)!
			arguments = BinaryBranchCastArguments{
				branch:      BinaryBranchArguments{
					label: label
				}
				source_type: BinaryValueType{
					...source
					nullable: cast_op & 1 != 0
				}
				target_type: BinaryValueType{
					...target
					nullable: cast_op & 2 != 0
				}
			}
		}
		binary_op_v128_load8_lane, binary_op_v128_load16_lane, binary_op_v128_load32_lane,
		binary_op_v128_load64_lane, binary_op_v128_store8_lane, binary_op_v128_store16_lane,
		binary_op_v128_store32_lane, binary_op_v128_store64_lane {
			memory := parse_binary_memory_argument(mut decoder)!
			arguments = BinaryMemoryLaneArgument{
				memory: memory
				lane:   decoder.byte()!
			}
		}
		binary_op_v128_const {
			arguments = BinaryVectorConstant{
				bytes: decoder.fixed_16_bytes()!
			}
		}
		binary_op_i8x16_shuffle {
			arguments = BinaryShuffleArgument{
				lanes: decoder.fixed_16_bytes()!
			}
		}
		binary_op_i8x16_extract_lane_s, binary_op_i8x16_extract_lane_u,
		binary_op_i8x16_replace_lane, binary_op_i16x8_extract_lane_s,
		binary_op_i16x8_extract_lane_u, binary_op_i16x8_replace_lane, binary_op_i32x4_extract_lane,
		binary_op_i32x4_replace_lane, binary_op_i64x2_extract_lane, binary_op_i64x2_replace_lane,
		binary_op_f32x4_extract_lane, binary_op_f32x4_replace_lane, binary_op_f64x2_extract_lane,
		binary_op_f64x2_replace_lane {
			arguments = BinaryLaneArgument{
				lane: decoder.byte()!
			}
		}
		else {
			if !binary_opcode_has_no_immediate(opcode) {
				return error('CompileError: unknown instruction')
			}
		}
	}

	return BinaryInstruction{
		opcode:      opcode
		local_index: local_index
		arguments:   arguments
	}
}
