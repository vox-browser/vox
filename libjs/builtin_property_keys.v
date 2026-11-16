module libjs

// Reuse the immutable spelling, while every Get/Set still goes through the
// ordinary or exotic object operation. Array length comparisons need no key
// allocation, including when the requested property is an index or a symbol.
pub struct BuiltinKeyActivity {
pub:
	cached         u64
	ascii_compares u64
	legacy         u64
}

$if test {
	__global builtin_key_cache_disabled_for_test bool
	__global builtin_key_diagnostic_for_test bool
	__global builtin_keys_cached_for_test u64
	__global builtin_keys_compared_for_test u64
	__global builtin_keys_legacy_for_test u64
	pub fn set_builtin_key_cache_for_testing(enabled bool) {
		builtin_key_cache_disabled_for_test = !enabled
	}
	pub fn diagnose_builtin_keys_for_testing(enabled bool) BuiltinKeyActivity {
		previous := BuiltinKeyActivity{builtin_keys_cached_for_test, builtin_keys_compared_for_test, builtin_keys_legacy_for_test}
		builtin_keys_cached_for_test = 0
		builtin_keys_compared_for_test = 0
		builtin_keys_legacy_for_test = 0
		builtin_key_diagnostic_for_test = enabled
		return previous
	}
}

fn (key PropertyName) is_length_property() bool {
	$if test {
		if builtin_key_cache_disabled_for_test {
			if builtin_key_diagnostic_for_test { builtin_keys_legacy_for_test++ }
			return key.equals(PropertyName.from_str('length'))
		}
		if builtin_key_diagnostic_for_test { builtin_keys_compared_for_test++ }
	}
	return key.is_string() && key.string_value != unsafe { nil } && utf16_equals_ascii(key.string_value.data, 'length')
}

fn (vm &VM) length_key() PropertyName {
	$if test {
		if builtin_key_cache_disabled_for_test {
			if builtin_key_diagnostic_for_test { builtin_keys_legacy_for_test++ }
			return PropertyName.from_str('length')
		}
		if builtin_key_diagnostic_for_test { builtin_keys_cached_for_test++ }
	}
	return vm.length_property_key
}
