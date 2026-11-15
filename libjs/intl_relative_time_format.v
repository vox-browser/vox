// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math
import platform

@[heap]
pub struct IntlRelativeTimeFormat {
	object &Object
	locale string
	data_locale string
	numbering_system string
	style string
	numeric string
	number_format &IntlNumberFormat
}

fn intl_relative_time_this(mut vm VM) !&IntlRelativeTimeFormat {
	value := vm.this_value()
	if value.is_object() { if formatter := value.as_object().intl_relative_time_format { return formatter } }
	return vm.throw_error(.type_error, 'Intl.RelativeTimeFormat member called on incompatible receiver')
}

fn intl_relative_time_construct(mut vm VM, new_target &Object) !&Object {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.intl_relative_time_format_prototype or { panic('Missing Intl.RelativeTimeFormat prototype') } })!
	requested := intl_canonicalize_locale_list(mut vm, vm.argument(0))!
	options := intl_options_object(mut vm, vm.argument(1))!
	intl_string_option(mut vm, options, 'localeMatcher', ['lookup', 'best fit'])!
	numbering := intl_numbering_option(mut vm, options)!
	locale, data_locale, system := intl_number_locale(mut vm, requested, numbering)!
	style := intl_option_text(mut vm, options, 'style', ['long', 'short', 'narrow'], 'long')!
	numeric := intl_option_text(mut vm, options, 'numeric', ['always', 'auto'], 'always')!
	mut number_options := Object.create(vm.realm(), none)
	number_options.create_data_property_or_throw(mut vm, PropertyName.from_str('numberingSystem'), Value.from_string(vm.create_string_from_str(system)))!
	constructor := vm.realm().intl_number_format_constructor or { return vm.throw_error(.internal_error, 'Missing Intl.NumberFormat') }
	number := construct(mut vm, Value.from_object(constructor), [Value.from_string(vm.create_string_from_str(locale)), Value.from_object(number_options)], none)!
	number_format := number.intl_number_format or { return vm.throw_error(.internal_error, 'Missing Intl.NumberFormat slots') }
	mut object := Object.create(vm.realm(), prototype)
	object.class_name = 'Intl.RelativeTimeFormat'
	object.intl_relative_time_format = &IntlRelativeTimeFormat{object: object, locale: locale, data_locale: data_locale, numbering_system: system, style: style, numeric: numeric, number_format: number_format}
	return object
}

fn intl_relative_time_parts(mut vm VM, formatter &IntlRelativeTimeFormat, number f64, unit_text string) ![]IntlNumberPart {
	if math.is_nan(number) || math.is_inf(number, 0) { return vm.throw_error(.range_error, 'Relative time must be finite') }
	mut unit := unit_text
	if unit.ends_with('s') { unit = unit[..unit.len - 1] }
	if unit !in ['year', 'quarter', 'month', 'week', 'day', 'hour', 'minute', 'second'] { return vm.throw_error(.range_error, 'Invalid relative time unit') }
	data := intl_date_locale_data(mut vm, formatter.data_locale)!
	style_key := unit + if formatter.style == 'long' { '' } else { '-' + formatter.style }
	patterns := (data.relative_time[style_key] or { data.relative_time[unit] or { map[string]string{} } }).clone()
	if formatter.numeric == 'auto' {
		if literal := patterns['relative-type-' + format_f64_value(number)] { return [IntlNumberPart{type_: 'literal', value: literal}] }
	}
	value := intl_mathematical_value(mut vm, Value.from_f64(if number < 0 { -number } else { number }))!
	rounded := intl_round_number(mut vm, value, formatter.number_format.digits)!
	plural := intl_plural_category(mut vm, formatter.data_locale, rounded.text, 0, false)!
	tense := if math.f64_bits(number) >> 63 != 0 { 'past' } else { 'future' }
	pattern := patterns[tense + ':' + plural] or { patterns[tense + ':other'] or { return vm.throw_error(.internal_error, 'Missing CLDR relative time pattern') } }
	parts := intl_format_number_parts(mut vm, formatter.number_format, IntlDecimal{...value, negative: false})!
	mut output := []IntlNumberPart{}
	mut cursor := 0
	for index in 0 .. pattern.len {
		if index < cursor || !pattern[index..].starts_with('{0}') { continue }
		if index > cursor { output << IntlNumberPart{type_: 'literal', value: pattern[cursor..index]} }
		for part in parts { output << IntlNumberPart{...part, unit: if part.type_ == 'literal' { '' } else { unit }} }
		cursor = index + 3
	}
	if cursor < pattern.len { output << IntlNumberPart{type_: 'literal', value: pattern[cursor..]} }
	return output
}

fn intl_relative_format(mut vm VM) !Value {
	formatter := intl_relative_time_this(mut vm)!
	number := vm.argument(0).to_number(mut vm)!.number
	unit := vm.argument(1).to_primitive_string(mut vm)!.str()
	return intl_number_parts_string(mut vm, intl_relative_time_parts(mut vm, formatter, number, unit)!)
}

fn intl_relative_format_to_parts(mut vm VM) !Value {
	formatter := intl_relative_time_this(mut vm)!
	number := vm.argument(0).to_number(mut vm)!.number
	unit := vm.argument(1).to_primitive_string(mut vm)!.str()
	return intl_number_parts_array(mut vm, intl_relative_time_parts(mut vm, formatter, number, unit)!)
}

fn initialize_intl_relative_time_format(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(realm, realm.object_prototype)
	realm.intl_relative_time_format_prototype = prototype
	mut constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value { return vm.throw_error(.type_error, 'Intl.RelativeTimeFormat constructor requires new') }, intl_relative_time_construct, 0, PropertyName.from_str('RelativeTimeFormat')).object
	realm.intl_relative_time_format_constructor = constructor
	constructor.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(constructor), attribute_writable | attribute_configurable)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('Intl.RelativeTimeFormat')), attribute_configurable)
	install_intrinsic_method(mut vm, realm, mut constructor, 'supportedLocalesOf', 1, fn (mut vm VM) !Value { return intl_supported_locales(mut vm, vm.argument(0), vm.argument(1)) })
	install_intrinsic_method(mut vm, realm, mut prototype, 'format', 2, intl_relative_format)
	install_intrinsic_method(mut vm, realm, mut prototype, 'formatToParts', 2, intl_relative_format_to_parts)
	install_intrinsic_method(mut vm, realm, mut prototype, 'resolvedOptions', 0, fn (mut vm VM) !Value {
		formatter := intl_relative_time_this(mut vm)!
		mut object := Object.create(vm.realm(), vm.realm().object_prototype)
		values := {'locale': formatter.locale, 'style': formatter.style, 'numeric': formatter.numeric, 'numberingSystem': formatter.numbering_system}
		for key in ['locale', 'style', 'numeric', 'numberingSystem'] { object.create_data_property_or_throw(mut vm, PropertyName.from_str(key), Value.from_string(vm.create_string_from_str(values[key])))! }
		return Value.from_object(object)
	})
	mut namespace := realm.intl_object or { panic('Missing Intl namespace') }
	namespace.define_direct_property(PropertyName.from_str('RelativeTimeFormat'), Value.from_object(constructor), attribute_writable | attribute_configurable)
}
