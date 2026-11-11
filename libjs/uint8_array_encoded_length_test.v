// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Boundary regressions for Ladybird 986504619b4f6b967812cc1853c3c3238539bff5.
// Exercise length arithmetic without allocating multi-gigabyte input buffers.
fn test_uint8_array_encoded_lengths_validate_complete_and_partial_groups() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for length in [uint(0), 1, 2, 3, 4, 5, 6] {
		assert uint8_array_base64_output_length(mut vm, length, false)! == ((length + 2) / 3) * 4
		assert uint8_array_base64_output_length(mut vm, length, true)! == (length * 8 + 5) / 6
	}
	assert uint8_array_base64_output_length(mut vm, uint(3221225469), false)! == uint(4294967292)
	assert uint8_array_base64_output_length(mut vm, uint(3221225470), true)! == uint(4294967294)
	assert uint8_array_base64_output_length(mut vm, uint(3221225471), true)! == uint(4294967295)
	for omit_padding in [false, true] {
		length := if omit_padding { uint(3221225472) } else { uint(3221225470) }
		if _ := uint8_array_base64_output_length(mut vm, length, omit_padding) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
			assert thrown_value(err).as_object().error_message()?.str() == 'string size must not overflow'
		}
	}
	assert checked_js_string_length_product(mut vm, uint(2147483647), 2,
		.string_size_must_not_overflow)! == uint(4294967294)
	if _ := checked_js_string_length_product(mut vm, uint(2147483648), 2,
		.string_size_must_not_overflow) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .range_error
	}
}
