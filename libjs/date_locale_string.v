// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math

// DatePrototype.cpp: capture the native time before any observable locale or
// option conversion, then use the intrinsic formatter rather than author APIs.
fn date_prototype_locale_string(mut vm VM, name string) !Value {
	value := this_date_object(mut vm)!.date_value
	if math.is_nan(value) { return Value.from_string(vm.create_string_from_str('Invalid Date')) }
	required := if name == 'toLocaleDateString' {
		IntlDateRequired.date
	} else if name == 'toLocaleTimeString' {
		IntlDateRequired.time
	} else {
		IntlDateRequired.any
	}
	defaults := if name == 'toLocaleDateString' {
		IntlDateDefaults.date
	} else if name == 'toLocaleTimeString' {
		IntlDateDefaults.time
	} else {
		IntlDateDefaults.all
	}
	object := create_intl_date_time_format(mut vm, vm.realm().intl_date_time_format_prototype or { return error('Missing intrinsic date formatter') }, vm.argument(0), vm.argument(1), required, defaults)!
	formatter := object.slots.intl_date_time_format or { return error('Missing date formatter slots') }
	parts := intl_format_date_parts(mut vm, formatter, Value.from_f64(value))!
	mut text := ''
	for part in parts { text += part.value }
	return Value.from_string(vm.create_string_from_str(text))
}
