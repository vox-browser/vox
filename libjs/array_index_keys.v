module libjs

pub struct ArrayIndexKeyActivity {
pub:
	numeric u64
	strings u64
}

$if test {
	__global numeric_array_keys_disabled_for_test bool
	__global numeric_array_keys_diagnostic_for_test bool
	__global numeric_array_keys_for_test u64
	__global string_array_keys_for_test u64
	pub fn set_numeric_array_keys_for_testing(enabled bool) {
		numeric_array_keys_disabled_for_test = !enabled
	}
	pub fn diagnose_array_index_keys_for_testing(enabled bool) ArrayIndexKeyActivity {
		previous := ArrayIndexKeyActivity{numeric_array_keys_for_test, string_array_keys_for_test}
		numeric_array_keys_for_test = 0
		string_array_keys_for_test = 0
		numeric_array_keys_diagnostic_for_test = enabled
		return previous
	}
}

fn array_index_key(index u64) PropertyName {
	mut numeric := index < u64(0xffffffff)
	$if test {
		if numeric_array_keys_disabled_for_test { numeric = false }
		if numeric_array_keys_diagnostic_for_test {
			if numeric { numeric_array_keys_for_test++ } else { string_array_keys_for_test++ }
		}
	}
	if numeric { return PropertyName.from_number(u32(index)) }
	// 2^32-1 is not an array index; larger array-like indices must also keep
	// their complete decimal spelling without truncating to u32.
	return PropertyName.from_str(index.str())
}
