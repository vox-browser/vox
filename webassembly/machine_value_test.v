module webassembly

import math

fn test_machine_value_scalar_storage_preserves_source_sign_extension_and_low_bit_views() {
	assert sizeof(BinaryMachineValue) == 16
	assert BinaryMachineValue.from_i8(-1).low == 0xffffffffffffffff
	assert BinaryMachineValue.from_u8(255).low == 255
	assert BinaryMachineValue.from_i16(-2).low == 0xfffffffffffffffe
	assert BinaryMachineValue.from_u16(65535).low == 65535
	assert BinaryMachineValue.from_u32(0x80000001).low == 0xffffffff80000001
	assert BinaryMachineValue.from_i32(-2147483647).high == 0
	value := BinaryMachineValue{ low: 0xfedcba98765480fe, high: 123 }
	assert value.to_u8() == 254 && value.to_i8() == -2
	assert value.to_u16() == 0x80fe && value.to_i16() == -32514
	assert value.to_u32() == 0x765480fe && value.to_i32() == i32(0x765480fe)
	assert value.to_u64() == value.low && value.to_i64() == i64(value.low)
	assert BinaryMachineValue.from_i64(-9223372036854775807).to_i64() == -9223372036854775807
}

fn test_machine_value_float_bits_preserve_signed_zero_infinities_and_nan_payloads() {
	for raw in [u32(0), 0x80000000, 0x7f800000, 0xff800000, 0x7fc12345, 0xffc12345] {
		value := BinaryMachineValue.from_f32(math.f32_from_bits(raw))
		assert value.low == u64(i64(i32(raw))) && value.high == 0
		assert math.f32_bits(value.to_f32()) == raw
	}
	for raw in [u64(0), 0x8000000000000000, 0x7ff0000000000000, 0xfff0000000000000, 0x7ff8000000012345,
		0xfff8000000012345] {
		value := BinaryMachineValue.from_f64(math.f64_from_bits(raw))
		assert value.low == raw && value.high == 0
		assert math.f64_bits(value.to_f64()) == raw
	}
}

fn test_machine_reference_null_tags_follow_source_heap_hierarchies_and_erase_narrow_null_type() {
	for kind in [BinaryValueKind.i32, .i64, .f32, .f64, .v128, .i8, .i16] {
		assert BinaryMachineValue.from_type(BinaryValueType{ kind: kind }) == BinaryMachineValue{}
		assert BinaryMachineValue.from_reference(BinaryNullReference{ type_: BinaryValueType{ kind: kind } }).high == 8
	}
	for kind in [BinaryValueKind.function_reference, .no_function_reference] {
		value := BinaryMachineValue.from_type(BinaryValueType{ kind: kind })
		assert value == BinaryMachineValue{ high: 2 }
		assert (value.to_reference() as BinaryNullReference).type_.kind == .function_reference
	}
	for kind in [BinaryValueKind.extern_reference, .no_extern_reference] {
		value := BinaryMachineValue.from_reference(BinaryNullReference{ type_: BinaryValueType{ kind: kind } })
		assert value.high == 3 && (value.to_reference() as BinaryNullReference).type_.kind == .extern_reference
	}
	for kind in [BinaryValueKind.exception_reference, .no_exception_reference] {
		value := BinaryMachineValue.from_type(BinaryValueType{ kind: kind })
		assert value.high == 4 && (value.to_reference() as BinaryNullReference).type_.kind == .exception_reference
	}
	for kind in [BinaryValueKind.any_reference, .eq_reference, .i31_reference, .struct_reference,
		.array_reference, .none_reference, .type_use_reference] {
		value := BinaryMachineValue.from_type(BinaryValueType{ kind: kind, type_index: 123 })
		assert value.high == 8 && (value.to_reference() as BinaryNullReference).type_.kind == .any_reference
	}
}

fn test_machine_reference_identity_scalar_masking_and_externalized_boxing_follow_raw_source_tags() {
	module_ := &Module{}
	function := BinaryFunctionReference{ address: 42, source_module: module_ }
	value := BinaryMachineValue.from_reference(function)
	assert value.low == 42 && value.high == u64(voidptr(module_))
	decoded := value.to_reference() as BinaryFunctionReference
	assert decoded.address == 42 && voidptr(decoded.source_module) == voidptr(module_)
	host := BinaryMachineValue.from_reference(BinaryFunctionReference{ address: 3 })
	assert host.high == 0 && (host.to_reference() as BinaryFunctionReference).address == 3
	assert (BinaryMachineValue.from_reference(BinaryExceptionReference{ address: 7 }).to_reference() as BinaryExceptionReference).address == 7
	assert BinaryMachineValue.from_reference(BinaryI31Reference{ value: 0xffffffff }).low == 0x7fffffff
	cell := &BinaryCanonicalType{}
	for high in [u64(6), 9 | (6 << 8)] {
		gc := BinaryMachineValue{ low: u64(voidptr(cell)), high: high }
		assert gc.gc_cell() == voidptr(cell)
		assert (gc.to_reference() as BinaryGcReference).ptr == voidptr(cell)
	}
	externalized_scalar := BinaryMachineValue{ low: 17, high: 9 | (7 << 8) }
	assert (externalized_scalar.to_reference() as BinaryI31Reference).value == 17
	for high in [u64(1), 10] {
		internalized := BinaryMachineValue{ low: 99, high: high }
		assert (internalized.to_reference() as BinaryExternReference).address == 99
		assert internalized.gc_cell() == unsafe { nil }
	}
}
