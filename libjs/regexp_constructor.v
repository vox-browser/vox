// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Value.cpp::IsRegExp observes @@match even for branded RegExp objects.
pub fn (value Value) is_regexp(mut vm VM) !bool {
	if !value.is_object() { return false }
	object := value.as_object()
	matcher := object.get(mut vm, PropertyName.from_symbol(vm.well_known_symbol_match()))!
	if !matcher.is_undefined() { return matcher.to_boolean() }
	return object.slots.regexp_object != none
}

// RegExpConstructor.cpp::call / construct_impl. Check @@match once, read
// generic source/flags before allocating, and coerce only after NewTarget's
// prototype lookup. Native slots retain their original pattern and flags.
fn regexp_constructor_call(mut vm VM) !Value {
	pattern := vm.argument(0)
	is_regexp := pattern.is_regexp(mut vm)!
	active := vm.active_function_object() or { return error('RegExp call has no active function') }
	if active !is NativeFunction { return error('RegExp call requires its native constructor') }
	if is_regexp && vm.argument(1).is_undefined() {
		constructor := pattern.as_object().get(mut vm, PropertyName.from_str('constructor'))!
		if is_strictly_equal(constructor, Value.from_object(active.object)) { return pattern }
	}
	return Value.from_object(regexp_constructor_create(mut vm, active.object, is_regexp)!)
}

fn regexp_constructor_construct(mut vm VM, new_target &Object) !&Object {
	is_regexp := vm.argument(0).is_regexp(mut vm)!
	return regexp_constructor_create(mut vm, new_target, is_regexp)
}

fn regexp_constructor_create(mut vm VM, new_target &Object, is_regexp bool) !&Object {
	pattern := vm.argument(0)
	flags := vm.argument(1)
	mut pattern_value := pattern
	mut flags_value := flags
	mut branded := false
	if pattern.is_object() {
		if record := pattern.as_object().slots.regexp_object {
			branded = true
			pattern_value = Value.from_string(vm.create_string(record.pattern))
			if flags.is_undefined() { flags_value = Value.from_string(vm.create_string(record.flags_text)) }
		}
	}
	if !branded && is_regexp {
		object := pattern.as_object()
		pattern_value = object.get(mut vm, PropertyName.from_str('source'))!
		if flags.is_undefined() { flags_value = object.get(mut vm, PropertyName.from_str('flags'))! }
	}
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.regexp_prototype or { panic('Missing RegExp prototype') } })!
	pattern_text := if pattern_value.is_undefined() { Utf16String.new() } else { pattern_value.to_primitive_string(mut vm)!.utf16 }
	flags_text := if flags_value.is_undefined() { Utf16String.new() } else { flags_value.to_primitive_string(mut vm)!.utf16 }
	mut object := create_regexp_object(mut vm, pattern_text, flags_text)!
	object.prototype = prototype
	return object
}
