// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/WeakMap.{h,cpp}. Keys are weak cells, values remain strong until a
// dead-key sweep. Boehm and non-collecting builds share the same JS operations.
struct WeakMapEntry {
	key WeakCellReference
	value Value
}

@[heap]
pub struct WeakMapObject {
pub:
	object &Object
mut:
	entries map[u64]WeakMapEntry
	epoch u64
}

pub fn can_be_held_weakly(value Value) bool {
	return value.is_object() || (value.is_symbol() && !value.as_symbol().is_global())
}

fn (mut collection WeakMapObject) remove_dead_cells() {
	collection.epoch = weak_cell_epoch()
	for encoded, entry in collection.entries {
		if entry.key.cell() == unsafe { nil } { collection.entries.delete(encoded) }
	}
}

fn (mut collection WeakMapObject) prepare() {
	if collection.epoch != weak_cell_epoch() { collection.remove_dead_cells() }
}

fn (mut collection WeakMapObject) get(key Value) ?Value {
	collection.prepare()
	if !can_be_held_weakly(key) { return none }
	entry := collection.entries[~u64(key.cell)] or { return none }
	if entry.key.cell() != key.cell { return none }
	return entry.value
}

fn (mut collection WeakMapObject) put(key Value, value Value) ! {
	collection.prepare()
	encoded := ~u64(key.cell)
	if entry := collection.entries[encoded] {
		if entry.key.cell() == key.cell {
			collection.entries[encoded] = WeakMapEntry{ key: entry.key, value: value }
			return
		}
	}
	collection.entries[encoded] = WeakMapEntry{ key: WeakCellReference.create(key.cell)!, value: value }
}

fn (mut collection WeakMapObject) remove(key Value) bool {
	if _ := collection.get(key) {
		collection.entries.delete(~u64(key.cell))
		return true
	}
	return false
}

fn create_weak_map(mut vm VM, prototype &Object) !&Object {
	mut object := Object.create(vm.realm(), prototype)
	collection := &WeakMapObject{ object: object, epoch: weak_cell_epoch() }
	object.weak_map = collection
	if vm.weak_collection_registry == none { vm.weak_collection_registry = &WeakCollectionRegistry{ epoch: weak_cell_epoch() } }
	mut registry := vm.weak_collection_registry or { return error('Missing weak container registry') }
	registry.collections << WeakCellReference.create(voidptr(collection))!
	return object
}

fn weak_map_receiver(mut vm VM) !&WeakMapObject {
	value := vm.this_value()
	if value.is_object() {
		if collection := value.as_object().weak_map { return collection }
	}
	return vm.throw_error_type(.type_error, .not_an_object_of_type, 'WeakMap')
}
