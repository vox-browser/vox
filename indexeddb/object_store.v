// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IDBObjectStore.{h,cpp,idl} and the object-store request
// algorithms in Internal/Algorithms.{h,cpp}.
module indexeddb

pub struct IDBGetAllOptions {
pub:
	range     ?IDBKeyRange
	count     ?u32
	direction IDBCursorDirection = .next
}

pub struct IDBIndexParameters {
pub:
	unique      bool
	multi_entry bool
}

pub struct IDBObjectStore {
pub mut:
	transaction &IDBTransaction
	name_       string
}

fn (store &IDBObjectStore) load() !ObjectStoreData {
	if store.name_ !in store.transaction.database.data.stores {
		return error('InvalidStateError: object store was deleted')
	}
	data := store.transaction.database.data.stores[store.name_] or {
		return error('InvalidStateError: object store was deleted')
	}
	return data.clone()
}

fn (mut store IDBObjectStore) save(data ObjectStoreData) {
	store.transaction.database.data.stores[store.name_] = data
}

pub fn (store &IDBObjectStore) name() string {
	return store.name_
}

pub fn (store &IDBObjectStore) key_path() ?KeyPath {
	data := store.load() or { return none }
	return data.key_path
}

pub fn (store &IDBObjectStore) auto_increment() bool {
	return store.load() or { return false }.auto_increment
}

pub fn (store &IDBObjectStore) index_names() []string {
	data := store.load() or { return [] }
	mut names := data.indexes.keys()
	sort_name_list(mut names)
	return names
}

pub fn (mut store IDBObjectStore) rename(name string) ! {
	store.transaction.require_versionchange_active()!
	mut data := store.load()!
	if name != store.name_ && name in store.transaction.database.data.stores {
		return error('ConstraintError: object store already exists')
	}
	store.transaction.database.data.stores.delete(store.name_)
	data.name = name
	store.transaction.database.data.stores[name] = data
	store.transaction.scope_names = store.transaction.scope_names.map(if it == store.name_ {
		name
	} else {
		it
	})
	sort_name_list(mut store.transaction.scope_names)
	store.name_ = name
}

pub fn (mut store IDBObjectStore) add(value Value, key ?Key) !&IDBRequest {
	return store.store_record(value, key, true)
}

pub fn (mut store IDBObjectStore) put(value Value, key ?Key) !&IDBRequest {
	return store.store_record(value, key, false)
}

fn (mut store IDBObjectStore) store_record(input Value, supplied_key ?Key, no_overwrite bool) !&IDBRequest {
	store.transaction.require_writable()!
	mut data := store.load()!
	mut value := input.clone()
	mut key := invalid_key()
	if path := data.key_path {
		if supplied_key != none {
			return error('DataError: an explicit key is forbidden for inline keys')
		}
		key = evaluate_key_path(value, path) or { invalid_key() }
		if !key.is_valid() {
			if !data.auto_increment {
				return error('DataError: inline key path did not yield a key')
			}
			match path {
				string {
					key = data.key_generator.generate()!
					value = inject_key(value, path, key)!
				}
				[]string {
					return error('DataError: generated key cannot populate a sequence key path')
				}
			}
		} else if data.auto_increment {
			data.key_generator.possibly_update(key)
		}
	} else if provided := supplied_key {
		key = provided.clone()
		ensure_valid_key(key)!
		if data.auto_increment {
			data.key_generator.possibly_update(key)
		}
	} else if data.auto_increment {
		key = data.key_generator.generate()!
	} else {
		return error('DataError: out-of-line object store requires a key')
	}
	position := find_record(data.records, key)
	if no_overwrite && position >= 0 {
		return completed_error_request(mut store, 'ConstraintError: key already exists')
	}
	if position >= 0 {
		data.records[position] = ObjectStoreRecord{
			key:   key.clone()
			value: value.clone()
		}
	} else {
		data.records << ObjectStoreRecord{
			key:   key.clone()
			value: value.clone()
		}
		sort_object_store_records(mut data.records)
	}
	rebuild_all_indexes(mut data) or {
		return completed_error_request(mut store,
			'ConstraintError: unique index key already exists')
	}
	store.save(data)
	mut request := store.new_request()
	request.key = key.clone()
	request.succeed(.key)
	return request
}

fn completed_error_request(mut store IDBObjectStore, message string) &IDBRequest {
	mut request := store.new_request()
	request.fail(message)
	return request
}

fn (mut store IDBObjectStore) new_request() &IDBRequest {
	mut request := IDBRequest.create(store.name_)
	store.transaction.requests << request
	return request
}

pub fn (mut store IDBObjectStore) get(range IDBKeyRange) !&IDBRequest {
	store.transaction.require_active()!
	data := store.load()!
	mut request := store.new_request()
	for record in data.records {
		if range.includes(record.key)! {
			request.value = record.value.clone()
			request.succeed(.value)
			return request
		}
	}
	request.value = undefined_value()
	request.succeed(.undefined)
	return request
}

pub fn (mut store IDBObjectStore) get_key(range IDBKeyRange) !&IDBRequest {
	store.transaction.require_active()!
	data := store.load()!
	mut request := store.new_request()
	for record in data.records {
		if range.includes(record.key)! {
			request.key = record.key.clone()
			request.succeed(.key)
			return request
		}
	}
	request.succeed(.undefined)
	return request
}

pub fn (mut store IDBObjectStore) get_all(options IDBGetAllOptions) !&IDBRequest {
	store.transaction.require_active()!
	data := store.load()!
	range := options.range or { IDBKeyRange.unbounded() }
	mut records := records_in_range(data.records, range, options.direction)!
	if count := options.count {
		if records.len > int(count) { records.trim(int(count)) }
	}
	mut request := store.new_request()
	request.values = records.map(it.value.clone())
	request.succeed(.values)
	return request
}

pub fn (mut store IDBObjectStore) get_all_keys(options IDBGetAllOptions) !&IDBRequest {
	store.transaction.require_active()!
	data := store.load()!
	range := options.range or { IDBKeyRange.unbounded() }
	mut records := records_in_range(data.records, range, options.direction)!
	if count := options.count {
		if records.len > int(count) { records.trim(int(count)) }
	}
	mut request := store.new_request()
	request.keys = records.map(it.key.clone())
	request.succeed(.keys)
	return request
}

pub fn (mut store IDBObjectStore) get_all_records(options IDBGetAllOptions) !&IDBRequest {
	store.transaction.require_active()!
	data := store.load()!
	range := options.range or { IDBKeyRange.unbounded() }
	mut records := records_in_range(data.records, range, options.direction)!
	if count := options.count {
		if records.len > int(count) { records.trim(int(count)) }
	}
	mut request := store.new_request()
	request.records = records.map(IDBRecord{
		key:         it.key.clone()
		primary_key: it.key.clone()
		value:       it.value.clone()
	})
	request.succeed(.records)
	return request
}

pub fn (mut store IDBObjectStore) count(range ?IDBKeyRange) !&IDBRequest {
	store.transaction.require_active()!
	data := store.load()!
	actual := range or { IDBKeyRange.unbounded() }
	mut request := store.new_request()
	for record in data.records {
		if actual.includes(record.key)! { request.count++ }
	}
	request.succeed(.count)
	return request
}

pub fn (mut store IDBObjectStore) delete(range IDBKeyRange) !&IDBRequest {
	store.transaction.require_writable()!
	mut data := store.load()!
	data.records = records_outside_range(data.records, range)!
	rebuild_all_indexes(mut data)!
	store.save(data)
	mut request := store.new_request()
	request.succeed(.undefined)
	return request
}

pub fn (mut store IDBObjectStore) clear() !&IDBRequest {
	store.transaction.require_writable()!
	mut data := store.load()!
	data.records.clear()
	for name, original in data.indexes {
		mut index := original
		index.records.clear()
		data.indexes[name] = index
	}
	store.save(data)
	mut request := store.new_request()
	request.succeed(.undefined)
	return request
}

fn records_in_range(records []ObjectStoreRecord, range IDBKeyRange, direction IDBCursorDirection) ![]ObjectStoreRecord {
	mut result := []ObjectStoreRecord{}
	if direction in [.prev, .prevunique] {
		for i := records.len - 1; i >= 0; i-- {
			if range.includes(records[i].key)! { result << records[i] }
		}
	} else {
		for record in records {
			if range.includes(record.key)! { result << record }
		}
	}
	return result
}

fn records_outside_range(records []ObjectStoreRecord, range IDBKeyRange) ![]ObjectStoreRecord {
	mut result := []ObjectStoreRecord{}
	for record in records {
		if !range.includes(record.key)! { result << record }
	}
	return result
}

pub fn (mut store IDBObjectStore) create_index(name string, key_path KeyPath, parameters IDBIndexParameters) !IDBIndex {
	store.transaction.require_versionchange_active()!
	mut data := store.load()!
	if name in data.indexes {
		return error('ConstraintError: index already exists')
	}
	if !is_valid_key_path(key_path) {
		return error('SyntaxError: invalid index key path')
	}
	if parameters.multi_entry {
		match key_path {
			[]string { return error('InvalidAccessError: multiEntry cannot use a sequence key path') }
			else {}
		}
	}
	mut index := IndexData{
		name:        name
		key_path:    clone_key_path(key_path)
		unique:      parameters.unique
		multi_entry: parameters.multi_entry
	}
	rebuild_index(data, mut index)!
	data.indexes[name] = index
	store.save(data)
	return IDBIndex{
		transaction: store.transaction
		store_name:  store.name_
		name_:       name
	}
}

pub fn (store &IDBObjectStore) index(name string) !IDBIndex {
	data := store.load()!
	if name !in data.indexes {
		return error('NotFoundError: index does not exist')
	}
	return IDBIndex{
		transaction: store.transaction
		store_name:  store.name_
		name_:       name
	}
}

pub fn (mut store IDBObjectStore) delete_index(name string) ! {
	store.transaction.require_versionchange_active()!
	mut data := store.load()!
	if name !in data.indexes {
		return error('NotFoundError: index does not exist')
	}
	data.indexes.delete(name)
	store.save(data)
}

pub fn (mut store IDBObjectStore) open_cursor(range ?IDBKeyRange, direction IDBCursorDirection, keys_only bool) !&IDBRequest {
	store.transaction.require_active()!
	data := store.load()!
	actual := range or { IDBKeyRange.unbounded() }
	records := records_in_range(data.records, actual, direction)!
	mut entries := []CursorEntry{cap: records.len}
	for record in records {
		entries << CursorEntry{
			key:         record.key.clone()
			primary_key: record.key.clone()
			value:       record.value.clone()
		}
	}
	mut request := store.new_request()
	if entries.len == 0 {
		request.succeed(.undefined)
		return request
	}
	mut cursor := IDBCursor.create(store.transaction, store.name_, '', direction, entries,
		!keys_only, request)
	request.cursor = cursor
	request.succeed(.cursor)
	return request
}
