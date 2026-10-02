// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

module webassembly

// LibWasm/Parser/Parser.cpp: Limits::parse, MemoryType::parse and
// MemorySection::parse; AbstractMachine/Validator.cpp: validate(Limits),
// validate(MemoryType), and the memory export index check.
pub struct WasmLimits {
pub:
	address_type AddressType
	minimum      u64
	maximum      ?u64
}

fn (mut decoder Decoder) u64_leb() !u64 {
	mut value := u64(0)
	for count in 0 .. 10 {
		byte := decoder.byte()!
		payload := u64(byte & 0x7f)
		if count == 9 && payload > 1 {
			return error('CompileError: integer representation too long')
		}
		value |= payload << u32(count * 7)
		if byte & 0x80 == 0 {
			return value
		}
	}
	return error('CompileError: integer representation too long')
}

fn parse_limits(mut decoder Decoder) !WasmLimits {
	flag := decoder.byte()!
	// This snapshot implements memory64, but not the threads proposal's
	// shared-limits flags. Limits are read as u64 for both address types.
	if flag & ~u8(0b00000101) != 0 {
		return error('CompileError: invalid limits flags')
	}
	minimum := decoder.u64_leb()!
	mut maximum := ?u64(none)
	if flag & 1 != 0 {
		maximum = decoder.u64_leb()!
	}
	return WasmLimits{
		address_type: if flag & 4 != 0 { .i64 } else { .i32 }
		minimum:      minimum
		maximum:      maximum
	}
}

fn validate_limits(limits WasmLimits, bound ?u64) ! {
	if maximum_bound := bound {
		if limits.minimum > maximum_bound {
			return error('CompileError: limit minimum is out of bounds')
		}
	}
	if maximum := limits.maximum {
		if maximum < limits.minimum {
			return error('CompileError: limit maximum is smaller than minimum')
		}
		if maximum_bound := bound {
			if maximum > maximum_bound {
				return error('CompileError: limit maximum is out of bounds')
			}
		}
	}
}

fn validate_memory_type(limits WasmLimits) ! {
	bound := if limits.address_type == .i64 { u64(1) << 48 } else { u64(1) << 16 }
	validate_limits(limits, bound)!
}

fn parse_memory_section(mut decoder Decoder, mut result []WasmLimits) ! {
	count := decoder.u32_leb()!
	for _ in 0 .. count {
		result << parse_limits(mut decoder)!
	}
}
