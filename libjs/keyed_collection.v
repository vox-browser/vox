// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math

// Runtime/Set.cpp and Map.cpp. Deleted entries retain their positions so a
// suspended iterator observes later insertions, including after clear(). The
// hash index is private: equality never invokes user conversion hooks.
struct KeyedCollectionEntry {
mut:
	key Value
	value Value
	active bool = true
}

@[heap]
pub struct KeyedCollection {
pub:
	object &Object
	is_map bool
mut:
	entries []KeyedCollectionEntry
	buckets map[string][]int
	size u64
}

@[heap]
pub struct KeyedCollectionIterator {
pub:
	object &Object
	collection &KeyedCollection
	kind PropertyKind
mut:
	index int
	done bool
}

fn keyed_collection_hash(value Value) string {
	if value.is_number() {
		if value.number == 0 { return 'n0' }
		if math.is_nan(value.number) { return 'nan' }
		return 'n${math.f64_bits(value.number)}'
	}
	return match value.tag {
		.string { 's' + value.as_string().str() }
		.bigint { 'b' + value.as_bigint().big_integer.str() }
		.object, .symbol { '${value.tag}:${u64(value.cell)}' }
		else { '${value.tag}:${value.number}' }
	}
}

fn (collection &KeyedCollection) find(key Value) int {
	for index in collection.buckets[keyed_collection_hash(key)] {
		entry := collection.entries[index]
		if entry.active && same_value_zero(entry.key, key) { return index }
	}
	return -1
}

fn (mut collection KeyedCollection) put(key Value, value Value) {
	index := collection.find(key)
	if index >= 0 {
		collection.entries[index].value = value
		return
	}
	canonical_key := if key.is_number() && key.number == 0 { Value.from_i32(0) } else { key }
	hash := keyed_collection_hash(canonical_key)
	mut bucket := collection.buckets[hash].clone()
	bucket << collection.entries.len
	collection.buckets[hash] = bucket
	collection.entries << KeyedCollectionEntry{ key: canonical_key, value: value }
	collection.size++
}

fn (mut collection KeyedCollection) remove(key Value) bool {
	index := collection.find(key)
	if index < 0 { return false }
	collection.entries[index] = KeyedCollectionEntry{ active: false }
	collection.size--
	hash := keyed_collection_hash(key)
	remaining := collection.buckets[hash].filter(it != index)
	if remaining.len == 0 { collection.buckets.delete(hash) } else { collection.buckets[hash] = remaining }
	return true
}

fn (mut collection KeyedCollection) clear() {
	for index in 0 .. collection.entries.len { collection.entries[index] = KeyedCollectionEntry{ active: false } }
	collection.buckets.clear()
	collection.size = 0
}

fn keyed_collection_receiver(mut vm VM, is_map bool) !&KeyedCollection {
	value := vm.this_value()
	if value.is_object() {
		if collection := value.as_object().keyed_collection {
			if collection.is_map == is_map { return collection }
		}
	}
	return vm.throw_error(.type_error, 'Incompatible keyed collection receiver')
}

fn keyed_collection_for_each(mut vm VM, is_map bool) !Value {
	collection := keyed_collection_receiver(mut vm, is_map)!
	callback, this_argument := vm.argument(0), vm.argument(1)
	if !callback.is_function() { return vm.throw_error_type(.type_error, .not_a_function, callback.str()) }
	mut index := 0
	for index < collection.entries.len {
		vm.consume_execution_budget()!
		entry := collection.entries[index]
		index++
		if !entry.active { continue }
		call(mut vm, callback, this_argument, [if is_map { entry.value } else { entry.key }, entry.key, Value.from_object(collection.object)])!
	}
	return js_undefined()
}

fn create_keyed_iterator(mut vm VM, is_map bool, kind PropertyKind, prototype &Object) !Value {
	collection := keyed_collection_receiver(mut vm, is_map)!
	mut object := Object.create(vm.realm(), prototype)
	object.keyed_iterator = &KeyedCollectionIterator{ object: object, collection: collection, kind: kind }
	return Value.from_object(object)
}

fn keyed_iterator_next(mut vm VM, is_map bool) !Value {
	value := vm.this_value()
	if !value.is_object() { return vm.throw_error(.type_error, 'Incompatible collection iterator receiver') }
	mut iterator := value.as_object().keyed_iterator or { return vm.throw_error(.type_error, 'Incompatible collection iterator receiver') }
	if iterator.collection.is_map != is_map { return vm.throw_error(.type_error, 'Incompatible collection iterator receiver') }
	if !iterator.done {
		for iterator.index < iterator.collection.entries.len {
			vm.consume_execution_budget()!
			entry := iterator.collection.entries[iterator.index]
			iterator.index++
			if !entry.active { continue }
			mut yielded := if iterator.kind == .key || !is_map { entry.key } else { entry.value }
			if iterator.kind == .key_and_value {
				yielded = Value.from_object(ArrayObject.create_from(mut vm, vm.realm(), [entry.key, if is_map { entry.value } else { entry.key }], vm.realm().array_prototype_record())!.object)
			}
			return Value.from_object(create_iterator_result_object(vm.realm(), yielded, false, vm.realm().object_prototype))
		}
		iterator.done = true
	}
	return Value.from_object(create_iterator_result_object(vm.realm(), js_undefined(), true, vm.realm().object_prototype))
}
