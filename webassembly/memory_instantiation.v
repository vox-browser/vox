// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

module webassembly

import webidl

// LibWasm/TypeSystem.cpp: matches_limits and matches_memory_type.
fn matches_memory_limits(actual WasmLimits, required WasmLimits) bool {
	if actual.address_type != required.address_type || actual.minimum < required.minimum {
		return false
	}
	if required_max := required.maximum {
		actual_max := actual.maximum or { return false }
		if actual_max > required_max {
			return false
		}
	}
	return true
}

// LibWasm/AbstractMachine/AbstractMachine.cpp: MemoryInstance::create,
// maximum_memory_size, allocate_all_initial_phase (memory declarations).
// This snapshot caps runtime memory64 allocations at wasm32_max_pages even
// though the validator permits memory64 limits up to 2^48 pages.
fn memory_create_for_module_with_cache(cache &WebAssemblyCache, limits WasmLimits) !&Memory {
	validate_memory_type(limits)!
	if limits.minimum > u64(maximum_pages) {
		return error('LinkError: Failed to allocate a memory instance')
	}
	mut runtime_maximum := ?u32(none)
	if maximum := limits.maximum {
		limit := if maximum > u64(maximum_pages) { u64(maximum_pages) } else { maximum }
		runtime_maximum = u32(limit)
	}
	memory := &Memory{
		maximum:          runtime_maximum
		cache_:           cache
		address_type_:    limits.address_type
		declared_maximum: limits.maximum
		data:             []u8{len: int(limits.minimum) * page_size}
	}
	unsafe { cache.add_memory_instance(memory.address(), memory) }
	return memory
}

pub fn external_memory_value(memory &Memory) ExternalValue {
	return ExternalValue{
		kind:   .memory
		value:  webidl.platform_object_value()
		memory: memory
	}
}
