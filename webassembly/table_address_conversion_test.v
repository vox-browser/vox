module webassembly

import math
import webidl

fn test_table32_address_values_use_source_to_number_and_enforce_range_truncation() {
	assert address_value_to_u64(webidl.number_value(1.9), .i32)! == 1
	assert address_value_to_u64(webidl.number_value(-0.9), .i32)! == 0
	assert address_value_to_u64(webidl.number_value(4294967295.9), .i32)! == u64(4294967295)
	assert address_value_to_u64(webidl.boolean_value(true), .i32)! == 1
	assert address_value_to_u64(webidl.null_value(), .i32)! == 0
	assert address_value_to_u64(webidl.string_value(' 0x20 '), .i32)! == 32
	assert address_value_to_u64(webidl.string_value('1.75'), .i32)! == 1
	assert address_value_to_u64(webidl.string_value(''), .i32)! == 0
	assert table_limit_to_js_value((u64(1) << 32) + 5, .i32).number_value == 5
}

fn test_table32_address_rejections_preserve_source_numeric_conversion_errors() {
	for input in [webidl.undefined_value(), webidl.string_value('not a number'),
		webidl.number_value(math.inf(1)), webidl.number_value(math.nan())] {
		if _ := address_value_to_u64(input, .i32) {
			assert false
		} else {
			assert err.msg() == 'TypeError: Number must not be NaN or Infinity'
		}
	}
	for input in [webidl.number_value(-1.9), webidl.number_value(4294967296)] {
		if _ := address_value_to_u64(input, .i32) {
			assert false
		} else {
			assert err.msg().contains('outside of allowed range of 0 to 4294967295')
		}
	}
	if _ := address_value_to_u64(webidl.bigint_value(1), .i32) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Cannot convert BigInt to number'
	}
}
