module libjs

pub struct PrimitivePropertyKeyActivity {
pub:
	strings u64
	symbols u64
}

$if test {
	__global primitive_property_keys_disabled bool
	__global primitive_property_keys_diagnostic bool
	__global primitive_property_keys_strings u64
	__global primitive_property_keys_symbols u64
	pub fn diagnose_primitive_property_keys_for_testing(enabled bool) PrimitivePropertyKeyActivity {
		previous := PrimitivePropertyKeyActivity{primitive_property_keys_strings, primitive_property_keys_symbols}
		primitive_property_keys_diagnostic = enabled
		primitive_property_keys_strings = 0
		primitive_property_keys_symbols = 0
		return previous
	}
	pub fn set_primitive_property_keys_for_testing(enabled bool) { primitive_property_keys_disabled = !enabled }
}

fn use_primitive_property_keys() bool {
	$if test { if primitive_property_keys_disabled { return false } }
	return true
}
