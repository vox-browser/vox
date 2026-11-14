module libjs

// RegExpObject.cpp / RegExpPrototype.cpp: ordinary builtin execution over the
// translated UTF-16 RegexEngine. No native regex or JavaScript engine is used.
@[heap]
pub struct RegExpObject {
	object &Object
	pattern Utf16String
	flags_text Utf16String
	flags RegExpFlags
mut:
	engine &RegexEngine
}

fn regexp_pattern_points(pattern Utf16String) []rune {
	mut points := []rune{}
	for index := 0; index < pattern.len(); {
		point := string_code_point_at(pattern, index)
		points << rune(point.code_point)
		index += point.code_unit_count
	}
	return points
}

fn compile_regexp_engine(pattern Utf16String, text Utf16String) !&RegexEngine {
	flags := validate_regexp_flags(text)!
	return RegexEngine.compile(regexp_pattern_points(pattern), RegexAstFlags{
		global: flags.has(.global)
		ignore_case: flags.has(.ignore_case)
		multiline: flags.has(.multiline)
		dot_all: flags.has(.dot_all)
		unicode: flags.has(.unicode)
		unicode_sets: flags.has(.unicode_sets)
		sticky: flags.has(.sticky)
		has_indices: flags.has(.has_indices)
	})
}

fn create_regexp_object(mut vm VM, pattern Utf16String, text Utf16String) !&Object {
	engine := compile_regexp_engine(pattern, text) or { return vm.throw_error(.syntax_error, err.msg()) }
	mut object := Object.create(vm.realm(), vm.realm().regexp_prototype)
	object.class_name = 'RegExp'
	object.regexp_object = &RegExpObject{object: object, pattern: pattern, flags_text: text, flags: regexp_to_flag_bits(text), engine: engine}
	object.define_direct_property(PropertyName.from_str('lastIndex'), Value.from_i32(0), attribute_writable)
	return object
}

fn initialize_regexp_intrinsics(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(&realm, realm.object_prototype)
	realm.regexp_prototype = prototype
	install_intrinsic_method(mut vm, &realm, mut prototype, 'exec', 1, regexp_prototype_exec)
	install_intrinsic_method(mut vm, &realm, mut prototype, 'test', 1, fn (mut vm VM) !Value {
		object := vm.this_value()
		if !object.is_object() { return vm.throw_error(.type_error, 'RegExp test requires an object') }
		text := vm.argument(0).to_primitive_string(mut vm)!
		return Value.from_bool(!regexp_exec(mut vm, object.as_object(), text)!.is_null())
	})
	for name in ['source', 'flags', 'global', 'ignoreCase', 'multiline', 'dotAll', 'unicode', 'unicodeSets', 'sticky', 'hasIndices'] {
		prototype.define_native_accessor(mut vm, &realm, PropertyName.from_str(name), fn [name] (mut vm VM) !Value {
			if name == 'flags' {
				if !vm.this_value().is_object() { return vm.throw_error(.type_error, 'RegExp flags requires an object') }
				object := vm.this_value().as_object()
				mut flags := ''
				for index, key in ['hasIndices','global','ignoreCase','multiline','dotAll','unicode','unicodeSets','sticky'] {
					if object.get(mut vm, PropertyName.from_str(key))!.to_boolean() { flags += ['d','g','i','m','s','u','v','y'][index] }
				}
				return Value.from_string(vm.create_string_from_str(flags))
			}
			if vm.this_value().is_object() && voidptr(vm.this_value().as_object()) == voidptr(vm.realm().regexp_prototype or { panic('Missing RegExp prototype') }) {
				return if name == 'source' { Value.from_string(vm.create_string_from_str('(?:)')) } else { js_undefined() }
			}
			regex := regexp_receiver(mut vm)!
			if name == 'source' { return Value.from_string(vm.create_string(escape_regexp_pattern(regex.pattern))) }
			flag := match name {
				'global' { RegExpFlags.global }
				'ignoreCase' { RegExpFlags.ignore_case }
				'multiline' { RegExpFlags.multiline }
				'dotAll' { RegExpFlags.dot_all }
				'unicode' { RegExpFlags.unicode }
				'unicodeSets' { RegExpFlags.unicode_sets }
				'sticky' { RegExpFlags.sticky }
				else { RegExpFlags.has_indices }
			}
			return Value.from_bool(regex.flags.has(flag))
		}, unsafe { nil }, attribute_configurable, realm.function_prototype)
	}
	match_function := NativeFunction.create(mut vm, &realm, realm.function_prototype, regexp_symbol_match, 1, PropertyName.from_symbol(vm.well_known_symbol_match()), none)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_match()), Value.from_object(match_function.object), attribute_writable | attribute_configurable)
	install_intrinsic_method(mut vm, &realm, mut prototype, 'toString', 0, fn (mut vm VM) !Value {
		if !vm.this_value().is_object() { return vm.throw_error(.type_error, 'RegExp toString requires an object') }
		object := vm.this_value().as_object()
		source := object.get(mut vm, PropertyName.from_str('source'))!.to_primitive_string(mut vm)!
		flags := object.get(mut vm, PropertyName.from_str('flags'))!.to_primitive_string(mut vm)!
		return Value.from_string(vm.create_string(utf16_concat([utf16_string('/'), source.utf16, utf16_string('/'), flags.utf16])))
	})
	constructor := NativeFunction.create_constructor(mut vm, &realm, realm.function_prototype, regexp_constructor_call,
		fn (mut vm VM, target &Object) !&Object {
			mut object := regexp_constructor_create(mut vm)!
			prototype_value := target.get(mut vm, PropertyName.from_str('prototype'))!
			if prototype_value.is_object() { object.internal_set_prototype_of(prototype_value.as_object()) }
			return object
		}, 2, PropertyName.from_str('RegExp'))
	mut object := constructor.object
	object.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
	prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(object), attribute_writable | attribute_configurable)
	realm.regexp_constructor = object
	mut text := realm.string_prototype or { panic('Missing String prototype') }
	install_intrinsic_method(mut vm, &realm, mut text, 'match', 1, string_prototype_match)
}

fn regexp_constructor_call(mut vm VM) !Value {
	pattern := vm.argument(0)
	if pattern.is_object() && pattern.as_object().regexp_object != none && vm.argument(1).is_undefined() { return pattern }
	return Value.from_object(regexp_constructor_create(mut vm)!)
}

fn regexp_constructor_create(mut vm VM) !&Object {
	pattern := vm.argument(0)
	flags := vm.argument(1)
	mut pattern_text := Utf16String.new()
	mut flag_text := Utf16String.new()
	if pattern.is_object() {
		if regex := pattern.as_object().regexp_object {
			pattern_text = regex.pattern
			flag_text = regex.flags_text
		} else { pattern_text = pattern.to_primitive_string(mut vm)!.utf16 }
	} else if !pattern.is_undefined() { pattern_text = pattern.to_primitive_string(mut vm)!.utf16 }
	if !flags.is_undefined() { flag_text = flags.to_primitive_string(mut vm)!.utf16 }
	return create_regexp_object(mut vm, pattern_text, flag_text)
}

fn regexp_receiver(mut vm VM) !&RegExpObject {
	if vm.this_value().is_object() {
		if regex := vm.this_value().as_object().regexp_object { return regex }
	}
	return vm.throw_error(.type_error, 'RegExp method called on incompatible receiver')
}

fn regexp_prototype_exec(mut vm VM) !Value {
	mut regex := regexp_receiver(mut vm)!
	text := vm.argument(0).to_primitive_string(mut vm)!
	return regex.builtin_exec(mut vm, text)
}

fn regexp_exec(mut vm VM, object &Object, text &PrimitiveString) !Value {
	exec := object.get(mut vm, PropertyName.from_str('exec'))!
	if exec.is_function() {
		result := call(mut vm, exec, Value.from_object(object), [Value.from_string(text)])!
		if !result.is_object() && !result.is_null() { return vm.throw_error(.type_error, 'RegExp exec must return an object or null') }
		return result
	}
	mut regex := object.regexp_object or { return vm.throw_error(.type_error, 'RegExp exec requires RegExp internal slots') }
	return regex.builtin_exec(mut vm, text)
}

fn (mut regex RegExpObject) builtin_exec(mut vm VM, text &PrimitiveString) !Value {
	vm.consume_execution_budget()!
	mut object := regex.object
	mut start := object.get(mut vm, PropertyName.from_str('lastIndex'))!.to_length(mut vm)!
	stateful := regex.flags.has(.global) || regex.flags.has(.sticky)
	if !stateful { start = 0 }
	mut slots := []i32{len: int(regex.engine.program.capture_count + 1) * 2, init: -1}
	mut matched := false
	if start <= u64(text.utf16.len()) {
		status := regex.engine.exec(RegexUtf16Input{units: text.utf16.code_units()}, uint(start), mut slots)
		if status == .limit_exceeded { return vm.throw_error(.internal_error, 'LibJS regular expression execution limit exceeded') }
		matched = status == .match
	}
	if !matched {
		if stateful { object.set(mut vm, PropertyName.from_str('lastIndex'), Value.from_i32(0), .yes)! }
		return js_null()
	}
	if stateful { object.set(mut vm, PropertyName.from_str('lastIndex'), Value.from_i32(slots[1]), .yes)! }
	mut values := []Value{}
	for index := 0; index < slots.len; index += 2 {
		values << if slots[index] < 0 { js_undefined() } else { Value.from_string(vm.create_string(utf16_string_from_code_units(text.utf16.data[int(slots[index])..int(slots[index + 1])]))) }
	}
	mut result := ArrayObject.create_from(mut vm, vm.realm(), values, vm.realm().array_prototype_record())!.object
	result.create_data_property_or_throw(mut vm, PropertyName.from_str('index'), Value.from_i32(slots[0]))!
	result.create_data_property_or_throw(mut vm, PropertyName.from_str('input'), Value.from_string(text))!
	mut groups := js_undefined()
	if regex.engine.program.named_groups.len > 0 {
		mut named := Object.create(vm.realm(), none)
		for group in regex.engine.program.named_groups {
			key := PropertyName.from_str(group.name)
			if !named.has_own_property(key) || named.get(mut vm, key)!.is_undefined() {
				named.create_data_property_or_throw(mut vm, key, values[int(group.index)])!
			}
		}
		groups = Value.from_object(named)
	}
	result.create_data_property_or_throw(mut vm, PropertyName.from_str('groups'), groups)!
	if regex.flags.has(.has_indices) {
		mut indices := []Value{}
		for index := 0; index < slots.len; index += 2 {
			indices << if slots[index] < 0 { js_undefined() } else {
				Value.from_object(ArrayObject.create_from(mut vm, vm.realm(), [Value.from_i32(slots[index]), Value.from_i32(slots[index + 1])], vm.realm().array_prototype_record())!.object)
			}
		}
		mut array := ArrayObject.create_from(mut vm, vm.realm(), indices, vm.realm().array_prototype_record())!.object
		mut named_indices := js_undefined()
		if regex.engine.program.named_groups.len > 0 {
			mut named := Object.create(vm.realm(), none)
			for group in regex.engine.program.named_groups {
				key := PropertyName.from_str(group.name)
				if !named.has_own_property(key) || named.get(mut vm, key)!.is_undefined() { named.create_data_property_or_throw(mut vm, key, indices[int(group.index)])! }
			}
			named_indices = Value.from_object(named)
		}
		array.create_data_property_or_throw(mut vm, PropertyName.from_str('groups'), named_indices)!
		result.create_data_property_or_throw(mut vm, PropertyName.from_str('indices'), Value.from_object(array))!
	}
	return Value.from_object(result)
}

fn regexp_symbol_match(mut vm VM) !Value {
	if !vm.this_value().is_object() { return vm.throw_error(.type_error, 'RegExp match requires an object') }
	mut object := vm.this_value().as_object()
	text := vm.argument(0).to_primitive_string(mut vm)!
	if !object.get(mut vm, PropertyName.from_str('global'))!.to_boolean() { return regexp_exec(mut vm, object, text) }
	unicode := object.get(mut vm, PropertyName.from_str('unicode'))!.to_boolean() || object.get(mut vm, PropertyName.from_str('unicodeSets'))!.to_boolean()
	object.set(mut vm, PropertyName.from_str('lastIndex'), Value.from_i32(0), .yes)!
	mut matches := []Value{}
	for {
		vm.consume_execution_budget()!
		result := regexp_exec(mut vm, object, text)!
		if result.is_null() { break }
		value := result.as_object().get(mut vm, PropertyName.from_number(0))!.to_primitive_string(mut vm)!
		matches << Value.from_string(value)
		if value.is_empty() {
			index := object.get(mut vm, PropertyName.from_str('lastIndex'))!.to_length(mut vm)!
			next := if unicode && index < u64(text.utf16.len()) { index + u64(string_code_point_at(text.utf16, int(index)).code_unit_count) } else { index + 1 }
			object.set(mut vm, PropertyName.from_str('lastIndex'), Value.from_f64(f64(next)), .yes)!
		}
	}
	if matches.len == 0 { return js_null() }
	return Value.from_object(ArrayObject.create_from(mut vm, vm.realm(), matches, vm.realm().array_prototype_record())!.object)
}

fn string_prototype_match(mut vm VM) !Value {
	receiver := vm.this_value()
	require_object_coercible(mut vm, receiver)!
	pattern := vm.argument(0)
	if !pattern.is_nullish() {
		object := pattern.to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
		method := object.get_method(mut vm, PropertyName.from_symbol(vm.well_known_symbol_match()))!
		if !method.is_undefined() { return call(mut vm, method, pattern, [receiver]) }
	}
	text := receiver.to_primitive_string(mut vm)!
	pattern_text := if pattern.is_undefined() { Utf16String.new() } else { pattern.to_primitive_string(mut vm)!.utf16 }
	object := create_regexp_object(mut vm, pattern_text, Utf16String.new())!
	method := object.get(mut vm, PropertyName.from_symbol(vm.well_known_symbol_match()))!
	return call(mut vm, method, Value.from_object(object), [Value.from_string(text)])
}
