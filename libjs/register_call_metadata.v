module libjs

import platform

@[heap]
struct FunctionRegisterNameIndex {
	count int
	data  voidptr
mut:
	positions map[u64]int
}

$if test {
	__global register_call_metadata_disabled bool
	__global register_call_metadata_diagnostics bool
	__global register_call_metadata_reads u64
	pub fn set_register_call_metadata_for_testing(enabled bool) {
		register_call_metadata_disabled = !enabled
	}
	pub fn diagnose_register_call_metadata_for_testing(enabled bool) u64 {
		previous := register_call_metadata_reads
		register_call_metadata_reads = 0
		register_call_metadata_diagnostics = enabled
		return previous
	}
}

fn use_register_call_metadata() bool {
	$if test {
		if register_call_metadata_disabled { return false }
	}
	return true
}

// Compiler-created private metadata has one register binding per parameter
// index. Find and initialize that slot in one pass instead of scanning twice.
fn (function &ECMAScriptFunction) parameter_register(index int) ?u32 {
	for binding in function.register_bindings {
		if binding.parameter_index == index {
			$if test {
				if register_call_metadata_diagnostics { register_call_metadata_reads++ }
			}
			return binding.slot
		}
	}
	return none
}

// The compiler sets this private vector once, or replaces it when loading a
// realm-local compiled body. Its complete bounded index can answer absence;
// hash collisions still use the original exact comparison.
fn (function &ECMAScriptFunction) indexed_register_name(name Utf16String) ?bool {
	count := function.register_bindings.len
	if count < 8 || count > 256 { return none }
	executable := function.executable or { return none }
	// Closure instances share this realm-local compiled body and its immutable
	// register metadata. Build one name index for that body, not per closure.
	mut owner := unsafe { &Executable(executable) }
	mut index := owner.register_name_index or { &FunctionRegisterNameIndex{} }
	if index.count != count || index.data != function.register_bindings.data {
		persistent := platform.enter_persistent()
		index = &FunctionRegisterNameIndex{ count: count, data: function.register_bindings.data }
		for position, binding in function.register_bindings {
			index.positions[binding_lookup_hash(binding.name)] = position
		}
		owner.register_name_index = index
		platform.leave_persistent(persistent)
	}
	$if test {
		if register_call_metadata_diagnostics { register_call_metadata_reads++ }
	}
	position := index.positions[binding_lookup_hash(name)] or { return false }
	if function.register_bindings[position].name == name { return true }
	return none
}
