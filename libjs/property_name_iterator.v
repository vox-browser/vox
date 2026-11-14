// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Interpreter/SlowPaths.cpp::asm_get_object_property_iterator and
// Bytecode/PropertyNameIterator.cpp's uncached path. Capture names once, without
// calling value getters, and skip names deleted before the next step.
@[heap]
pub struct PropertyNameIterator {
pub:
	object     &Object
	target     &Object
	properties []PropertyName
mut:
	next_property int
}

fn create_property_name_iterator(mut vm VM, value Value) !&Object {
	target := value.to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	mut properties := []PropertyName{}
	mut visited_names := map[string]bool{}
	mut visited_objects := map[voidptr]bool{}
	mut current := ?&Object(target)
	for {
		object := current or { break }
		vm.consume_execution_budget()!
		if visited_objects[voidptr(object)] { break }
		visited_objects[voidptr(object)] = true
		for key in object.own_property_keys() {
			vm.consume_execution_budget()!
			if key.is_symbol() || visited_names[key.str()] { continue }
			descriptor := object.internal_get_own_property(key) or { continue }
			visited_names[key.str()] = true
			if descriptor.enumerable or { false } { properties << key }
		}
		current = object.internal_get_prototype_of()
	}
	mut object := Object.create(vm.realm(), none)
	object.class_name = 'PropertyNameIterator'
	object.property_name_iterator = &PropertyNameIterator{ object: object, target: target, properties: properties }
	return object
}

fn (mut iterator PropertyNameIterator) next(mut vm VM) !IteratorStepValue {
	for iterator.next_property < iterator.properties.len {
		vm.consume_execution_budget()!
		key := iterator.properties[iterator.next_property]
		iterator.next_property++
		if iterator.target.has_property(key) {
			return IteratorStepValue{ value: key.to_value(mut vm) }
		}
	}
	return IteratorStepValue{ done: true, value: js_undefined() }
}
