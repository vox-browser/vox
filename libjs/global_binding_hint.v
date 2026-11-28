module libjs

// Successful own-data reads only. The ordered live property array remains
// authoritative; neither a value nor absence is cached. A borrowed name address
// selects a slot but is never dereferenced after the call: owned UTF-16 content
// is checked as well, so reused/mutated input storage cannot create a false hit.
const global_binding_hint_slots = 256

struct GlobalBindingHint {
	object &Object = unsafe { nil }
	owner &PrimitiveString = unsafe { nil }
	key PropertyName
	index int
}

$if test {
	__global global_binding_hints_disabled bool
	pub fn set_global_binding_hints_for_testing(enabled bool) { global_binding_hints_disabled = !enabled }
}

@[inline]
fn use_global_binding_hints() bool {
	$if test { if global_binding_hints_disabled { return false } }
	return true
}

fn global_binding_hint_slot(object &Object, name Utf16String) int {
	return int(((u64(uint(object)) >> 4) ^ (u64(uint(name.data.data)) >> 4)) & (global_binding_hint_slots - 1))
}

// Called only after the lexical shadowing and exotic-object guards. A cache
// hit still checks the current key and value, including accessor replacements.
fn (mut vm VM) live_global_data_binding(object &Object, name Utf16String) ?Value {
	eligible := use_global_binding_hints() && name.data.len <= 64
	mut slot := 0
	if eligible {
		slot = global_binding_hint_slot(object, name)
		if vm.global_binding_hints.len != 0 {
			hint := vm.global_binding_hints[slot]
			if voidptr(hint.object) == voidptr(object) && hint.owner != unsafe { nil }
				&& utf16_equals(hint.owner.utf16.data, name.data)
				&& hint.index >= 0 && hint.index < object.properties.len
				&& object.properties[hint.index].key.equals(hint.key) {
				value := object.properties[hint.index].value
				if value.is_accessor() { return none }
				if mut tier := vm.native_tier { if tier.diagnostics { tier.activity.global_binding_hint_hits++ } }
				return value
			}
		}
	}
	key := vm.binding_property_key(name)
	index := object.find_own_property(key)
	if index < 0 { return none }
	value := object.properties[index].value
	if value.is_accessor() { return none }
	if eligible {
		if vm.global_binding_hints.len == 0 {
			vm.global_binding_hints = []GlobalBindingHint{len: global_binding_hint_slots}
		}
		owner := vm.create_fly_string(name)
		vm.global_binding_hints[slot] = GlobalBindingHint{object: object, owner: owner, key: key, index: index}
	}
	return value
}
