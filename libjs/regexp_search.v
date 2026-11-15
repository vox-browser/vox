// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn initialize_regexp_search_intrinsics(mut vm VM, mut realm Realm) {
	mut prototype := realm.regexp_prototype or { panic('Missing RegExp prototype') }
	method := NativeFunction.create(mut vm, realm, realm.function_prototype, regexp_symbol_search, 1, PropertyName.from_symbol(vm.well_known_symbol_search()), none)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_search()), Value.from_object(method.object), attribute_writable | attribute_configurable)
	mut text := realm.string_prototype or { panic('Missing String prototype') }
	install_intrinsic_method(mut vm, realm, mut text, 'search', 1, string_prototype_search)
}

// RegExpPrototype.cpp::symbol_search. Preserve lastIndex as an arbitrary Value,
// with SameValue's NaN and signed-zero semantics. An abrupt exec propagates
// directly; restoration occurs only after its successful completion.
fn regexp_symbol_search(mut vm VM) !Value {
	if !vm.this_value().is_object() { return vm.throw_error(.type_error, 'RegExp search requires an object') }
	mut object := vm.this_value().as_object()
	text := vm.argument(0).to_primitive_string(mut vm)!
	previous := object.get(mut vm, PropertyName.from_str('lastIndex'))!
	if !same_value(previous, Value.from_i32(0)) { object.set(mut vm, PropertyName.from_str('lastIndex'), Value.from_i32(0), .yes)! }
	result := regexp_exec(mut vm, object, text)!
	current := object.get(mut vm, PropertyName.from_str('lastIndex'))!
	if !same_value(current, previous) { object.set(mut vm, PropertyName.from_str('lastIndex'), previous, .yes)! }
	if result.is_null() { return Value.from_i32(-1) }
	return result.as_object().get(mut vm, PropertyName.from_str('index'))
}

// StringPrototype.cpp::search. Symbol delegation precedes ToString(receiver),
// while fallback RegExpCreate uses the intrinsic graph rather than globals.
fn string_prototype_search(mut vm VM) !Value {
	receiver := require_object_coercible(mut vm, vm.this_value())!
	pattern := vm.argument(0)
	if pattern.is_object() {
		method := pattern.as_object().get_method(mut vm, PropertyName.from_symbol(vm.well_known_symbol_search()))!
		if !method.is_undefined() { return call(mut vm, method, pattern, [receiver]) }
	}
	text := receiver.to_primitive_string(mut vm)!
	pattern_text := if pattern.is_undefined() { Utf16String.new() } else { pattern.to_primitive_string(mut vm)!.utf16 }
	regexp := create_regexp_object(mut vm, pattern_text, Utf16String.new())!
	method := regexp.get(mut vm, PropertyName.from_symbol(vm.well_known_symbol_search()))!
	return call(mut vm, method, Value.from_object(regexp), [Value.from_string(text)])
}
