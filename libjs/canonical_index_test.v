module libjs

fn test_canonical_numeric_index_string_keeps_optimized_indices_and_roundtrip_tags() {
	for index in [u32(0), 1, 42, 4294967294] {
		for mode in [CanonicalIndexMode.detect_numeric_roundtrip, .ignore_numeric_roundtrip] {
			result := canonical_numeric_index_string(PropertyName.from_number(index), mode)
			assert result.is_index() && result.as_index() == index
		}
	}
	last_index_key := PropertyName.from_str('4294967295')
	last_index := canonical_numeric_index_string(last_index_key, .detect_numeric_roundtrip)
	assert last_index.is_index() && last_index.as_index() == 4294967295
	assert canonical_numeric_index_string(last_index_key, .ignore_numeric_roundtrip).is_undefined()
	for text in ['-0', '-1', '1.5', '0.5', '-0.5', 'Infinity', '-Infinity', 'NaN',
		'4294967296', '1e+21', '1e-7', '0.000001'] {
		key := PropertyName.from_str(text)
		result := canonical_numeric_index_string(key, .detect_numeric_roundtrip)
		assert result.kind == .numeric && !result.is_index() && !result.is_undefined(), text
		assert canonical_numeric_index_string(key, .ignore_numeric_roundtrip).is_undefined()
	}
	for text in ['', '-', '00', '-00', '01', '+1', '1.0', '0.', '-0.', '.5', '1e3', '1e21', '1E+21',
		'0.0000001', ' 1', '1 ', 'Infinity ', '+Infinity', 'nan', '0x10', '1x', '1\u0000', '１'] {
		assert canonical_numeric_index_string(PropertyName.from_str(text),
			.detect_numeric_roundtrip).is_undefined(), text
	}
	assert canonical_numeric_index_string(PropertyName.from_utf16(Utf16String.from_slice([
		u16(`1`),
		0xd800,
	])), .detect_numeric_roundtrip).is_undefined()
}

fn test_canonical_index_from_double_retains_source_checked_range_and_truncation() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert CanonicalIndex.from_double(mut vm, .index, 42.9)!.as_index() == 42
	assert CanonicalIndex.from_double(mut vm, .index, -0.0)!.as_index() == 0
	assert CanonicalIndex.from_double(mut vm, .index, 4294967295.0)!.as_index() == 4294967295
	for index in [-1.0, 4294967296.0] {
		if _ := CanonicalIndex.from_double(mut vm, .index, index) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() ==
				'Invalid integer index: ' + format_f64_value(index)
		}
	}
}
