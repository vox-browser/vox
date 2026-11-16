// SPDX-License-Identifier: BSD-2-Clause
module libjs

import platform

import math
import time

@[heap]
pub struct IntlDateTimeFormat {
pub:
	object &Object
	locale string
	data_locale string
	calendar string
	numbering_system string
	time_zone IntlTimeZone
	hour_cycle string
	date_style string
	time_style string
	pattern []IntlDatePatternToken
	fields map[string]string
mut:
	bound_format ?&Object
}

fn intl_date_time_format_this(mut vm VM) !&IntlDateTimeFormat {
	value := vm.this_value()
	if value.is_object() { if formatter := value.as_object().intl_date_time_format { return formatter } }
	return vm.throw_error(.type_error, 'Intl.DateTimeFormat member called on incompatible receiver')
}

fn intl_default_hour_cycle(mut vm VM, id IntlLocaleIdentifier) !string {
	core := intl_core_data(mut vm)!
	maximized := intl_maximize_identifier(mut vm, id)!
	preference := core.hour_cycles[id.language + '_' + maximized.region] or { core.hour_cycles[maximized.region] or { core.hour_cycles['001'] or { 'H' } } }
	return match preference { 'h' { 'h12' } 'K' { 'h11' } 'k' { 'h24' } else { 'h23' } }
}

fn intl_date_component_values(name string) []string {
	return match name {
		'weekday', 'era', 'dayPeriod' { ['narrow', 'short', 'long'] }
		'month' { ['2-digit', 'numeric', 'narrow', 'short', 'long'] }
		'timeZoneName' { ['short', 'long', 'shortOffset', 'longOffset', 'shortGeneric', 'longGeneric'] }
		else { ['2-digit', 'numeric'] }
	}
}

fn intl_date_time_format_construct(mut vm VM, new_target &Object) !&Object {
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.intl_date_time_format_prototype or { panic('Missing Intl.DateTimeFormat prototype') } })!
	return create_intl_date_time_format(mut vm, prototype, vm.argument(0), vm.argument(1), .any, .date)
}

enum IntlDateRequired { any date time }
enum IntlDateDefaults { date time all }

fn create_intl_date_time_format(mut vm VM, prototype &Object, locales Value, options_value Value, required IntlDateRequired, defaults IntlDateDefaults) !&Object {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	requested := intl_canonicalize_locale_list(mut vm, locales)!
	options := intl_options_object(mut vm, options_value)!
	intl_string_option(mut vm, options, 'localeMatcher', ['lookup', 'best fit'])!
	calendar_value := intl_string_option(mut vm, options, 'calendar', [])!
	if !calendar_value.is_undefined() && !intl_type_identifier(intl_ascii(mut vm, calendar_value.as_string().utf16)!) { return vm.throw_error(.range_error, 'Invalid Intl calendar') }
	numbering_value := intl_string_option(mut vm, options, 'numberingSystem', [])!
	if !numbering_value.is_undefined() && !intl_type_identifier(intl_ascii(mut vm, numbering_value.as_string().utf16)!) { return vm.throw_error(.range_error, 'Invalid Intl numbering system') }
	hour12 := options.get(mut vm, PropertyName.from_str('hour12'))!
	hour_cycle_value := intl_string_option(mut vm, options, 'hourCycle', ['h11', 'h12', 'h23', 'h24'])!
	data_locale, requested_id := intl_resolve_locale(mut vm, requested)!
	data := intl_date_locale_data(mut vm, data_locale)!
	core := intl_core_data(mut vm)!
	mut calendar := 'gregory'
	mut numbering_system := data.numbering_system
	mut hour_cycle := intl_default_hour_cycle(mut vm, requested_id)!
	mut retained := map[string]string{}
	if extension := requested_id.keywords['ca'] {
		if extension in ['gregory', 'iso8601'] { calendar = extension; retained['ca'] = extension }
	}
	if !calendar_value.is_undefined() {
		option := calendar_value.as_string().str().to_lower()
		if option in ['gregory', 'iso8601'] {
			if calendar != option { retained.delete('ca') }; calendar = option
		}
	}
	if extension := requested_id.keywords['nu'] {
		if extension in core.numbering_systems { numbering_system = extension; retained['nu'] = extension }
	}
	if !numbering_value.is_undefined() {
		option := numbering_value.as_string().str().to_lower()
		if option in core.numbering_systems { if numbering_system != option { retained.delete('nu') }; numbering_system = option }
	}
	if numbering_system !in core.numbering_systems { numbering_system = 'latn' }
	if hour12.is_undefined() {
		if extension := requested_id.keywords['hc'] {
			if extension in ['h11', 'h12', 'h23', 'h24'] { hour_cycle = extension; retained['hc'] = extension }
		}
		if !hour_cycle_value.is_undefined() {
			option := hour_cycle_value.as_string().str()
			if hour_cycle != option { retained.delete('hc') }; hour_cycle = option
		}
	} else {
		// Upstream's explicit hour12 override requests the h/H pattern family.
		hour_cycle = if hour12.to_boolean() { 'h12' } else { 'h23' }
	}
	zone := intl_parse_time_zone(mut vm, options.get(mut vm, PropertyName.from_str('timeZone'))!)!
	mut wanted := map[string]string{}
	mut fractional := 0
	for name in ['weekday', 'era', 'year', 'month', 'day', 'dayPeriod', 'hour', 'minute', 'second', 'fractionalSecondDigits', 'timeZoneName'] {
		if name == 'fractionalSecondDigits' {
			value := options.get(mut vm, PropertyName.from_str(name))!
			if !value.is_undefined() {
				number := value.to_number(mut vm)!.number
				if math.is_nan(number) || number < 1 || number > 3 { return vm.throw_error(.range_error, 'Invalid fractionalSecondDigits') }
				fractional = int(math.floor(number)); wanted[name] = fractional.str()
			}
		} else {
			value := intl_string_option(mut vm, options, name, intl_date_component_values(name))!
			if !value.is_undefined() { wanted[name] = value.as_string().str() }
		}
	}
	intl_string_option(mut vm, options, 'formatMatcher', ['basic', 'best fit'])!
	date_style_value := intl_string_option(mut vm, options, 'dateStyle', ['full', 'long', 'medium', 'short'])!
	time_style_value := intl_string_option(mut vm, options, 'timeStyle', ['full', 'long', 'medium', 'short'])!
	date_style := if date_style_value.is_undefined() { '' } else { date_style_value.as_string().str() }
	time_style := if time_style_value.is_undefined() { '' } else { time_style_value.as_string().str() }
	if required == .date && time_style != '' { return vm.throw_error(.type_error, 'timeStyle is not allowed for toLocaleDateString') }
	if required == .time && date_style != '' { return vm.throw_error(.type_error, 'dateStyle is not allowed for toLocaleTimeString') }
	mut pattern := []IntlDatePatternToken{}
	if date_style != '' || time_style != '' {
		if wanted.len > 0 { return vm.throw_error(.type_error, 'dateStyle/timeStyle cannot be combined with explicit date components') }
		date := if date_style != '' { intl_parse_date_pattern(mut vm, data.date_formats[date_style])! } else { []IntlDatePatternToken{} }
		mut clock := if time_style != '' { intl_parse_date_pattern(mut vm, data.time_formats[time_style])! } else { []IntlDatePatternToken{} }
		clock = intl_adjust_style_hour_cycle(mut vm, data, clock, hour_cycle)!
		combination := data.at_time[date_style] or { data.combinations[date_style] or { '{1}, {0}' } }
		pattern = intl_combine_date_patterns(mut vm, date, clock, combination)!
	} else {
		mut need_defaults := true
		if required in [.any,.date] {
			for name in ['weekday','year','month','day'] { if name in wanted { need_defaults = false } }
		}
		if required in [.any,.time] {
			for name in ['dayPeriod','hour','minute','second','fractionalSecondDigits'] { if name in wanted { need_defaults = false } }
		}
		if need_defaults {
			if defaults in [.date,.all] { wanted['year'] = 'numeric'; wanted['month'] = 'numeric'; wanted['day'] = 'numeric' }
			if defaults in [.time,.all] { wanted['hour'] = 'numeric'; wanted['minute'] = 'numeric'; wanted['second'] = 'numeric' }
		}
		mut date_wanted := map[string]string{}
		mut time_wanted := map[string]string{}
		for name, value in wanted {
			if name in ['weekday', 'era', 'year', 'month', 'day'] { date_wanted[name] = value }
			else { time_wanted[name] = value }
		}
		if hour_cycle in ['h23', 'h24'] && 'hour' in time_wanted { time_wanted.delete('dayPeriod') }
		zone_style := time_wanted['timeZoneName'] or { '' }
		time_wanted.delete('timeZoneName')
		if fractional > 0 && time_wanted.len > 1 { time_wanted.delete('fractionalSecondDigits') }
		date := intl_best_date_pattern(mut vm, data, date_wanted, hour_cycle)!
		mut clock := intl_best_date_pattern(mut vm, data, time_wanted, hour_cycle)!
		if fractional > 0 && time_wanted.len > 0 && 'fractionalSecondDigits' !in time_wanted {
			clock = intl_add_fractional_seconds(clock, fractional, data.decimal[numbering_system] or { '.' })
		}
		style := if wanted['month'] in ['long', 'narrow'] { 'long' } else if wanted['month'] == 'short' { 'medium' } else { 'short' }
		pattern = intl_combine_date_patterns(mut vm, date, clock, data.combinations[style] or { '{1}, {0}' })!
		if zone_style != '' {
			pattern << IntlDatePatternToken{literal: ' '}
			pattern << IntlDatePatternToken{field: if zone_style.ends_with('Offset') { `O` } else if zone_style.ends_with('Generic') { `v` } else { `z` }, count: if zone_style.starts_with('long') { 4 } else { 1 }}
		}
	}
	fields, supported := intl_date_pattern_fields(pattern)
	if !supported { return vm.throw_error(.internal_error, 'Unsupported CLDR Gregorian date field') }
	mut resolved_id := intl_canonicalize_language_tag(mut vm, utf16_string(data_locale))!
	resolved_id.keywords = retained
	mut object := Object.create(vm.realm(), prototype)
	object.class_name = 'Intl.DateTimeFormat'
	object.intl_date_time_format = &IntlDateTimeFormat{object: object, locale: resolved_id.tag(), data_locale: data_locale, calendar: calendar, numbering_system: numbering_system, time_zone: zone, hour_cycle: hour_cycle, date_style: date_style, time_style: time_style, pattern: pattern, fields: fields}
	return object
}

fn intl_adjust_style_hour_cycle(mut vm VM, data &IntlDateLocaleData, tokens []IntlDatePatternToken, cycle string) ![]IntlDatePatternToken {
	mut fields, supported := intl_date_pattern_fields(tokens)
	if !supported { return vm.throw_error(.internal_error, 'Unsupported CLDR time style') }
	if 'hour' !in fields { return tokens }
	fields['hour'] = 'numeric'
	if cycle in ['h23', 'h24'] { fields.delete('dayPeriod') }
	return intl_best_date_pattern(mut vm, data, fields, cycle)
}

fn intl_add_fractional_seconds(tokens []IntlDatePatternToken, digits int, decimal string) []IntlDatePatternToken {
	mut result := []IntlDatePatternToken{}
	mut inserted := false
	for token in tokens {
		result << token
		if token.field == `s` { result << IntlDatePatternToken{literal: decimal}; result << IntlDatePatternToken{field: `S`, count: digits}; inserted = true }
	}
	if !inserted { result << IntlDatePatternToken{literal: decimal}; result << IntlDatePatternToken{field: `S`, count: digits} }
	return result
}

fn intl_date_format_getter(mut vm VM) !Value {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut formatter := intl_date_time_format_this(mut vm)!
	if bound := formatter.bound_format { return Value.from_object(bound) }
	function := create_intl_date_format_function(mut vm, formatter)
	formatter.bound_format = function
	return Value.from_object(function)
}

fn intl_date_resolved_options(mut vm VM) !Value {
	formatter := intl_date_time_format_this(mut vm)!
	mut result := Object.create(vm.realm(), vm.realm().object_prototype)
	for name, value in {'locale': formatter.locale, 'calendar': formatter.calendar, 'numberingSystem': formatter.numbering_system, 'timeZone': formatter.time_zone.identifier} {
		result.create_data_property_or_throw(mut vm, PropertyName.from_str(name), Value.from_string(vm.create_string_from_str(value)))!
	}
	if 'hour' in formatter.fields {
		result.create_data_property_or_throw(mut vm, PropertyName.from_str('hourCycle'), Value.from_string(vm.create_string_from_str(formatter.hour_cycle)))!
		result.create_data_property_or_throw(mut vm, PropertyName.from_str('hour12'), Value.from_bool(formatter.hour_cycle in ['h11', 'h12']))!
	}
	if formatter.date_style == '' && formatter.time_style == '' {
		for name in ['weekday', 'era', 'year', 'month', 'day', 'dayPeriod', 'hour', 'minute', 'second', 'fractionalSecondDigits', 'timeZoneName'] {
			if value := formatter.fields[name] {
				result.create_data_property_or_throw(mut vm, PropertyName.from_str(name), if name == 'fractionalSecondDigits' { Value.from_i32(value.i32()) } else { Value.from_string(vm.create_string_from_str(value)) })!
			}
		}
	}
	for name, value in {'dateStyle': formatter.date_style, 'timeStyle': formatter.time_style} { if value != '' { result.create_data_property_or_throw(mut vm, PropertyName.from_str(name), Value.from_string(vm.create_string_from_str(value)))! } }
	return Value.from_object(result)
}

fn initialize_intl_date_time_format(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(realm, realm.object_prototype)
	realm.intl_date_time_format_prototype = prototype
	mut constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		fn (mut vm VM) !Value {
			constructor := vm.realm().intl_date_time_format_constructor or { panic('Missing Intl.DateTimeFormat') }
			return Value.from_object(construct(mut vm, Value.from_object(constructor), [vm.argument(0), vm.argument(1)], none)!)
		}, intl_date_time_format_construct, 0, PropertyName.from_str('DateTimeFormat')).object
	realm.intl_date_time_format_constructor = constructor
	constructor.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(constructor), attribute_writable | attribute_configurable)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('Intl.DateTimeFormat')), attribute_configurable)
	install_intrinsic_method(mut vm, realm, mut constructor, 'supportedLocalesOf', 1, fn (mut vm VM) !Value { return intl_supported_locales(mut vm, vm.argument(0), vm.argument(1)) })
	prototype.define_native_accessor(mut vm, realm, PropertyName.from_str('format'), intl_date_format_getter, unsafe { nil }, attribute_configurable, realm.function_prototype)
	install_intrinsic_method(mut vm, realm, mut prototype, 'resolvedOptions', 0, intl_date_resolved_options)
	install_intrinsic_method(mut vm, realm, mut prototype, 'formatToParts', 1, fn (mut vm VM) !Value {
		formatter := intl_date_time_format_this(mut vm)!
		parts := intl_format_date_parts(mut vm, formatter, vm.argument(0))!
		mut values := []Value{cap: parts.len}
		for part in parts {
			mut object := Object.create(vm.realm(), vm.realm().object_prototype)
			object.create_data_property_or_throw(mut vm, PropertyName.from_str('type'), Value.from_string(vm.create_string_from_str(part.type_)))!
			object.create_data_property_or_throw(mut vm, PropertyName.from_str('value'), Value.from_string(vm.create_string_from_str(part.value)))!
			values << Value.from_object(object)
		}
		return Value.from_object(ArrayObject.create_from(mut vm, vm.realm(), values, vm.realm().array_prototype_record())!.object)
	})
	mut namespace := realm.intl_object or { panic('Missing Intl namespace') }
	namespace.define_direct_property(PropertyName.from_str('DateTimeFormat'), Value.from_object(constructor), attribute_writable | attribute_configurable)
}
