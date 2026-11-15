// SPDX-License-Identifier: BSD-2-Clause
module libjs

// RegExpPrototype.cpp::symbol_match_all and RegExpStringIteratorPrototype.cpp.
// Matching stays lazy and uses observable RegExpExec, including custom species.
@[heap]
pub struct RegExpStringIterator {
	regexp &Object
	text &PrimitiveString
	global bool
	unicode bool
mut:
	done bool
}

fn initialize_regexp_match_all_intrinsics(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(realm, realm.iterator_prototype)
	realm.regexp_string_iterator_prototype = prototype
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('RegExp String Iterator')), attribute_configurable)
	install_intrinsic_method(mut vm, realm, mut prototype, 'next', 0, regexp_string_iterator_next)
	mut regexp := realm.regexp_prototype or { panic('Missing RegExp prototype') }
	method := NativeFunction.create(mut vm, realm, realm.function_prototype, regexp_symbol_match_all, 1, PropertyName.from_symbol(vm.well_known_symbol_match_all()), none)
	regexp.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_match_all()), Value.from_object(method.object), attribute_writable | attribute_configurable)
	mut text := realm.string_prototype or { panic('Missing String prototype') }
	install_intrinsic_method(mut vm, realm, mut text, 'matchAll', 1, string_prototype_match_all)
}

fn regexp_symbol_match_all(mut vm VM) !Value {
	if !vm.this_value().is_object() { return vm.throw_error(.type_error, 'RegExp matchAll requires an object') }
	object := vm.this_value().as_object()
	text := vm.argument(0).to_primitive_string(mut vm)!
	constructor := species_constructor(mut vm, object, vm.realm().regexp_constructor or { panic('Missing RegExp constructor') })!
	flags := object.get(mut vm, PropertyName.from_str('flags'))!.to_primitive_string(mut vm)!
	matcher := construct(mut vm, Value.from_object(constructor), [Value.from_object(object), Value.from_string(flags)], none)!
	last_index := object.get(mut vm, PropertyName.from_str('lastIndex'))!.to_length(mut vm)!
	mut writable := matcher
	writable.set(mut vm, PropertyName.from_str('lastIndex'), Value.from_f64(f64(last_index)), .yes)!
	mut iterator := Object.create(vm.realm(), vm.realm().regexp_string_iterator_prototype)
	iterator.regexp_string_iterator = &RegExpStringIterator{
		regexp: matcher
		text: text
		global: flags.utf16.data.contains(u16(`g`))
		unicode: flags.utf16.data.contains(u16(`u`)) || flags.utf16.data.contains(u16(`v`))
	}
	return Value.from_object(iterator)
}

fn regexp_string_iterator_next(mut vm VM) !Value {
	value := vm.this_value()
	if !value.is_object() { return vm.throw_error(.type_error, 'RegExp String Iterator next requires its internal slots') }
	mut iterator := value.as_object().regexp_string_iterator or { return vm.throw_error(.type_error, 'RegExp String Iterator next requires its internal slots') }
	vm.consume_execution_budget()!
	if iterator.done { return Value.from_object(create_iterator_result_object(vm.realm(), js_undefined(), true, vm.realm().object_prototype)) }
	match_ := regexp_exec(mut vm, iterator.regexp, iterator.text)!
	if match_.is_null() {
		iterator.done = true
		return Value.from_object(create_iterator_result_object(vm.realm(), js_undefined(), true, vm.realm().object_prototype))
	}
	if !iterator.global {
		iterator.done = true
	} else {
		matched := match_.as_object().get(mut vm, PropertyName.from_number(0))!.to_primitive_string(mut vm)!
		if matched.is_empty() {
			mut regexp := iterator.regexp
			index := regexp.get(mut vm, PropertyName.from_str('lastIndex'))!.to_length(mut vm)!
			next := if iterator.unicode && index < u64(iterator.text.utf16.len()) { index + u64(string_code_point_at(iterator.text.utf16, int(index)).code_unit_count) } else { index + 1 }
			regexp.set(mut vm, PropertyName.from_str('lastIndex'), Value.from_f64(f64(next)), .yes)!
		}
	}
	return Value.from_object(create_iterator_result_object(vm.realm(), match_, false, vm.realm().object_prototype))
}

// StringPrototype.cpp::match_all. Validate global regex flags before reading
// @@matchAll, and delegate the original receiver without premature ToString.
fn string_prototype_match_all(mut vm VM) !Value {
	receiver := require_object_coercible(mut vm, vm.this_value())!
	pattern := vm.argument(0)
	if pattern.is_object() {
		object := pattern.as_object()
		if pattern.is_regexp(mut vm)! {
			flags := require_object_coercible(mut vm, object.get(mut vm, PropertyName.from_str('flags'))!)!
			if !flags.to_primitive_string(mut vm)!.utf16.data.contains(u16(`g`)) { return vm.throw_error(.type_error, 'String.matchAll requires a global regular expression') }
		}
		method := object.get_method(mut vm, PropertyName.from_symbol(vm.well_known_symbol_match_all()))!
		if !method.is_undefined() { return call(mut vm, method, pattern, [receiver]) }
	}
	text := receiver.to_primitive_string(mut vm)!
	pattern_text := if pattern.is_undefined() { Utf16String.new() } else { pattern.to_primitive_string(mut vm)!.utf16 }
	regexp := create_regexp_object(mut vm, pattern_text, utf16_string('g'))!
	method := regexp.get(mut vm, PropertyName.from_symbol(vm.well_known_symbol_match_all()))!
	return call(mut vm, method, Value.from_object(regexp), [Value.from_string(text)])
}
