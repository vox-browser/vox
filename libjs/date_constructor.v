// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math
import time

// Runtime/DateConstructor.cpp. Intl/Temporal integration and implementation-
// defined legacy date-string formats remain separate slices.
fn initialize_date_intrinsics(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(realm, realm.object_prototype)
	realm.date_prototype = prototype
	function := NativeFunction.create_constructor_record(mut vm, realm, realm.function_prototype,
		date_constructor_call, date_constructor_construct, PropertyName.from_str('Date'))
	mut constructor := function.object
	realm.date_constructor = constructor
	constructor.set_function_length(7)
	constructor.set_function_name(mut vm, PropertyName.from_str('Date'), none)
	constructor.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(constructor), attribute_writable | attribute_configurable)
	install_intrinsic_method(mut vm, realm, mut constructor, 'now', 0, date_constructor_now)
	install_intrinsic_method(mut vm, realm, mut constructor, 'parse', 1, date_constructor_parse)
	install_intrinsic_method(mut vm, realm, mut constructor, 'UTC', 7, date_constructor_utc)
	initialize_date_prototype(mut vm, realm, mut prototype)
}

fn date_constructor_call(mut vm VM) !Value {
	return Value.from_string(vm.create_string_from_str(date_to_string(f64(time.utc().unix_milli()))))
}

fn date_constructor_now(mut vm VM) !Value {
	return Value.from_f64(f64(time.utc().unix_milli()))
}

fn date_constructor_parse(mut vm VM) !Value {
	text := vm.argument(0).to_primitive_string(mut vm)!
	return Value.from_f64(parse_date_string(text.utf16))
}

fn date_constructor_components(mut vm VM, utc bool) !f64 {
	mut values := [0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0]
	values[0] = vm.argument(0).to_number(mut vm)!.number
	for i in 1 .. 7 {
		if vm.argument_count() > i { values[i] = vm.argument(i).to_number(mut vm)!.number }
	}
	integer_year := math.trunc(values[0])
	if integer_year >= 0 && integer_year <= 99 { values[0] = integer_year + 1900 }
	value := date_make_date(values[0], values[1], values[2], values[3], values[4], values[5], values[6])
	return date_time_clip(if utc { value } else { date_utc_time(value) })
}

fn date_constructor_utc(mut vm VM) !Value {
	return Value.from_f64(date_constructor_components(mut vm, true)!)
}

fn date_constructor_construct(mut vm VM, new_target &Object) !&Object {
	mut value := 0.0
	if vm.argument_count() == 0 {
		value = f64(time.utc().unix_milli())
	} else if vm.argument_count() == 1 {
		argument := vm.argument(0)
		if argument.is_object() && argument.as_object().date_object != none {
			value = argument.as_object().date_object or { panic('Missing Date slot') }.date_value
		} else {
			primitive := argument.to_primitive(mut vm)!
			value = if primitive.is_string() {
				parse_date_string(primitive.as_string().utf16)
			} else {
				primitive.to_number(mut vm)!.number
			}
		}
		value = date_time_clip(value)
	} else {
		value = date_constructor_components(mut vm, false)!
	}
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object {
		return realm.date_prototype or { panic('Missing Date prototype') }
	})!
	return create_date_object(vm.realm(), prototype, value)
}
