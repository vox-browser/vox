module libjs

// Runtime/Object.h::PrivateElement and Object.cpp::Private{ElementFind,FieldAdd,
// MethodOrAccessorAdd,Get,Set}. V-owned records retain values independently of
// ordinary property storage, as [[PrivateElements]] does upstream.
pub enum PrivateElementKind {
	field
	method
	accessor
}

pub struct PrivateElement {
pub:
	key  PrivateName
	kind PrivateElementKind
pub mut:
	value Value
}

fn (object &Object) private_element_index(name PrivateName) int {
	for index, element in object.private_elements {
		if element.key == name { return index }
	}
	return -1
}

pub fn (object &Object) private_element_find(name PrivateName) ?PrivateElement {
	index := object.private_element_index(name)
	if index < 0 { return none }
	return object.private_elements[index]
}

pub fn (mut object Object) private_field_add(mut vm VM, name PrivateName, value Value) ! {
	vm.host_ensure_can_add_private_element(mut object)!
	if object.private_element_index(name) >= 0 {
		return vm.throw_error_type(.type_error, .private_field_already_declared, name.description.str())
	}
	object.private_elements << PrivateElement{ key: name, kind: .field, value: value }
}

pub fn (mut object Object) private_method_or_accessor_add(mut vm VM, element PrivateElement) ! {
	assert element.kind in [.method, .accessor]
	vm.host_ensure_can_add_private_element(mut object)!
	if object.private_element_index(element.key) >= 0 {
		return vm.throw_error_type(.type_error, .private_field_already_declared, element.key.description.str())
	}
	object.private_elements << element
}

pub fn (object &Object) private_get(mut vm VM, name PrivateName) !Value {
	entry := object.private_element_find(name) or {
		return vm.throw_error_type(.type_error, .private_field_does_not_exist_on_object, name.description.str())
	}
	if entry.kind != .accessor { return entry.value }
	getter := entry.value.as_accessor().getter or {
		return vm.throw_error_type(.type_error, .private_field_get_accessor_without_getter, name.description.str())
	}
	return call(mut vm, Value.from_object(getter), Value.from_object(object), [])
}

pub fn (mut object Object) private_set(mut vm VM, name PrivateName, value Value) ! {
	index := object.private_element_index(name)
	if index < 0 {
		return vm.throw_error_type(.type_error, .private_field_does_not_exist_on_object, name.description.str())
	}
	entry := object.private_elements[index]
	if entry.kind == .field {
		object.private_elements[index].value = value
		return
	}
	if entry.kind == .method {
		return vm.throw_error_type(.type_error, .private_field_set_method, name.description.str())
	}
	assert entry.kind == .accessor
	setter := entry.value.as_accessor().setter or {
		return vm.throw_error_type(.type_error, .private_field_set_accessor_without_setter, name.description.str())
	}
	call(mut vm, Value.from_object(setter), Value.from_object(&object), [value])!
}
