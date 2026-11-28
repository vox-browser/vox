module libjs

$if test {
	__global string_key_scans_disabled bool
	__global string_key_scans_diagnostics bool
	__global string_key_scans u64
	pub fn set_string_key_scans_for_testing(enabled bool) { string_key_scans_disabled = !enabled }
	pub fn diagnose_string_key_scans_for_testing(enabled bool) u64 {
		previous := string_key_scans
		string_key_scans = 0
		string_key_scans_diagnostics = enabled
		return previous
	}
}

@[inline]
fn use_string_key_scans() bool {
	$if test {
		if string_key_scans_disabled { return false }
	}
	return true
}

// Read the authoritative keys on every lookup. Length and identity reject
// most candidates without copying a property or dispatching a union comparison.
// No key, descriptor, absence or property-vector version is cached here.
fn (object &Object) find_own_string_property(key &Utf16String) int {
	$if test {
		if string_key_scans_diagnostics { string_key_scans++ }
	}
	units := if key == unsafe { nil } { []u16{} } else { key.data }
	for index in 0 .. object.properties.len {
		property := &object.properties[index]
		if property.key.kind != .string_key { continue }
		candidate := property.key.string_value
		if voidptr(candidate) == voidptr(key) { return index }
		if candidate == unsafe { nil } {
			if units.len == 0 { return index }
			continue
		}
		if candidate.data.len != units.len { continue }
		if utf16_key_units_equal(candidate.data, units) { return index }
	}
	return -1
}
