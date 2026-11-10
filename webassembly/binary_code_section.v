// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

// The JS API's implementation limit includes the local declarations.
const binary_max_function_size = u32(7654321)

pub struct BinaryLocals {
pub:
	count u32
	type_ BinaryValueType
}

pub struct BinaryFunctionBody {
	total_local_count_ uint
pub:
	declared_size u32
	locals        []BinaryLocals
pub mut:
	body BinaryExpression
}

// CodeSection::Func constructor caches the sum once, before publishing Code.
// This combines the source Code(size, Func(locals, body)) record construction.
pub fn BinaryFunctionBody.create(size u32, locals []BinaryLocals, body BinaryExpression) BinaryFunctionBody {
	mut total := uint(0)
	for local in locals { total += uint(local.count) }
	return BinaryFunctionBody{
		declared_size: size
		locals: locals
		body: body
		total_local_count_: total
	}
}

pub fn (function &BinaryFunctionBody) total_local_count() uint {
	return function.total_local_count_
}

// Parser.cpp::Locals::parse and CodeSection::{Func,Code,parse}. A function
// body is constrained to its declared byte size before its local declarations
// and expression are consumed, and must consume that complete slice.
fn parse_code_section(mut decoder Decoder) ![]BinaryFunctionBody {
	count := decoder.u32_leb()!
	mut functions := []BinaryFunctionBody{}
	for _ in 0 .. count {
		size := decoder.u32_leb()!
		if u64(size) > u64(decoder.bytes.len - decoder.offset) {
			return error('CompileError: function body extends beyond code section')
		}
		if size > binary_max_function_size {
			return error('CompileError: function body too large')
		}
		mut body_decoder := Decoder{ bytes: decoder.bytes[decoder.offset..decoder.offset + int(size)] }
		local_groups := body_decoder.u32_leb()!
		mut locals := []BinaryLocals{}
		mut declared_local_count := u64(0)
		for _ in 0 .. local_groups {
			local_count := body_decoder.u32_leb()!
			declared_local_count += u64(local_count)
			if declared_local_count > u64(max_u32) {
				return error('CompileError: too many locals')
			}
			locals << BinaryLocals{ count: local_count, type_: parse_binary_value_type(mut body_decoder)! }
		}
		body := parse_binary_expression_with_hint(mut body_decoder, uint(size / 2))!
		if body_decoder.offset != body_decoder.bytes.len {
			return error('CompileError: function body size mismatch')
		}
		decoder.offset += int(size)
		functions << BinaryFunctionBody.create(size, locals, body)
	}
	return functions
}
