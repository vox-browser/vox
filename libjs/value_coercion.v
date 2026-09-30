module libjs

// Runtime/Value.cpp::ToPrimitive and Object.cpp::OrdinaryToPrimitive. Property
// lookup uses the translated ordinary data-property object model; accessor and
// exotic object [[Get]] hooks remain separate runtime work.
pub enum PreferredType {
	default_
	string
	number
}

pub fn (value Value) to_primitive(mut vm VM) !Value {
	return value.to_primitive_with_hint(mut vm, .default_)
}

pub fn (value Value) to_primitive_with_hint(mut vm VM, preferred_type PreferredType) !Value {
	if value.tag in [.empty, .accessor] {
		return vm.throw_error(.internal_error, 'ToPrimitive received an internal value')
	}
	if !value.is_object() { return value }
	object := value.as_object()
	method := object.get_method(mut vm,
		PropertyName.from_symbol(vm.well_known_symbol_to_primitive()))!
	if !method.is_undefined() {
		hint := match preferred_type {
			.default_ { 'default' }
			.string { 'string' }
			.number { 'number' }
		}

		result := call(mut vm, method, value, [
			Value.from_string(vm.create_string_from_str(hint)),
		])!
		if !result.is_object() { return result }
		return vm.throw_error_type(.type_error, .to_primitive_returned_object, value.str(), hint)
	}
	return object.ordinary_to_primitive(mut vm, if preferred_type == .default_ {
		PreferredType.number
	} else {
		preferred_type
	})
}

// The object-receiver path of 7.3.11 GetMethod ( V, P ).
pub fn (object &Object) get_method(mut vm VM, key PropertyName) !Value {
	method := object.get(key)
	if method.is_nullish() { return js_undefined() }
	if !method.is_function() {
		return vm.throw_error_type(.type_error, .not_a_function, method.str())
	}
	return method
}

pub fn (object &Object) ordinary_to_primitive(mut vm VM, preferred_type PreferredType) !Value {
	assert preferred_type in [.string, .number]
	method_names := if preferred_type == .string {
		['toString', 'valueOf']
	} else {
		['valueOf', 'toString']
	}
	for name in method_names {
		method := object.get(PropertyName.from_str(name))
		if method.is_function() {
			result := call(mut vm, method, Value.from_object(object), []Value{})!
			if !result.is_object() { return result }
		}
	}
	return vm.throw_error_type(.type_error, .convert, 'object', if preferred_type == .string {
		'string'
	} else {
		'number'
	})
}

// Runtime/Value.cpp::ToPropertyKey.
pub fn (value Value) to_property_key(mut vm VM) !PropertyName {
	key := value.to_primitive_with_hint(mut vm, .string)!
	if key.is_symbol() { return PropertyName.from_symbol(key.as_symbol()) }
	text := key.to_primitive_string(mut vm)!
	return PropertyName.from_utf16(text.utf16)
}
