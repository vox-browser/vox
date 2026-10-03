module webidl

import libjs

fn test_source_quota_constructor_preserves_utf16_message_and_nullable_double_fields() {
	message := libjs.utf16_string_from_code_units([u16(0xd800), 0, 0xdc00])
	exception := QuotaExceededError.construct_utf16(message, QuotaExceededErrorOptions{quota: 0, requested: 0.5})!
	assert exception.base.name_utf16().code_units() == libjs.utf16_string('QuotaExceededError').code_units()
	assert exception.base.message_utf16().code_units() == message.code_units()
	assert exception.base.code() == 22
	assert exception.quota()? == 0
	assert exception.requested()? == 0.5
	empty := QuotaExceededError.create_utf16(message)
	assert empty.quota() == none
	assert empty.requested() == none
	assert empty.base.message_utf16().code_units() == message.code_units()
}

fn test_source_quota_constructor_checks_source_option_order_after_utf16_message() {
	message := libjs.utf16_string_from_code_units([u16(0xd800)])
	for options in [QuotaExceededErrorOptions{quota: -1, requested: -2}, QuotaExceededErrorOptions{quota: 0, requested: -1}, QuotaExceededErrorOptions{quota: 2, requested: 1}] {
		if _ := QuotaExceededError.construct_utf16(message, options) { assert false } else {
			expected := if options.quota or { 0 } < 0 { 'RangeError: Quota cannot be less than 0' } else if options.requested or { 0 } < 0 { 'RangeError: Requested cannot be less than 0' } else { 'RangeError: Requested cannot be less than quota' }
			assert err.msg() == expected
		}
	}
}
