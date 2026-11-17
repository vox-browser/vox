// SPDX-License-Identifier: BSD-2-Clause
module libjs

// EnumerateObjectProperties / CreateForInIterator. Snapshot each level's keys
// when reaching it. Breaking a loop must not run later Proxy traps or getters.
@[heap]
pub struct PropertyNameIterator {
pub:
	object &Object
	target &Object
mut:
	current ?&Object
	properties []PropertyName
	next_property int
	keys_loaded bool
	visited_names map[u64]PropertyName
	colliding_names map[string]bool
	visited_objects map[voidptr]bool
}

fn create_property_name_iterator(mut vm VM, value Value) !&Object {
	target := value.to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	mut object := Object.create(vm.realm(), none)
	object.class_name = 'PropertyNameIterator'
	object.property_name_iterator = &PropertyNameIterator{object: object, target: target, current: target}
	return object
}

fn (mut iterator PropertyNameIterator) next(mut vm VM) !IteratorStepValue {
	for {
		holder := iterator.current or { break }
		vm.consume_execution_budget()!
		if !iterator.keys_loaded {
			if iterator.visited_objects[voidptr(holder)] { iterator.current = none; break }
			iterator.visited_objects[voidptr(holder)] = true
			iterator.properties = holder.own_property_keys_checked(mut vm)!
			iterator.next_property = 0
			iterator.keys_loaded = true
		}
		for iterator.next_property < iterator.properties.len {
			vm.consume_execution_budget()!
			key := iterator.properties[iterator.next_property]
			iterator.next_property++
			if key.is_symbol() { continue }
			hash := property_lookup_hash(key)
			mut collision := ?string(none)
			if prior := iterator.visited_names[hash] {
				if prior.equals(key) { continue }
				// Use the exact encoding only for distinct names with the same hash.
				identity := property_name_identity(key)
				if iterator.colliding_names[identity] { continue }
				collision = identity
			}
			descriptor := holder.get_own_property_checked(mut vm, key)!.descriptor or { continue }
			if identity := collision {
				iterator.colliding_names[identity] = true
			} else {
				iterator.visited_names[hash] = key
			}
			if descriptor.enumerable or { false } { return IteratorStepValue{value: key.to_value(mut vm)} }
		}
		iterator.current = holder.get_prototype_of_checked(mut vm)!.prototype
		iterator.keys_loaded = false
		iterator.properties = []PropertyName{}
	}
	return IteratorStepValue{done: true, value: js_undefined()}
}
