module libjs

import platform

// A property instruction remembers the own-property position where it last
// found its key. Own keys are unique, so a matching key at that position is the
// property itself; objects built in the same order (one constructor or literal
// site) share the position. Mismatches, absent keys and exotic objects take
// the ordinary lookup, which refreshes the position.
const no_property_hint = u32(0xffffffff)

// One slot per instruction, owned by the compiled body (closures share it).
@[inline]
fn (executable &Executable) property_hint(pc u32) &u32 {
	if executable.property_hints.len != executable.instructions.len {
		persistent := platform.enter_persistent()
		mut owner := unsafe { &Executable(executable) }
		owner.property_hints = []u32{len: executable.instructions.len, init: no_property_hint}
		platform.leave_persistent(persistent)
	}
	// run_executable() dispatches only instructions inside the stream.
	return unsafe { &u32(executable.property_hints.data) + pc }
}

fn (object &Object) hinted_get(mut vm VM, key PropertyName, receiver Value, hint &u32) !Value {
	if object.proxy_object != none || object.array_object != none || object.indexed_properties != none
		|| !object.reads_directly() {
		return object.internal_get(mut vm, key, receiver)
	}
	position := unsafe { *hint }
	mut index := int(position)
	if position < u32(object.properties.len) && object.properties[position].key.equals(key) {
		$if test { if property_hint_diagnostics { property_hint_hits++ } }
	} else {
		index = object.find_own_property(key)
		if index < 0 { return object.get_inherited(mut vm, key, receiver) }
		unsafe {
			*hint = u32(index)
		}
	}
	value := object.properties[index].value
	if !value.is_accessor() {
		record_direct_property_read()
		return value
	}
	// Own accessors keep [[Get]]'s complete dispatch and caching.
	return object.internal_get(mut vm, key, receiver)
}

$if test {
	__global property_hint_diagnostics bool
	__global property_hint_hits u64
	pub fn diagnose_property_hints_for_testing(enabled bool) u64 {
		previous := property_hint_hits
		property_hint_hits = 0
		property_hint_diagnostics = enabled
		return previous
	}
}
