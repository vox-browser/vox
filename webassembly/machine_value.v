// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/AbstractMachine/AbstractMachine.h: Reference and Value.
module webassembly

import math

pub struct BinaryNullReference {
pub:
	type_ BinaryValueType = BinaryValueType{ kind: .function_reference }
}

pub struct BinaryFunctionReference {
pub:
	address       u64
	source_module &Module = unsafe { nil }
}

pub struct BinaryExternReference {
pub:
	address u64
}

pub struct BinaryExceptionReference {
pub:
	address u64
}

pub struct BinaryI31Reference {
pub:
	value u32
}

pub struct BinaryGcReference {
pub:
	ptr voidptr
}

pub type BinaryMachineReference = BinaryNullReference
	| BinaryFunctionReference
	| BinaryExternReference
	| BinaryExceptionReference
	| BinaryI31Reference
	| BinaryGcReference

// The two-word source u128 representation is intentionally untyped. V's WebIDL
// WasmValue adapter remains separate from this machine record. Actual GC root
// reporting belongs to AbstractMachine::RootsProvider/active configurations.
pub struct BinaryMachineValue {
pub:
	low  u64
	high u64
}

pub fn BinaryMachineValue.from_type(type_ BinaryValueType) BinaryMachineValue {
	return match type_.kind {
		.i32, .i64, .f32, .f64, .v128, .i8, .i16 { BinaryMachineValue{} }
		.function_reference, .no_function_reference { BinaryMachineValue{ high: 2 } }
		.extern_reference, .no_extern_reference { BinaryMachineValue{ high: 3 } }
		.exception_reference, .no_exception_reference { BinaryMachineValue{ high: 4 } }
		.any_reference, .eq_reference, .i31_reference, .struct_reference, .array_reference,
		.none_reference, .type_use_reference {
			BinaryMachineValue{ high: 8 }
		}
	}
}

pub fn BinaryMachineValue.from_reference(reference BinaryMachineReference) BinaryMachineValue {
	return match reference {
		BinaryNullReference {
			match reference.type_.kind {
				.function_reference, .no_function_reference { BinaryMachineValue{ high: 2 } }
				.extern_reference, .no_extern_reference { BinaryMachineValue{ high: 3 } }
				.exception_reference, .no_exception_reference { BinaryMachineValue{ high: 4 } }
				else { BinaryMachineValue{ high: 8 } }
			}
		}
		BinaryFunctionReference {
			BinaryMachineValue{ low: reference.address, high: u64(voidptr(reference.source_module)) }
		}
		BinaryExternReference { BinaryMachineValue{ low: reference.address, high: 1 } }
		BinaryExceptionReference { BinaryMachineValue{ low: reference.address, high: 5 } }
		BinaryI31Reference { BinaryMachineValue{ low: u64(reference.value & 0x7fffffff), high: 7 } }
		BinaryGcReference { BinaryMachineValue{ low: u64(reference.ptr), high: 6 } }
	}
}

pub fn BinaryMachineValue.from_i8(value i8) BinaryMachineValue {
	return BinaryMachineValue{ low: u64(i64(value)) }
}

pub fn BinaryMachineValue.from_u8(value u8) BinaryMachineValue {
	return BinaryMachineValue{ low: u64(value) }
}

pub fn BinaryMachineValue.from_i16(value i16) BinaryMachineValue {
	return BinaryMachineValue{ low: u64(i64(value)) }
}

pub fn BinaryMachineValue.from_u16(value u16) BinaryMachineValue {
	return BinaryMachineValue{ low: u64(value) }
}

pub fn BinaryMachineValue.from_i32(value i32) BinaryMachineValue {
	return BinaryMachineValue{ low: u64(i64(value)) }
}

pub fn BinaryMachineValue.from_u32(value u32) BinaryMachineValue {
	return BinaryMachineValue.from_i32(i32(value))
}

pub fn BinaryMachineValue.from_i64(value i64) BinaryMachineValue {
	return BinaryMachineValue{ low: u64(value) }
}

pub fn BinaryMachineValue.from_u64(value u64) BinaryMachineValue {
	return BinaryMachineValue{ low: value }
}

pub fn BinaryMachineValue.from_f32(value f32) BinaryMachineValue {
	return BinaryMachineValue.from_u32(math.f32_bits(value))
}

pub fn BinaryMachineValue.from_f64(value f64) BinaryMachineValue {
	return BinaryMachineValue.from_u64(math.f64_bits(value))
}

pub fn (value BinaryMachineValue) to_i8() i8 { return i8(value.low & 0xff) }

pub fn (value BinaryMachineValue) to_u8() u8 { return u8(value.low & 0xff) }

pub fn (value BinaryMachineValue) to_i16() i16 { return i16(value.low & 0xffff) }

pub fn (value BinaryMachineValue) to_u16() u16 { return u16(value.low & 0xffff) }

pub fn (value BinaryMachineValue) to_i32() i32 { return i32(value.low & 0xffffffff) }

pub fn (value BinaryMachineValue) to_u32() u32 { return u32(value.low & 0xffffffff) }

pub fn (value BinaryMachineValue) to_i64() i64 { return i64(value.low) }

pub fn (value BinaryMachineValue) to_u64() u64 { return value.low }

pub fn (value BinaryMachineValue) to_f32() f32 { return math.f32_from_bits(value.to_u32()) }

pub fn (value BinaryMachineValue) to_f64() f64 { return math.f64_from_bits(value.low) }

pub fn (value BinaryMachineValue) gc_cell() voidptr {
	if value.high == 6 || value.high == (9 | (6 << 8)) { return unsafe { voidptr(value.low) } }
	return unsafe { nil }
}

pub fn (value BinaryMachineValue) to_reference() BinaryMachineReference {
	return match value.high {
		1, 10 { BinaryMachineReference(BinaryExternReference{ address: value.low }) }
		2 {
			BinaryMachineReference(BinaryNullReference{ type_: BinaryValueType{ kind: .function_reference } })
		}
		3 {
			BinaryMachineReference(BinaryNullReference{ type_: BinaryValueType{ kind: .extern_reference } })
		}
		4 {
			BinaryMachineReference(BinaryNullReference{ type_: BinaryValueType{ kind: .exception_reference } })
		}
		5 { BinaryMachineReference(BinaryExceptionReference{ address: value.low }) }
		6, 9 | (6 << 8) {
			BinaryMachineReference(BinaryGcReference{ ptr: unsafe { voidptr(value.low) } })
		}
		7, 9 | (7 << 8) { BinaryMachineReference(BinaryI31Reference{ value: u32(value.low) }) }
		8 {
			BinaryMachineReference(BinaryNullReference{ type_: BinaryValueType{ kind: .any_reference } })
		}
		else {
			BinaryMachineReference(BinaryFunctionReference{ address: value.low, source_module: unsafe { &Module(voidptr(value.high)) } })
		}
	}
}
