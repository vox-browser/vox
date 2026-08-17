// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IDBIndex.{h,cpp,idl} and index retrieval algorithms from
// Internal/Algorithms.{h,cpp}.
module indexeddb

pub struct IDBIndex {
pub mut:
	transaction &IDBTransaction
	store_name  string
	name_       string
}

fn (index &IDBIndex) load() !(ObjectStoreData, IndexData) {
	if index.store_name !in index.transaction.database.data.stores {
		return error('InvalidStateError: object store was deleted')
	}
	store := index.transaction.database.data.stores[index.store_name].clone()
	if index.name_ !in store.indexes {
		return error('InvalidStateError: index was deleted')
	}
	return store, store.indexes[index.name_].clone()
}

pub fn (index &IDBIndex) name() string {
	return index.name_
}

pub fn (index &IDBIndex) unique() bool {
	_, data := index.load() or { return false }
	return data.unique
}

pub fn (index &IDBIndex) multi_entry() bool {
	_, data := index.load() or { return false }
	return data.multi_entry
}

pub fn (index &IDBIndex) key_path() !KeyPath {
	_, data := index.load()!
	return clone_key_path(data.key_path)
}

pub fn (mut index IDBIndex) rename(name string) ! {
	index.transaction.require_versionchange_active()!
	mut store, mut data := index.load()!
	if name != index.name_ && name in store.indexes {
		return error('ConstraintError: index already exists')
	}
	store.indexes.delete(index.name_)
	data.name = name
	store.indexes[name] = data
	index.transaction.database.data.stores[index.store_name] = store
	index.name_ = name
}

fn (mut index IDBIndex) new_request() &IDBRequest {
	mut request := IDBRequest.create(index.name_)
	index.transaction.requests << request
	return request
}

fn (index &IDBIndex) entries(range IDBKeyRange, direction IDBCursorDirection) ![]CursorEntry {
	store, data := index.load()!
	mut entries := []CursorEntry{}
	if direction in [.prev, .prevunique] {
		for i := data.records.len - 1; i >= 0; i-- {
			record := data.records[i]
			if range.includes(record.key)! {
				position := find_record(store.records, record.primary_key)
				if position >= 0 {
					if direction == .prevunique && entries.any(keys_equal(it.key, record.key)) { continue
					 }
					entries << CursorEntry{
						key:         record.key.clone()
						primary_key: record.primary_key.clone()
						value:       store.records[position].value.clone()
					}
				}
			}
		}
	} else {
		for record in data.records {
			if range.includes(record.key)! {
				position := find_record(store.records, record.primary_key)
				if position >= 0 {
					if direction == .nextunique && entries.any(keys_equal(it.key, record.key)) { continue
					 }
					entries << CursorEntry{
						key:         record.key.clone()
						primary_key: record.primary_key.clone()
						value:       store.records[position].value.clone()
					}
				}
			}
		}
	}
	return entries
}

pub fn (mut index IDBIndex) get(range IDBKeyRange) !&IDBRequest {
	index.transaction.require_active()!
	entries := index.entries(range, .next)!
	mut request := index.new_request()
	if entries.len > 0 {
		request.value = entries[0].value.clone()
		request.succeed(.value)
	} else {
		request.succeed(.undefined)
	}
	return request
}

pub fn (mut index IDBIndex) get_key(range IDBKeyRange) !&IDBRequest {
	index.transaction.require_active()!
	entries := index.entries(range, .next)!
	mut request := index.new_request()
	if entries.len > 0 {
		request.key = entries[0].primary_key.clone()
		request.succeed(.key)
	} else {
		request.succeed(.undefined)
	}
	return request
}

pub fn (mut index IDBIndex) get_all(options IDBGetAllOptions) !&IDBRequest {
	index.transaction.require_active()!
	range := options.range or { IDBKeyRange.unbounded() }
	mut entries := index.entries(range, options.direction)!
	if count := options.count {
		if entries.len > int(count) { entries.trim(int(count)) }
	}
	mut request := index.new_request()
	request.values = entries.map(it.value.clone())
	request.succeed(.values)
	return request
}

pub fn (mut index IDBIndex) get_all_keys(options IDBGetAllOptions) !&IDBRequest {
	index.transaction.require_active()!
	range := options.range or { IDBKeyRange.unbounded() }
	mut entries := index.entries(range, options.direction)!
	if count := options.count {
		if entries.len > int(count) { entries.trim(int(count)) }
	}
	mut request := index.new_request()
	request.keys = entries.map(it.primary_key.clone())
	request.succeed(.keys)
	return request
}

pub fn (mut index IDBIndex) get_all_records(options IDBGetAllOptions) !&IDBRequest {
	index.transaction.require_active()!
	range := options.range or { IDBKeyRange.unbounded() }
	mut entries := index.entries(range, options.direction)!
	if count := options.count {
		if entries.len > int(count) { entries.trim(int(count)) }
	}
	mut request := index.new_request()
	request.records = entries.map(IDBRecord{
		key:         it.key.clone()
		primary_key: it.primary_key.clone()
		value:       it.value.clone()
	})
	request.succeed(.records)
	return request
}

pub fn (mut index IDBIndex) count(range ?IDBKeyRange) !&IDBRequest {
	index.transaction.require_active()!
	actual := range or { IDBKeyRange.unbounded() }
	entries := index.entries(actual, .next)!
	mut request := index.new_request()
	request.count = u64(entries.len)
	request.succeed(.count)
	return request
}

pub fn (mut index IDBIndex) open_cursor(range ?IDBKeyRange, direction IDBCursorDirection, keys_only bool) !&IDBRequest {
	index.transaction.require_active()!
	actual := range or { IDBKeyRange.unbounded() }
	entries := index.entries(actual, direction)!
	mut request := index.new_request()
	if entries.len == 0 {
		request.succeed(.undefined)
		return request
	}
	mut cursor := IDBCursor.create(index.transaction, index.store_name, index.name_, direction,
		entries, !keys_only, request)
	request.cursor = cursor
	request.succeed(.cursor)
	return request
}
