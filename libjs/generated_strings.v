module libjs

// Builtin split/join results have ordinary code-unit storage. Keep their small
// immutable results in a separate bounded cache; create_string's public cloning
// and source/IPC storage contracts remain unchanged.
const generated_string_cache_slots = 256
const generated_string_cache_units = 64

$if test {
	__global generated_strings_disabled bool
	pub fn set_generated_strings_for_testing(enabled bool) {
		generated_strings_disabled = !enabled
	}
}

fn use_generated_strings() bool {
	$if test { if generated_strings_disabled { return false } }
	return true
}

fn generated_string_hash_append(initial u32, units []u16) u32 {
	mut hash := initial
	for unit in units {
		hash = (hash ^ u32(unit & 255)) * 16777619
		hash = (hash ^ u32(unit >> 8)) * 16777619
	}
	return hash
}

fn (mut vm VM) remember_generated_string(units []u16, hash u32) &PrimitiveString {
	// The caller supplied views or temporary join storage. Own the only retained
	// copy, including on cache misses; no result aliases a mutable caller buffer.
	result := &PrimitiveString{utf16: Utf16String{data: units.clone()}}
	if units.len <= generated_string_cache_units {
		if vm.generated_string_cache.len == 0 {
			vm.generated_string_cache = []?&PrimitiveString{len: generated_string_cache_slots}
		}
		vm.generated_string_cache[int(hash & (generated_string_cache_slots - 1))] = result
	}
	return result
}

fn (mut vm VM) generated_string_hit() {
	if mut tier := vm.native_tier {
		if tier.diagnostics { tier.activity.generated_string_hits++ }
	}
}

fn (mut vm VM) create_generated_string(units []u16) &PrimitiveString {
	if !use_generated_strings() { return vm.create_string(Utf16String.from_slice(units)) }
	if units.len == 0 { return vm.empty_string() }
	if units.len == 1 && units[0] < 128 { return vm.single_ascii_character_string(u8(units[0])) }
	mut hash := u32(0)
	if units.len <= generated_string_cache_units {
		hash = generated_string_hash_append(2166136261, units)
		if vm.generated_string_cache.len != 0 {
			if cached := vm.generated_string_cache[int(hash & (generated_string_cache_slots - 1))] {
				if utf16_equals(cached.utf16.data, units) {
					vm.generated_string_hit()
					return cached
				}
			}
		}
	}
	return vm.remember_generated_string(units, hash)
}

fn generated_parts_equal(units []u16, parts []Utf16String, length int) bool {
	if units.len != length { return false }
	mut offset := 0
	for part in parts {
		for unit in part.data {
			if units[offset] != unit { return false }
			offset++
		}
	}
	return true
}

fn (mut vm VM) create_generated_join(parts []Utf16String) &PrimitiveString {
	if !use_generated_strings() { return vm.create_string(utf16_concat(parts)) }
	mut length := 0
	for part in parts { length += part.data.len }
	if length == 0 { return vm.empty_string() }
	if length == 1 {
		for part in parts { if part.data.len == 1 { return vm.create_generated_string(part.data) } }
	}
	mut hash := u32(0)
	if length <= generated_string_cache_units {
		hash = u32(2166136261)
		for part in parts { hash = generated_string_hash_append(hash, part.data) }
		if vm.generated_string_cache.len != 0 {
			if cached := vm.generated_string_cache[int(hash & (generated_string_cache_slots - 1))] {
				if generated_parts_equal(cached.utf16.data, parts, length) {
					vm.generated_string_hit()
					return cached
				}
			}
		}
	}
	mut units := []u16{len: length}
	mut offset := 0
	for part in parts {
		for unit in part.data { units[offset] = unit; offset++ }
	}
	// This buffer is newly allocated and never exposed. Transfer it directly
	// instead of cloning an intermediate builder and then cloning it again.
	result := &PrimitiveString{utf16: Utf16String{data: units}}
	if length <= generated_string_cache_units {
		if vm.generated_string_cache.len == 0 {
			vm.generated_string_cache = []?&PrimitiveString{len: generated_string_cache_slots}
		}
		vm.generated_string_cache[int(hash & (generated_string_cache_slots - 1))] = result
	}
	return result
}
