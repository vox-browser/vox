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
	next int
}

@[heap]
pub struct KeyedCollection {
pub:
	object &Object
	is_map bool
mut:
	entries []KeyedCollectionEntry
	// Heads and links are entry indices plus one. Zero ends the chain.
	buckets map[u64]int
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

fn keyed_collection_hash(value Value) u64 {
	return match value.tag {
		.int32, .double {
			if value.number == 0 {
				u64(0)
			} else if math.is_nan(value.number) {
				u64(0x7ff8000000000000)
			} else {
				math.f64_bits(value.number)
			}
		}
		.string { binding_lookup_hash(value.as_string().utf16) }
		.bigint {
			magnitude, sign := value.as_bigint().big_integer.bytes()
			mut hash := u64(14695981039346656037) ^ u64(sign)
			for byte in magnitude {
				hash = (hash ^ u64(byte)) * 1099511628211
			}
			hash
		}
		.boolean { u64(value.tag) + if value.number == 0 { u64(0) } else { u64(1) } }
		.object, .symbol, .accessor { u64(value.cell) ^ u64(value.tag) }
		else { u64(value.tag) }
	}
}

fn (collection &KeyedCollection) find_link(key Value, head int) (int, int) {
	mut previous := 0
	mut link := head
	for link != 0 {
		entry := &collection.entries[link - 1]
		if same_value_zero(entry.key, key) { return link, previous }
		previous = link
		link = entry.next
	}
	return 0, 0
}

fn (collection &KeyedCollection) find(key Value) int {
	link, _ := collection.find_link(key, collection.buckets[keyed_collection_hash(key)])
	return link - 1
}

fn (mut collection KeyedCollection) put(key Value, value Value) {
	hash := keyed_collection_hash(key)
	head := collection.buckets[hash]
	link, _ := collection.find_link(key, head)
	if link != 0 {
		collection.entries[link - 1].value = value
		return
	}
	canonical_key := if key.is_number() && key.number == 0 { Value.from_i32(0) } else { key }
	collection.entries << KeyedCollectionEntry{key: canonical_key, value: value, next: head}
	collection.buckets[hash] = collection.entries.len
	collection.size++
}

fn (mut collection KeyedCollection) remove(key Value) bool {
	hash := keyed_collection_hash(key)
	link, previous := collection.find_link(key, collection.buckets[hash])
	if link == 0 { return false }
	next := collection.entries[link - 1].next
	if previous != 0 {
		collection.entries[previous - 1].next = next
	} else if next != 0 {
		collection.buckets[hash] = next
	} else {
		collection.buckets.delete(hash)
	}
	collection.entries[link - 1] = KeyedCollectionEntry{active: false}
	collection.size--
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
