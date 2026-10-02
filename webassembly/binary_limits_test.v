module webassembly

import webidl

fn limits_module(section []u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 5, u8(section.len)]
	bytes << section
	return bytes
}

fn test_memory_section_rejects_the_audited_invalid_binary_and_bad_limits() {
	for payload in [
		[u8(255)], // WA-11: truncated memory count.
		[u8(1)], // A count without a memory type.
		[u8(1), 2, 0], // Threads flags are absent in the upstream snapshot.
		[u8(1), 3, 0, 1],
		[u8(1), 8, 0],
		[u8(1), 1, 2, 1], // Maximum below the minimum.
		[u8(1), 0, 0x81, 0x80, 4], // 65537 memory32 pages.
		[u8(1), 1, 0, 0x81, 0x80, 4], // Maximum exceeds 65536.
		[u8(0), 0], // Trailing bytes after the memory vector.
	] {
		assert !validate(webidl.BufferSource.array_buffer(limits_module(payload))), '${payload}'
	}
}

fn test_memory32_and_memory64_limits_are_parsed_without_allocation() {
	module32 := compile(webidl.BufferSource.array_buffer(limits_module([u8(1), 1, 1, 0x80, 0x80,
		4])))!
	assert module32.memory_types == [WasmLimits{
		minimum: 1
		maximum: u64(65536)
	}]
	// 2^48 is the upstream validator bound for memory64. Validation must not
	// allocate this memory, and must not truncate it to the binding's u32.
	module64 := compile(webidl.BufferSource.array_buffer(limits_module([u8(1), 5, 0, 0x80, 0x80,
		0x80, 0x80, 0x80, 0x80, 0x40])))!
	assert module64.memory_types[0].address_type == .i64
	assert module64.memory_types[0].maximum? == u64(1) << 48
	assert !validate(webidl.BufferSource.array_buffer(limits_module([u8(1), 4, 0x81, 0x80, 0x80,
		0x80, 0x80, 0x80, 0x40])))
}

fn test_limits_leb128_checks_width_and_accepts_valid_padding() {
	mut valid := Decoder{
		bytes: [u8(0x80), 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 1]
	}
	assert valid.u64_leb()! == u64(1) << 63
	mut padded := Decoder{ bytes: [u8(0x80), 0] }
	assert padded.u64_leb()! == 0
	for bytes in [
		[u8(0x80), 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 2],
		[u8(0x80), 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0],
	] {
		mut decoder := Decoder{ bytes: bytes }
		if _ := decoder.u64_leb() {
			assert false
		} else {
			assert err.msg().starts_with('CompileError:')
		}
	}
}

fn test_memory_imports_validate_limits_and_export_indices_include_imports() {
	// One imported memory, env.m, min 1/max 3, then export its index 0.
	bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 2, 11, 1, 3, `e`, `n`, `v`, 1, `m`, 2, 1, 1,
		3, 7, 5, 1, 1, `m`, 2, 0]
	compiled := compile(webidl.BufferSource.array_buffer(bytes))!
	assert compiled.imports()[0].memory_type.minimum == 1
	assert compiled.imports()[0].memory_type.maximum? == 3
	assert compiled.exports()[0].index == 0
	mut bad := bytes.clone()
	bad[20] = 0 // Imported maximum below its minimum.
	assert !validate(webidl.BufferSource.array_buffer(bad))
	bad = bytes.clone()
	bad[bad.len - 1] = 1 // No memory at index 1.
	assert !validate(webidl.BufferSource.array_buffer(bad))
	// No memory section or imports means export index 0 is invalid too.
	assert !validate(webidl.BufferSource.array_buffer([u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 7,
		5, 1, 1, `m`, 2, 0]))
}

fn test_memory_type_metadata_survives_module_serialization() {
	compiled := compile(webidl.BufferSource.array_buffer(limits_module([u8(1), 1, 2, 4])))!
	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(compiled.serialization_steps(false)!)!
	assert restored.memory_types == compiled.memory_types
}
