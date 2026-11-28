// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math

struct IntlNumberDigits {
	minimum_integer int = 1
	minimum_fraction int = -1
	maximum_fraction int = -1
	minimum_significant int = -1
	maximum_significant int = -1
	increment int = 1
	mode string = 'halfExpand'
	priority string = 'auto'
	type_ string = 'fractionDigits'
	trailing_zero string = 'auto'
}

fn intl_option_text(mut vm VM, options &Object, name string, allowed []string, fallback string) !string {
	value := intl_string_option(mut vm, options, name, allowed)!
	return if value.is_undefined() { fallback } else { value.as_string().str() }
}

fn intl_default_number_option(mut vm VM, value Value, minimum int, maximum int, fallback int) !int {
	if value.is_undefined() { return fallback }
	number := value.to_number(mut vm)!.number
	if math.is_nan(number) || number < minimum || number > maximum { return vm.throw_error(.range_error, 'Invalid Intl numeric option') }
	return int(math.floor(number))
}

fn intl_number_digit_options(mut vm VM, options &Object, default_minimum int, default_maximum int, notation string) !IntlNumberDigits {
	minimum_integer := intl_default_number_option(mut vm, options.get(mut vm, PropertyName.from_str('minimumIntegerDigits'))!, 1, 21, 1)!
	minimum_fraction := options.get(mut vm, PropertyName.from_str('minimumFractionDigits'))!
	maximum_fraction := options.get(mut vm, PropertyName.from_str('maximumFractionDigits'))!
	minimum_significant := options.get(mut vm, PropertyName.from_str('minimumSignificantDigits'))!
	maximum_significant := options.get(mut vm, PropertyName.from_str('maximumSignificantDigits'))!
	increment := intl_default_number_option(mut vm, options.get(mut vm, PropertyName.from_str('roundingIncrement'))!, 1, 5000, 1)!
	if increment !in [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 2500, 5000] { return vm.throw_error(.range_error, 'Invalid Intl roundingIncrement') }
	mode := intl_option_text(mut vm, options, 'roundingMode', ['ceil', 'floor', 'expand', 'trunc', 'halfCeil', 'halfFloor', 'halfExpand', 'halfTrunc', 'halfEven'], 'halfExpand')!
	priority := intl_option_text(mut vm, options, 'roundingPriority', ['auto', 'morePrecision', 'lessPrecision'], 'auto')!
	trailing := intl_option_text(mut vm, options, 'trailingZeroDisplay', ['auto', 'stripIfInteger'], 'auto')!
	has_significant := !minimum_significant.is_undefined() || !maximum_significant.is_undefined()
	has_fraction := !minimum_fraction.is_undefined() || !maximum_fraction.is_undefined()
	need_significant := priority != 'auto' || has_significant
	need_fraction := priority != 'auto' || (!need_significant && (has_fraction || notation != 'compact'))
	mut result := IntlNumberDigits{minimum_integer: minimum_integer, increment: increment, mode: mode, priority: priority, trailing_zero: trailing}
	if need_significant {
		min_digits := intl_default_number_option(mut vm, minimum_significant, 1, 21, 1)!
		max_digits := intl_default_number_option(mut vm, maximum_significant, min_digits, 21, 21)!
		result = IntlNumberDigits{...result, minimum_significant: min_digits, maximum_significant: max_digits}
	}
	if need_fraction {
		mut min_digits := intl_default_number_option(mut vm, minimum_fraction, 0, 100, -1)!
		mut max_digits := intl_default_number_option(mut vm, maximum_fraction, 0, 100, -1)!
		maximum_default := if increment == 1 { default_maximum } else { default_minimum }
		if min_digits == -1 { min_digits = if max_digits == -1 || default_minimum < max_digits { default_minimum } else { max_digits } }
		if max_digits == -1 { max_digits = if maximum_default > min_digits { maximum_default } else { min_digits } }
		if min_digits > max_digits { return vm.throw_error(.range_error, 'Intl minimumFractionDigits exceeds maximumFractionDigits') }
		result = IntlNumberDigits{...result, minimum_fraction: min_digits, maximum_fraction: max_digits}
	}
	if !need_significant && !need_fraction {
		result = IntlNumberDigits{...result, minimum_fraction: 0, maximum_fraction: 0, minimum_significant: 1, maximum_significant: 2, type_: 'morePrecision', priority: 'morePrecision'}
	} else if priority != 'auto' { result = IntlNumberDigits{...result, type_: priority} }
	else if has_significant { result = IntlNumberDigits{...result, type_: 'significantDigits'} }
	if increment != 1 {
		if result.type_ != 'fractionDigits' { return vm.throw_error(.type_error, 'roundingIncrement requires fraction-digit rounding') }
		if result.minimum_fraction != result.maximum_fraction { return vm.throw_error(.range_error, 'roundingIncrement requires equal fraction digits') }
	}
	return result
}

struct IntlRoundedNumber { decimal IntlDecimal; text string; magnitude int }

fn intl_round_number(mut vm VM, value IntlDecimal, options IntlNumberDigits) !IntlRoundedNumber {
	mut fraction := IntlRoundedNumber{}
	mut significant := IntlRoundedNumber{}
	if options.type_ != 'significantDigits' {
		rounded := intl_decimal_round(mut vm, value, -options.maximum_fraction, options.increment, options.mode)!
		fraction = IntlRoundedNumber{decimal: rounded, text: intl_decimal_fixed(rounded, options.minimum_fraction), magnitude: -options.maximum_fraction}
	}
	if options.type_ != 'fractionDigits' {
		rounded := intl_decimal_round(mut vm, value, value.magnitude() - options.maximum_significant + 1, 1, options.mode)!
		fraction_count := options.minimum_significant - rounded.magnitude() - 1
		minimum_fraction := if fraction_count > 0 { fraction_count } else { 0 }
		significant = IntlRoundedNumber{decimal: rounded, text: intl_decimal_fixed(rounded, minimum_fraction), magnitude: rounded.magnitude() - options.maximum_significant + 1}
	}
	mut chosen := if options.type_ == 'fractionDigits' { fraction } else if options.type_ == 'significantDigits' { significant }
		else if (options.type_ == 'morePrecision' && significant.magnitude <= fraction.magnitude) || (options.type_ == 'lessPrecision' && significant.magnitude > fraction.magnitude) { significant } else { fraction }
	if options.trailing_zero == 'stripIfInteger' && chosen.text.contains('.') && chosen.text.all_after('.').trim('0') == '' {
		chosen = IntlRoundedNumber{...chosen, text: chosen.text.all_before('.')}
	}
	integer := chosen.text.all_before('.')
	if integer.len < options.minimum_integer { chosen = IntlRoundedNumber{...chosen, text: '0'.repeat(options.minimum_integer - integer.len) + chosen.text} }
	return chosen
}
