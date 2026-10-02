// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// LibWasm Parser.cpp: value/storage/reference/heap, composite and recursive
// type parsing. These records preserve the binary type section for the
// subsequent LibWasm type-system and instruction-validator translation.
module webassembly

pub enum BinaryValueKind {
	i32
	i64
	f32
	f64
	v128
	i8
	i16
	function_reference
	no_function_reference
	extern_reference
	no_extern_reference
	any_reference
	eq_reference
	i31_reference
	struct_reference
	array_reference
	none_reference
	exception_reference
	no_exception_reference
	type_use_reference
}

pub struct BinaryValueType {
pub:
	kind       BinaryValueKind
	nullable   bool = true
	type_index u32
}

pub struct BinaryFieldType {
pub:
	mutable_ bool
	type_    BinaryValueType
}

pub enum BinaryCompositeKind {
	function_
	struct_
	array
}

pub struct BinaryRecGroupSpan {
pub:
	start u32
	count u32
}

pub struct BinaryDefinedType {
pub:
	kind       BinaryCompositeKind
	parameters []BinaryValueType
	results    []BinaryValueType
	fields     []BinaryFieldType
	supertypes []u32
	is_final   bool = true
pub mut:
	rec_group BinaryRecGroupSpan
}

// Parser.cpp parse_signed_integer_of_size<N>, used by heap types with N=33.
fn (mut decoder Decoder) signed_leb(bits u32) !i64 {
	mut result := i64(0)
	mut shift := u32(0)
	max_bytes := (bits + 6) / 7
	for i := u32(0); i < max_bytes; i++ {
		byte := decoder.byte()!
		if byte & 0x80 == 0 {
			remaining_bits := if bits - 7 * i < 7 { bits - 7 * i } else { u32(7) }
			sign_bit := u8(1 << (remaining_bits - 1))
			unused_mask := u8(0x7f & ~(u8(sign_bit << 1) - 1))
			if (byte & sign_bit != 0 && byte & unused_mask != unused_mask)
				|| (byte & sign_bit == 0 && byte & unused_mask != 0) {
				return error('CompileError: invalid signed immediate')
			}
			result |= i64(byte & 0x7f) << shift
			shift += 7
			if shift < 64 && byte & 0x40 != 0 { result |= ~i64(0) << shift }
			return result
		}
		result |= i64(byte & 0x7f) << shift
		shift += 7
	}
	return error('CompileError: invalid signed immediate')
}

fn abstract_heap_type_from_tag(tag u8) ?BinaryValueKind {
	return match tag {
		0x69 { BinaryValueKind.exception_reference }
		0x6a { BinaryValueKind.array_reference }
		0x6b { BinaryValueKind.struct_reference }
		0x6c { BinaryValueKind.i31_reference }
		0x6d { BinaryValueKind.eq_reference }
		0x6e { BinaryValueKind.any_reference }
		0x6f { BinaryValueKind.extern_reference }
		0x70 { BinaryValueKind.function_reference }
		0x71 { BinaryValueKind.none_reference }
		0x72 { BinaryValueKind.no_extern_reference }
		0x73 { BinaryValueKind.no_function_reference }
		0x74 { BinaryValueKind.no_exception_reference }
		else { none }
	}
}

fn parse_heap_type(mut decoder Decoder) !BinaryValueType {
	tag := decoder.byte()!
	if kind := abstract_heap_type_from_tag(tag) { return BinaryValueType{ kind: kind } }
	decoder.offset--
	index := decoder.signed_leb(33)!
	if index < 0 || index > i64(max_u32) { return error('CompileError: invalid heap type index') }
	return BinaryValueType{ kind: .type_use_reference, type_index: u32(index) }
}

fn parse_reference_type(mut decoder Decoder, tag u8) !BinaryValueType {
	if tag in [u8(0x63), 0x64] {
		heap := parse_heap_type(mut decoder)!
		return BinaryValueType{ ...heap, nullable: tag == 0x63 }
	}
	if kind := abstract_heap_type_from_tag(tag) { return BinaryValueType{ kind: kind } }
	return error('CompileError: invalid reference type')
}

fn parse_binary_value_type(mut decoder Decoder) !BinaryValueType {
	tag := decoder.byte()!
	kind := match tag {
		0x7f { BinaryValueKind.i32 }
		0x7e { BinaryValueKind.i64 }
		0x7d { BinaryValueKind.f32 }
		0x7c { BinaryValueKind.f64 }
		0x7b { BinaryValueKind.v128 }
		else { return parse_reference_type(mut decoder, tag) }
	}
	return BinaryValueType{ kind: kind }
}

fn parse_binary_field_type(mut decoder Decoder) !BinaryFieldType {
	tag := decoder.byte()!
	mut type_ := BinaryValueType{}
	if tag in [u8(0x77), 0x78] {
		type_ = BinaryValueType{
			kind: if tag == 0x77 {
				BinaryValueKind.i16
			} else {
				BinaryValueKind.i8
			}
		}
	} else {
		decoder.offset--
		type_ = parse_binary_value_type(mut decoder)!
	}
	mutable_ := decoder.byte()!
	if mutable_ > 1 { return error('CompileError: invalid field mutability') }
	return BinaryFieldType{ type_: type_, mutable_: mutable_ == 1 }
}

fn parse_binary_value_type_vector(mut decoder Decoder) ![]BinaryValueType {
	count := decoder.u32_leb()!
	mut types := []BinaryValueType{}
	for _ in 0 .. count { types << parse_binary_value_type(mut decoder)! }
	return types
}

fn parse_defined_type(mut decoder Decoder, leading_tag ?u8) !BinaryDefinedType {
	mut tag := leading_tag or { decoder.byte()! }
	mut is_final := true
	mut supertypes := []u32{}
	if tag in [u8(0x4f), 0x50] {
		is_final = tag == 0x4f
		count := decoder.u32_leb()!
		for _ in 0 .. count { supertypes << decoder.u32_leb()! }
		tag = decoder.byte()!
	}
	match tag {
		0x60 {
			parameters := parse_binary_value_type_vector(mut decoder)!
			results := parse_binary_value_type_vector(mut decoder)!
			return BinaryDefinedType{ kind: .function_, parameters: parameters, results: results, supertypes: supertypes, is_final: is_final }
		}
		0x5f {
			count := decoder.u32_leb()!
			mut fields := []BinaryFieldType{}
			for _ in 0 .. count { fields << parse_binary_field_type(mut decoder)! }
			return BinaryDefinedType{ kind: .struct_, fields: fields, supertypes: supertypes, is_final: is_final }
		}
		0x5e {
			field := parse_binary_field_type(mut decoder)!
			return BinaryDefinedType{ kind: .array, fields: [field], supertypes: supertypes, is_final: is_final }
		}
		else { return error('CompileError: invalid composite type tag') }
	}
}

fn parse_type_section(mut decoder Decoder) ![]BinaryDefinedType {
	count := decoder.u32_leb()!
	mut types := []BinaryDefinedType{}
	for _ in 0 .. count {
		tag := decoder.byte()!
		first := types.len
		if tag == 0x4e {
			sub_count := decoder.u32_leb()!
			for _ in 0 .. sub_count { types << parse_defined_type(mut decoder, none)! }
		} else {
			types << parse_defined_type(mut decoder, tag)!
		}
		span := BinaryRecGroupSpan{ start: u32(first), count: u32(types.len - first) }
		for i in first .. types.len { types[i].rec_group = span }
	}
	return types
}
