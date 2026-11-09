// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IDBIndex.{h,cpp,idl} and index retrieval algorithms from
// Internal/Algorithms.{h,cpp}.
module indexeddb

pub struct IDBIndex {
pub mut:
	transaction          &IDBTransaction
	store_name           string
	name_                string
	store_               ?&ObjectStoreData
	index_               ?&IndexData
	object_store_handle_ IDBObjectStore
mut:
	operation_request_ ?&IDBRequest
}

fn (index &IDBIndex) load() !(&ObjectStoreData, &IndexData) {
	if store := index.store_ {
		if store.deleted {
			return error('InvalidStateError: object store was deleted')
		}
		if data := index.index_ {
			if data.deleted {
				return error('InvalidStateError: index was deleted')
			}
			return store, data
		}
	}
	if index.store_name !in index.transaction.database.data.stores {
		return error('InvalidStateError: object store was deleted')
	}
	store := index.transaction.database.data.stores[index.store_name] or {
		return error('InvalidStateError: object store was deleted')
	}
	if index.name_ !in store.indexes {
		return error('InvalidStateError: index was deleted')
	}
	return store, store.indexes[index.name_] or { return error('InvalidStateError: index was deleted') }
}

pub fn (index &IDBIndex) name() string {
	if index.transaction.state == .finished { return index.name_ }
	if data := index.index_ {
		return data.name
	}
	return index.name_
}

pub fn (index &IDBIndex) unique() bool {
	if data := index.index_ { return data.unique }
	_, data := index.load() or { return false }
	return data.unique
}

pub fn (index &IDBIndex) multi_entry() bool {
	if data := index.index_ { return data.multi_entry }
	_, data := index.load() or { return false }
	return data.multi_entry
}

pub fn (index &IDBIndex) key_path() !KeyPath {
	// Schema metadata belongs to the retained index record, including after
	// deletion. Only operations on its records require a live schema handle.
	if data := index.index_ { return clone_key_path(data.key_path) }
	_, data := index.load()!
	return clone_key_path(data.key_path)
}

pub fn (index &IDBIndex) key_path_value() !Value {
	return convert_a_key_path_to_a_value(index.key_path()!)
}

pub fn IDBIndex.object_store_handle_offset() uint {
	return uint(__offsetof(IDBIndex, object_store_handle_))
}

pub fn (mut index IDBIndex) rename(name string) ! {
	index.transaction.require_versionchange_active()!
	mut store, mut data := index.load()!
	if name != index.name_ && name in store.indexes {
		return error('ConstraintError: index already exists')
	}
	if mut log := store.mutation_log_ {
		log.note_index_renamed(data, data.name)
	}
	store.indexes.delete(index.name_)
	data.name = name
	store.indexes[name] = data
	index.name_ = name
}

fn (mut index IDBIndex) new_request() &IDBRequest {
	if request := index.operation_request_ { return request }
	mut request := IDBRequest.create_for_global_scope(index.relevant_global_object(), index.name_)
	request.transaction_ = index.transaction
	index.transaction.request_list_.append(request)
	return request
}

fn (index &IDBIndex) entries(range IDBKeyRange, direction IDBCursorDirection, include_values bool) ![]CursorEntry {
	store, data := index.load()!
	mut entries := []CursorEntry{}
	if direction in [.prev, .prevunique] {
		for i := data.records.len - 1; i >= 0; i-- {
			record := data.records[i]
			if range.includes(record.key)! {
				position := if include_values {
					find_record(store.records, record.primary_key)
				} else {
					0
				}
				if position >= 0 {
					entry := CursorEntry{
						key: record.key.clone()
						primary_key: record.primary_key.clone()
						value: if include_values {
							store.records[position].value.clone()
						} else {
							undefined_value()
						}
					}
					if direction == .prevunique && entries.len > 0 && keys_equal(entries[entries.len - 1].key, record.key) {
						// The upstream prevunique algorithm retains the first
						// (lowest-primary-key) record in each equal-key run.
						entries[entries.len - 1] = entry
						continue
					}
					entries << entry
				}
			}
		}
	} else {
		for record in data.records {
			if range.includes(record.key)! {
				position := if include_values {
					find_record(store.records, record.primary_key)
				} else {
					0
				}
				if position >= 0 {
					if direction == .nextunique && entries.len > 0 && keys_equal(entries[entries.len - 1].key, record.key) {
						continue
					}
					entries << CursorEntry{
						key: record.key.clone()
						primary_key: record.primary_key.clone()
						value: if include_values {
							store.records[position].value.clone()
						} else {
							undefined_value()
						}
					}
				}
			}
		}
	}
	return entries
}

pub fn (mut index IDBIndex) get(range IDBKeyRange) !&IDBRequest {
	if index.operation_request_ == none { index.transaction.require_active()! }
	store, data := index.load()!
	mut request := index.new_request()
	if record := data.first_in_range(range) {
		request.value = (data.referenced_value(record, store) or { undefined_value() }).clone()
		request.succeed(.value)
	} else {
		request.succeed(.undefined)
	}
	return request
}

pub fn (mut index IDBIndex) get_key(range IDBKeyRange) !&IDBRequest {
	if index.operation_request_ == none { index.transaction.require_active()! }
	_, data := index.load()!
	mut request := index.new_request()
	if record := data.first_in_range(range) {
		request.key = record.primary_key.clone()
		request.succeed(.key)
	} else {
		request.succeed(.undefined)
	}
	return request
}

pub fn (mut index IDBIndex) get_all(options IDBGetAllOptions) !&IDBRequest {
	if index.operation_request_ == none { index.transaction.require_active()! }
	range := options.range or { IDBKeyRange.unbounded() }
	mut entries := index.entries(range, options.direction, true)!
	if count := options.count {
		if count > 0 && entries.len > int(count) { entries.trim(int(count)) }
	}
	mut request := index.new_request()
	request.values = entries.map(it.value.clone())
	request.succeed(.values)
	return request
}

pub fn (mut index IDBIndex) get_all_keys(options IDBGetAllOptions) !&IDBRequest {
	if index.operation_request_ == none { index.transaction.require_active()! }
	range := options.range or { IDBKeyRange.unbounded() }
	mut entries := index.entries(range, options.direction, false)!
	if count := options.count {
		if count > 0 && entries.len > int(count) { entries.trim(int(count)) }
	}
	mut request := index.new_request()
	request.keys = entries.map(it.primary_key.clone())
	request.succeed(.keys)
	return request
}

pub fn (mut index IDBIndex) get_all_records(options IDBGetAllOptions) !&IDBRequest {
	if index.operation_request_ == none { index.transaction.require_active()! }
	range := options.range or { IDBKeyRange.unbounded() }
	mut entries := index.entries(range, options.direction, true)!
	if count := options.count {
		if count > 0 && entries.len > int(count) { entries.trim(int(count)) }
	}
	mut request := index.new_request()
	request.records = entries.map(IDBRecord{
		key: it.key.clone()
		primary_key: it.primary_key.clone()
		value: it.value.clone()
	})
	request.succeed(.records)
	return request
}

pub fn (mut index IDBIndex) count(range ?IDBKeyRange) !&IDBRequest {
	if index.operation_request_ == none { index.transaction.require_active()! }
	actual := range or { IDBKeyRange.unbounded() }
	_, data := index.load()!
	mut request := index.new_request()
	request.count = data.count_records_in_range(actual)
	request.succeed(.count)
	return request
}

pub fn (mut index IDBIndex) open_cursor(range ?IDBKeyRange, direction IDBCursorDirection, keys_only bool) !&IDBRequest {
	index.transaction.require_active()!
	store, data := index.load()!
	actual := range or { IDBKeyRange.unbounded() }
	mut request := index.new_request()
	mut cursor := IDBCursor.create(index.transaction, store, data, direction, actual, !keys_only, request)
	if !cursor.iterate(none, none, 1)! {
		request.succeed(.undefined)
		return request
	}
	request.cursor = cursor
	request.succeed(.cursor)
	return request
}
