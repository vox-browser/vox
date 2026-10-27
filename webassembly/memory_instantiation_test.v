module webassembly

import webidl

fn declared_memories_binary() []u8 {
	return [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 
	// Two memories: min 1/max 2; min 2/max 4.
	5, 7, 2, 1, 1, 2, 1, 2, 4, 
	// b exports memory 1, a/alias export memory 0.
	7, 17, 3, 1, `b`, 2, 1, 1, `a`, 2, 0, 5, `a`, `l`, `i`, `a`, `s`, 2, 0]
}

fn test_instantiation_uses_declared_memory_sizes_and_export_indices() {
	compiled := compile(webidl.BufferSource.array_buffer(declared_memories_binary()))!
	first := Instance.create_for_realm('declared-memory-one', compiled, ImportObject{})!
	objects := first.exports_for_realm('declared-memory-one')
	mut a := objects.memory_objects['a'] or { panic('missing a') }
	b := objects.memory_objects['b'] or { panic('missing b') }
	alias := objects.memory_objects['alias'] or { panic('missing alias') }
	assert a.size_pages() == 1
	assert a.maximum? == 2
	assert b.size_pages() == 2
	assert b.maximum? == 4
	assert voidptr(a) == voidptr(alias)
	assert voidptr(a) != voidptr(b)
	assert a.buffer().read_bytes(0, uint(page_size)) == []u8{len: page_size}
	assert first.module_instance().memories.len == 2
	a.grow(1)!
	assert alias.size_pages() == 2
	// Allocations are per instantiation, never per export name or module.
	second := Instance.create_for_realm('declared-memory-two', compiled, ImportObject{})!
	second_a := second.exports_for_realm('declared-memory-two').memory_objects['a'] or {
		panic('missing second a')
	}
	assert second_a.size_pages() == 1
	assert voidptr(second_a) != voidptr(a)
}

fn imported_memory_binary() []u8 {
	return [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 2, 11, 1, 3, `e`, `n`, `v`, 1, `m`, 2, 1, 1, 4,
		5, 4, 1, 1, 3, 5, 7, 11, 2, 1, `a`, 2, 0, 3, `n`, `e`, `w`, 2, 1]
}

fn test_imported_memory_is_preserved_and_precedes_defined_memories() {
	compiled := compile(webidl.BufferSource.array_buffer(imported_memory_binary()))!
	mut original := Memory.construct(MemoryDescriptor{ initial: 2, maximum: 3 })!
	imports := {
		'env': {
			'm': external_memory_value(original)
		}
	}
	instance := Instance.create_for_realm('import-memory-other-realm', compiled, imports)!
	exports := instance.exports_for_realm('import-memory-other-realm')
	alias := exports.memory_objects['a'] or { panic('missing imported memory') }
	defined := exports.memory_objects['new'] or { panic('missing defined memory') }
	assert voidptr(alias) == voidptr(original)
	assert defined.size_pages() == 3
	assert defined.maximum? == 5
	original.grow(1)!
	assert alias.size_pages() == 3
	// The ExternalValue carries the actual Memory for WebAssembly ES module
	// imports too, instead of only an indistinguishable platform-object token.
	mut dependency := WebAssemblyModule.create('memory-dependency', '', compiled)
	dependency.link_javascript_module('env', {
		'm': external_memory_value(original)
	})
	dependency.execute_module()!
	value := dependency.environment()?.get_binding_value('a')!
	assert voidptr(value.memory?) == voidptr(original)
}

fn test_memory_import_types_require_a_memory_and_match_upstream_limits() {
	compiled := compile(webidl.BufferSource.array_buffer(imported_memory_binary()))!
	for value in [
		ExternalValue{ kind: .memory, value: webidl.platform_object_value() },
		external_memory_value(Memory.construct(MemoryDescriptor{ initial: 0, maximum: 4 })!),
		external_memory_value(Memory.construct(MemoryDescriptor{ initial: 1, maximum: 5 })!),
		external_memory_value(Memory.construct(MemoryDescriptor{ initial: 1 })!),
	] {
		if _ := Instance.create(compiled, {
			'env': {
				'm': value
			}
		}) {
			assert false
		} else {
			assert err.msg().starts_with('LinkError:')
		}
	}
}

fn test_memory64_runtime_capacity_matches_current_upstream_cap() {
	// The validator accepts 65537 memory64 pages, while the current machine
	// restricts allocation to 65536 pages. Compilation and allocation differ.
	compiled := compile(webidl.BufferSource.array_buffer([u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0,
		5, 5, 1, 4, 0x81, 0x80, 4]))!
	if _ := Instance.create(compiled, ImportObject{}) {
		assert false
	} else {
		assert err.msg() == 'LinkError: Failed to allocate a memory instance'
	}
	// Preserve the declared 64-bit type, with the real runtime growth cap.
	compiled64 := compile(webidl.BufferSource.array_buffer([u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0,
		5, 6, 1, 5, 0, 0x81, 0x80, 4]))!
	instance := Instance.create(compiled64, ImportObject{})!
	memory := instance.module_instance().memories[0]
	assert memory.wasm_type().address_type == .i64
	assert memory.wasm_type().maximum? == 65537
	assert memory.maximum? == 65536
	assert !matches_memory_limits(memory.wasm_type(), WasmLimits{})
}
