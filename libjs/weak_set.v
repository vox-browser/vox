// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/WeakSet.{h,cpp}. Encoded identities and disappearing links share the
// WeakMap collector adapter; neither members nor the VM registry root cells.
@[heap]
pub struct WeakSetObject {
pub:
	object &Object
mut:
	values map[u64]WeakCellReference
	epoch u64
}

fn (mut collection WeakSetObject) remove_dead_cells() {
	collection.epoch = weak_cell_epoch()
	for encoded, reference in collection.values {
		if reference.cell() == unsafe { nil } { collection.values.delete(encoded) }
	}
}

fn (mut collection WeakSetObject) has(value Value) bool {
	if collection.epoch != weak_cell_epoch() { collection.remove_dead_cells() }
	if !can_be_held_weakly(value) { return false }
	reference := collection.values[~u64(value.cell)] or { return false }
	return reference.cell() == value.cell
}

fn (mut collection WeakSetObject) add(value Value) ! {
	if collection.has(value) { return }
	collection.values[~u64(value.cell)] = WeakCellReference.create(value.cell)!
}

fn (mut collection WeakSetObject) remove(value Value) bool {
	if !collection.has(value) { return false }
	collection.values.delete(~u64(value.cell))
	return true
}

fn create_weak_set(mut vm VM, prototype &Object) !&Object {
	mut object := Object.create(vm.realm(), prototype)
	collection := &WeakSetObject{ object: object, epoch: weak_cell_epoch() }
	object.weak_set = collection
	if vm.weak_collection_registry == none { vm.weak_collection_registry = &WeakCollectionRegistry{ epoch: weak_cell_epoch() } }
	mut registry := vm.weak_collection_registry or { return error('Missing weak container registry') }
	registry.sets << WeakCellReference.create(voidptr(collection))!
	return object
}

fn weak_set_receiver(mut vm VM) !&WeakSetObject {
	value := vm.this_value()
	if value.is_object() {
		if collection := value.as_object().weak_set { return collection }
	}
	return vm.throw_error_type(.type_error, .not_an_object_of_type, 'WeakSet')
}
