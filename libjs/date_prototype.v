// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math
import time

// Runtime/DatePrototype.cpp. Shared dispatch retains the individual native
// names, lengths and descriptors while using the same Date abstract operations.
fn initialize_date_prototype(mut vm VM, realm &Realm, mut prototype Object) {
	for name in ['getDate', 'getDay', 'getFullYear', 'getHours', 'getMilliseconds', 'getMinutes',
		'getMonth', 'getSeconds', 'getTime', 'getTimezoneOffset', 'getUTCDate', 'getUTCDay',
		'getUTCFullYear', 'getUTCHours', 'getUTCMilliseconds', 'getUTCMinutes', 'getUTCMonth',
		'getUTCSeconds', 'getYear', 'valueOf', 'toString', 'toDateString', 'toTimeString', 'toUTCString',
		'toISOString'] {
		function := NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
			fn [name] (mut vm VM) !Value { return date_prototype_read(mut vm, name) }, 0, PropertyName.from_str(name), none)
		prototype.define_direct_property(PropertyName.from_str(name), Value.from_object(function.object), attribute_writable | attribute_configurable)
	}
	names := ['setDate', 'setFullYear', 'setHours', 'setMilliseconds', 'setMinutes', 'setMonth',
		'setSeconds', 'setTime', 'setUTCDate', 'setUTCFullYear', 'setUTCHours', 'setUTCMilliseconds',
		'setUTCMinutes', 'setUTCMonth', 'setUTCSeconds', 'setYear']
	lengths := [1, 3, 4, 1, 3, 2, 2, 1, 1, 3, 4, 1, 3, 2, 2, 1]
	for i, name in names {
		function := NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
			fn [name] (mut vm VM) !Value { return date_prototype_set(mut vm, name) }, lengths[i], PropertyName.from_str(name), none)
		prototype.define_direct_property(PropertyName.from_str(name), Value.from_object(function.object), attribute_writable | attribute_configurable)
	}
	install_intrinsic_method(mut vm, realm, mut prototype, 'toJSON', 1, date_prototype_to_json)
	primitive := NativeFunction.create_raw(mut vm, realm, realm.function_prototype, date_prototype_to_primitive,
		1, PropertyName.from_symbol(vm.well_known_symbol_to_primitive()), none)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()), Value.from_object(primitive.object), attribute_configurable)
	prototype.define_direct_property(PropertyName.from_str('toGMTString'), prototype.get_without_side_effects(PropertyName.from_str('toUTCString')), attribute_writable | attribute_configurable)
}

fn date_prototype_read(mut vm VM, name string) !Value {
	value := this_date_object(mut vm)!.date_value
	if name in ['getTime', 'valueOf'] { return Value.from_f64(value) }
	if name.starts_with('to') {
		if math.is_nan(value) {
			if name == 'toISOString' { return vm.throw_error(.range_error, 'Invalid time value') }
			return Value.from_string(vm.create_string_from_str('Invalid Date'))
		}
		text := match name {
			'toISOString' { date_iso_string(value) }
			'toDateString' { date_date_string(date_local_time(value), false) }
			'toTimeString' { date_time_string(value) }
			'toUTCString' {
				t := time.unix_milli(i64(value))
				date_date_string(value, true) + ' ${t.hour:02}:${t.minute:02}:${t.second:02} GMT'
			}
			else { date_to_string(value) }
		}
		return Value.from_string(vm.create_string_from_str(text))
	}
	if math.is_nan(value) { return Value.from_f64(math.nan()) }
	local := date_local_time(value)
	if name == 'getTimezoneOffset' { return Value.from_f64((value - local) / 60000) }
	clock := if name.starts_with('getUTC') { value } else { local }
	t := time.unix_milli(i64(clock))
	suffix := if name.starts_with('getUTC') { name[6..] } else { name[3..] }
	result := match suffix {
		'Date' { t.day }
		'Day' { int(math.fmod(math.fmod(math.floor(clock / 86400000) + 4, 7) + 7, 7)) }
		'FullYear' { t.year }
		'Year' { t.year - 1900 }
		'Month' { t.month - 1 }
		'Hours' { t.hour }
		'Minutes' { t.minute }
		'Seconds' { t.second }
		else { t.nanosecond / 1000000 }
	}
	return Value.from_f64(f64(result))
}

fn date_prototype_set(mut vm VM, name string) !Value {
	mut date := this_date_object(mut vm)!
	// Read the time before argument conversions, which can re-enter setTime.
	mut value := date.date_value
	first := vm.argument(0).to_number(mut vm)!.number
	if name == 'setTime' {
		date.date_value = date_time_clip(first)
		return Value.from_f64(date.date_value)
	}
	utc := name.starts_with('setUTC')
	suffix := if utc { name[6..] } else { name[3..] }
	if math.is_nan(value) && suffix in ['FullYear', 'Year'] {
		value = 0
	} else if !utc && !math.is_nan(value) {
		value = date_local_time(value)
	}
	// NaN still converts all provided parameters before returning NaN.
	t := time.unix_milli(if math.is_nan(value) { i64(0) } else { i64(value) })
	mut fields := [f64(t.year), f64(t.month - 1), f64(t.day), f64(t.hour), f64(t.minute),
		f64(t.second), f64(t.nanosecond / 1000000)]
	start := match suffix {
		'FullYear', 'Year' { 0 }
		'Month' { 1 }
		'Date' { 2 }
		'Hours' { 3 }
		'Minutes' { 4 }
		'Seconds' { 5 }
		else { 6 }
	}
	count := match suffix {
		'FullYear' { 3 }
		'Month', 'Seconds' { 2 }
		'Hours' { 4 }
		'Minutes' { 3 }
		else { 1 }
	}
	fields[start] = first
	for i in 1 .. count {
		if vm.argument_count() > i { fields[start + i] = vm.argument(i).to_number(mut vm)!.number }
	}
	if suffix == 'Year' && math.trunc(first) >= 0 && math.trunc(first) <= 99 {
		fields[0] = math.trunc(first) + 1900
	}
	mut result := if math.is_nan(value) {
		math.nan()
	} else {
		date_make_date(fields[0], fields[1], fields[2], fields[3], fields[4], fields[5], fields[6])
	}
	if !utc { result = date_utc_time(result) }
	date.date_value = date_time_clip(result)
	return Value.from_f64(date.date_value)
}

fn date_prototype_to_json(mut vm VM) !Value {
	object := vm.this_value().to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	value := Value.from_object(object).to_primitive_with_hint(mut vm, .number)!
	if value.is_number() && !value.is_finite_number() { return js_null() }
	method := object.get(mut vm, PropertyName.from_str('toISOString'))!
	return call(mut vm, method, Value.from_object(object), []Value{})
}

fn date_prototype_to_primitive(mut vm VM) !Value {
	value := vm.this_value()
	if !value.is_object() { return vm.throw_error_type(.type_error, .not_an_object, value.str()) }
	hint := vm.argument(0)
	if hint.is_string() {
		text := hint.as_string().str()
		if text in ['default', 'string', 'number'] {
			return value.as_object().ordinary_to_primitive(mut vm, if text == 'number' {
				PreferredType.number
			} else {
				PreferredType.string
			})
		}
	}
	return vm.throw_error(.type_error, 'Invalid hint for Date conversion')
}
