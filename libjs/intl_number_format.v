// SPDX-License-Identifier: BSD-2-Clause
module libjs

import platform

@[heap]
pub struct IntlNumberFormat {
	object &Object
	locale string
	data_locale string
	numbering_system string
	style string
	currency string
	currency_display string
	currency_sign string
	unit string
	unit_display string
	notation string
	compact_display string
	grouping string
	sign_display string
	digits IntlNumberDigits
mut:
	bound_format ?&Object
}

struct IntlNumberPart { type_ string; value string; unit string }

fn intl_number_format_this(mut vm VM) !&IntlNumberFormat {
	value := vm.this_value()
	if value.is_object() { if formatter := value.as_object().intl_number_format { return formatter } }
	return vm.throw_error(.type_error, 'Intl.NumberFormat member called on incompatible receiver')
}

fn intl_number_locale(mut vm VM, requested []string, numbering_value Value) !(string, string, string) {
	data_locale, identifier := intl_resolve_locale(mut vm, requested)!
	data := intl_date_locale_data(mut vm, data_locale)!
	core := intl_core_data(mut vm)!
	mut system := data.numbering_system
	mut extension := ''
	if requested_system := identifier.keywords['nu'] {
		if requested_system in core.numbering_systems { system = requested_system; extension = requested_system }
	}
	if !numbering_value.is_undefined() {
		option := numbering_value.as_string().str().to_lower()
		if option in core.numbering_systems { if option != system { extension = '' }; system = option }
	}
	return data_locale + if extension == '' { '' } else { '-u-nu-' + extension }, data_locale, system
}

fn intl_numbering_option(mut vm VM, options &Object) !Value {
	value := intl_string_option(mut vm, options, 'numberingSystem', [])!
	if !value.is_undefined() && !intl_type_identifier(intl_ascii(mut vm, value.as_string().utf16)!) { return vm.throw_error(.range_error, 'Invalid Intl numbering system') }
	return value
}

const intl_sanctioned_units = ['acre', 'bit', 'byte', 'celsius', 'centimeter', 'day', 'degree', 'fahrenheit', 'fluid-ounce', 'foot', 'gallon', 'gigabit', 'gigabyte', 'gram', 'hectare', 'hour', 'inch', 'kilobit', 'kilobyte', 'kilogram', 'kilometer', 'liter', 'megabit', 'megabyte', 'meter', 'microsecond', 'mile', 'mile-scandinavian', 'milliliter', 'millimeter', 'millisecond', 'minute', 'month', 'nanosecond', 'ounce', 'percent', 'petabyte', 'pound', 'second', 'stone', 'terabit', 'terabyte', 'week', 'yard', 'year']

fn intl_well_formed_unit(unit string) bool {
	if unit in intl_sanctioned_units { return true }
	pieces := unit.split('-per-')
	return pieces.len == 2 && pieces[0] in intl_sanctioned_units && pieces[1] in intl_sanctioned_units
}

fn intl_number_format_construct(mut vm VM, new_target &Object) !&Object {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.intl_number_format_prototype or { panic('Missing Intl.NumberFormat prototype') } })!
	requested := intl_canonicalize_locale_list(mut vm, vm.argument(0))!
	options := intl_options_object(mut vm, vm.argument(1))!
	intl_string_option(mut vm, options, 'localeMatcher', ['lookup', 'best fit'])!
	numbering := intl_numbering_option(mut vm, options)!
	locale, data_locale, system := intl_number_locale(mut vm, requested, numbering)!
	style := intl_option_text(mut vm, options, 'style', ['decimal', 'percent', 'currency', 'unit'], 'decimal')!
	currency_value := intl_string_option(mut vm, options, 'currency', [])!
	currency_text := if currency_value.is_undefined() { '' } else { currency_value.as_string().str() }
	if currency_value.is_undefined() && style == 'currency' { return vm.throw_error(.type_error, 'currency style requires a currency') }
	if !currency_value.is_undefined() && (currency_text.len != 3 || !intl_alpha(currency_text)) { return vm.throw_error(.range_error, 'Invalid Intl currency') }
	currency := currency_text.to_upper()
	currency_display := intl_option_text(mut vm, options, 'currencyDisplay', ['code', 'symbol', 'narrowSymbol', 'name'], 'symbol')!
	currency_sign := intl_option_text(mut vm, options, 'currencySign', ['standard', 'accounting'], 'standard')!
	unit_value := intl_string_option(mut vm, options, 'unit', [])!
	unit := if unit_value.is_undefined() { '' } else { unit_value.as_string().str() }
	if unit == '' && style == 'unit' { return vm.throw_error(.type_error, 'unit style requires a unit') }
	if !unit_value.is_undefined() && !intl_well_formed_unit(unit) { return vm.throw_error(.range_error, 'Invalid Intl unit') }
	unit_display := intl_option_text(mut vm, options, 'unitDisplay', ['short', 'narrow', 'long'], 'short')!
	notation := intl_option_text(mut vm, options, 'notation', ['standard', 'scientific', 'engineering', 'compact'], 'standard')!
	core := intl_core_data(mut vm)!
	currency_digits := core.currency_digits[currency] or { 2 }
	minimum := if style == 'currency' && notation == 'standard' { currency_digits } else { 0 }
	maximum := if style == 'currency' && notation == 'standard' { currency_digits } else if style == 'percent' { 0 } else { 3 }
	digits := intl_number_digit_options(mut vm, options, minimum, maximum, notation)!
	compact_display := intl_option_text(mut vm, options, 'compactDisplay', ['short', 'long'], 'short')!
	default_grouping := if notation == 'compact' { 'min2' } else { 'auto' }
	grouping_value := options.get(mut vm, PropertyName.from_str('useGrouping'))!
	mut grouping := default_grouping
	if !grouping_value.is_undefined() {
		if !grouping_value.to_boolean() { grouping = 'false' }
		else if grouping_value.is_boolean() { grouping = 'always' }
		else {
			text := grouping_value.to_primitive_string(mut vm)!.str()
			if text !in ['min2', 'auto', 'always', 'true', 'false'] { return vm.throw_error(.range_error, 'Invalid Intl useGrouping') }
			if text !in ['true', 'false'] { grouping = text }
		}
	}
	sign_display := intl_option_text(mut vm, options, 'signDisplay', ['auto', 'never', 'always', 'exceptZero', 'negative'], 'auto')!
	mut object := Object.create(vm.realm(), prototype)
	object.class_name = 'Intl.NumberFormat'
	object.intl_number_format = &IntlNumberFormat{object: object, locale: locale, data_locale: data_locale, numbering_system: system, style: style, currency: currency, currency_display: currency_display, currency_sign: currency_sign, unit: unit, unit_display: unit_display, notation: notation, compact_display: compact_display, grouping: grouping, sign_display: sign_display, digits: digits}
	return object
}

fn intl_number_resolved_options(mut vm VM) !Value {
	f := intl_number_format_this(mut vm)!
	mut object := Object.create(vm.realm(), vm.realm().object_prototype)
	mut entries := {'locale': f.locale, 'numberingSystem': f.numbering_system, 'style': f.style, 'notation': f.notation, 'signDisplay': f.sign_display, 'roundingMode': f.digits.mode, 'roundingPriority': f.digits.priority, 'trailingZeroDisplay': f.digits.trailing_zero}
	if f.style == 'currency' { entries['currency'] = f.currency; entries['currencyDisplay'] = f.currency_display; entries['currencySign'] = f.currency_sign }
	if f.style == 'unit' { entries['unit'] = f.unit; entries['unitDisplay'] = f.unit_display }
	if f.notation == 'compact' { entries['compactDisplay'] = f.compact_display }
	numbers := {'minimumIntegerDigits': f.digits.minimum_integer, 'minimumFractionDigits': f.digits.minimum_fraction, 'maximumFractionDigits': f.digits.maximum_fraction, 'minimumSignificantDigits': f.digits.minimum_significant, 'maximumSignificantDigits': f.digits.maximum_significant, 'roundingIncrement': f.digits.increment}
	for key in ['locale', 'numberingSystem', 'style', 'currency', 'currencyDisplay', 'currencySign', 'unit', 'unitDisplay', 'minimumIntegerDigits', 'minimumFractionDigits', 'maximumFractionDigits', 'minimumSignificantDigits', 'maximumSignificantDigits', 'useGrouping', 'notation', 'compactDisplay', 'signDisplay', 'roundingIncrement', 'roundingMode', 'roundingPriority', 'trailingZeroDisplay'] {
		if key == 'useGrouping' { object.create_data_property_or_throw(mut vm, PropertyName.from_str(key), if f.grouping == 'false' { Value.from_bool(false) } else { Value.from_string(vm.create_string_from_str(f.grouping)) })! }
		else if text := entries[key] { object.create_data_property_or_throw(mut vm, PropertyName.from_str(key), Value.from_string(vm.create_string_from_str(text)))! }
		else if number := numbers[key] { if number >= 0 { object.create_data_property_or_throw(mut vm, PropertyName.from_str(key), Value.from_i32(i32(number)))! } }
	}
	return Value.from_object(object)
}

fn intl_number_parts_array(mut vm VM, parts []IntlNumberPart) !Value {
	mut output := []Value{cap: parts.len}
	for part in parts {
		mut object := Object.create(vm.realm(), vm.realm().object_prototype)
		for key, text in {'type': part.type_, 'value': part.value} { object.create_data_property_or_throw(mut vm, PropertyName.from_str(key), Value.from_string(vm.create_string_from_str(text)))! }
		if part.unit != '' { object.create_data_property_or_throw(mut vm, PropertyName.from_str('unit'), Value.from_string(vm.create_string_from_str(part.unit)))! }
		output << Value.from_object(object)
	}
	return Value.from_object(ArrayObject.create_from(mut vm, vm.realm(), output, vm.realm().array_prototype_record())!.object)
}

fn intl_number_parts_string(mut vm VM, parts []IntlNumberPart) !Value {
	mut text := ''
	for part in parts { checked_js_string_length_sum(mut vm, uint(text.len), uint(part.value.len), .string_size_must_not_overflow)!; text += part.value }
	return Value.from_string(vm.create_string_from_str(text))
}

fn initialize_intl_number_format(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(realm, realm.object_prototype)
	realm.intl_number_format_prototype = prototype
	mut constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
		constructor := vm.realm().intl_number_format_constructor or { panic('Missing Intl.NumberFormat') }
		return Value.from_object(construct(mut vm, Value.from_object(constructor), [vm.argument(0), vm.argument(1)], none)!)
	}, intl_number_format_construct, 0, PropertyName.from_str('NumberFormat')).object
	realm.intl_number_format_constructor = constructor
	constructor.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(constructor), attribute_writable | attribute_configurable)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('Intl.NumberFormat')), attribute_configurable)
	install_intrinsic_method(mut vm, realm, mut constructor, 'supportedLocalesOf', 1, fn (mut vm VM) !Value { return intl_supported_locales(mut vm, vm.argument(0), vm.argument(1)) })
	prototype.define_native_accessor(mut vm, realm, PropertyName.from_str('format'), intl_number_format_getter, unsafe { nil }, attribute_configurable, realm.function_prototype)
	install_intrinsic_method(mut vm, realm, mut prototype, 'resolvedOptions', 0, intl_number_resolved_options)
	install_intrinsic_method(mut vm, realm, mut prototype, 'formatToParts', 1, fn (mut vm VM) !Value {
		formatter := intl_number_format_this(mut vm)!
		return intl_number_parts_array(mut vm, intl_format_number_parts(mut vm, formatter, intl_mathematical_value(mut vm, vm.argument(0))!)!)
	})
	mut namespace := realm.intl_object or { panic('Missing Intl namespace') }
	namespace.define_direct_property(PropertyName.from_str('NumberFormat'), Value.from_object(constructor), attribute_writable | attribute_configurable)
}
