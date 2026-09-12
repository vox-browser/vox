// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IDBRecord.{h,cpp,idl}, Internal/Index.{h,cpp},
// Internal/ObjectStore.{h,cpp}, and Internal/KeyGenerator.h.
module indexeddb

pub const maximum_key_generator_value = u64(9_007_199_254_740_992)

pub struct ObjectStoreRecord {
pub:
	key   Key
	value Value
}

pub struct IndexRecord {
pub:
	key         Key
	primary_key Key
}

pub struct IDBRecord {
pub:
	key         Key
	primary_key Key
	value       Value
}

pub struct KeyGenerator {
pub mut:
	current_number u64 = 1
}

pub fn (mut generator KeyGenerator) generate() !Key {
	if generator.current_number > maximum_key_generator_value {
		return error('ConstraintError: key generator exhausted')
	}
	key := number_key(f64(generator.current_number))
	generator.current_number++
	return key
}

pub fn (mut generator KeyGenerator) possibly_update(key Key) {
	if key.kind != .number || key.number < 0 {
		return
	}
	mut bounded := key.number
	if bounded > f64(maximum_key_generator_value) {
		bounded = f64(maximum_key_generator_value)
	}
	next := u64(bounded) + 1
	if next > generator.current_number {
		generator.current_number = next
	}
}

@[heap]
pub struct IndexData {
pub mut:
	name          string
	key_path      KeyPath
	unique        bool
	multi_entry   bool
	records       []IndexRecord
	deleted       bool
	store_name    string
	object_store_ ?&ObjectStoreData
}

@[heap]
pub struct ObjectStoreData {
pub mut:
	name           string
	key_path       ?KeyPath
	auto_increment bool
	key_generator  KeyGenerator
	records        []ObjectStoreRecord
	indexes        map[string]&IndexData
	deleted        bool
	database_      ?&DatabaseData
	mutation_log_  ?&MutationLog
}

fn clone_key_path(path KeyPath) KeyPath {
	return match path {
		string { path }
		[]string { path.clone() }
	}
}

fn sort_object_store_records(mut records []ObjectStoreRecord) {
	records.sort_with_compare(fn (a &ObjectStoreRecord, b &ObjectStoreRecord) int {
		return compare_two_keys(a.key, b.key) or { 0 }
	})
}

fn sort_index_records(mut records []IndexRecord) {
	records.sort_with_compare(fn (a &IndexRecord, b &IndexRecord) int {
		return compare_index_records(*a, *b)
	})
}

pub fn compare_index_records(a IndexRecord, b IndexRecord) int {
	key_comparison := compare_two_keys(a.key, b.key) or { return 0 }
	if key_comparison != 0 {
		return key_comparison
	}
	return compare_two_keys(a.primary_key, b.primary_key) or { 0 }
}

fn find_record(records []ObjectStoreRecord, key Key) int {
	mut low := 0
	mut high := records.len
	for low < high {
		middle := low + (high - low) / 2
		comparison := compare_two_keys(records[middle].key, key) or { return -1 }
		if comparison < 0 {
			low = middle + 1
		} else {
			high = middle
		}
	}
	if low < records.len && keys_equal(records[low].key, key) {
		return low
	}
	return -1
}

fn index_keys_for_value(index &IndexData, value Value) []Key {
	if index.multi_entry {
		match index.key_path {
			string {
				found := evaluate_string_key_path(value, index.key_path) or { return [] }
				if found.kind == .array {
					mut result := []Key{}
					for item in found.items {
						candidate := value_to_key(item)
						if candidate.is_valid() && !result.any(keys_equal(it, candidate)) {
							result << candidate
						}
					}
					return result
				}
				key := value_to_key(found)
				if key.is_valid() {
					return [key]
				}
				return []
			}
			[]string {}
		}
	}
	key := evaluate_key_path(value, index.key_path) or { return [] }
	return [key]
}

fn rebuild_index(store &ObjectStoreData, mut index IndexData) ! {
	index.records.clear()
	for record in store.records {
		for key in index_keys_for_value(index, record.value) {
			if index.unique && index.records.any(keys_equal(it.key, key)) {
				return error('ConstraintError: duplicate index key')
			}
			index.records << IndexRecord{
				key: key.clone()
				primary_key: record.key.clone()
			}
		}
	}
	sort_index_records(mut index.records)
}
