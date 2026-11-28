// SPDX-License-Identifier: BSD-2-Clause
module libjs

import vunicode

// StringPrototype.cpp::TransformCase. Canonicalize the whole locale list but
// use only its first request: an unsupported first language uses root mappings,
// rather than negotiating a later language as the Intl formatters do.
fn string_locale_case(mut vm VM, uppercase bool) !Value {
	text := string_primitive_from(mut vm)!
	requested := intl_canonicalize_locale_list(mut vm, vm.argument(0))!
	locale := if requested.len > 0 { requested[0] } else { vm.realm().intl_default_locale }
	if string_case_is_unchanged_ascii(text.utf16, uppercase) { return Value.from_string(text) }
	for index := 0; index < text.utf16.data.len; index += 1024 { vm.consume_execution_budget()! }
	mapped := vunicode.map_case(text.utf16.data, locale, if uppercase { .uppercase } else { .lowercase })
	checked_js_string_length_sum(mut vm, 0, uint(mapped.units.len), .string_size_must_not_overflow)!
	return Value.from_string(vm.create_string(Utf16String.from_slice(mapped.units)))
}

pub fn string_prototype_to_locale_lowercase(mut vm VM) !Value { return string_locale_case(mut vm, false) }
pub fn string_prototype_to_locale_uppercase(mut vm VM) !Value { return string_locale_case(mut vm, true) }
