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
	store_      ?&ObjectStoreData
mut:
	// The asynchronous browser entry points execute against the same request
	// that was returned to the caller, rather than creating a second request.
	operation_request_ ?&IDBRequest
	operation_indexes_ []&IndexData
	has_operation_indexes_ bool
}

fn (store &IDBObjectStore) load() !&ObjectStoreData {
	if data := store.store_ {
		if data.deleted {
			return error('InvalidStateError: object store was deleted')
		}
		return data
	}
	if store.name_ !in store.transaction.database.data.stores {
		return error('InvalidStateError: object store was deleted')
	}
	return store.transaction.database.data.stores[store.name_] or {
		return error('InvalidStateError: object store was deleted')
	}
}

pub fn (store &IDBObjectStore) name() string {
	if store.transaction.state == .finished { return store.name_ }
	if data := store.store_ {
		return data.name
	}
	return store.name_
}

pub fn (store &IDBObjectStore) key_path() ?KeyPath {
	data := store.load() or { return none }
	return data.key_path
}

pub fn (store &IDBObjectStore) key_path_value() Value {
	key_path := store.key_path() or { return null_value() }
	return convert_a_key_path_to_a_value(key_path)
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
	if mut log := data.mutation_log_ {
		log.note_object_store_renamed(store.name_)
	}
	store.transaction.database.data.stores.delete(store.name_)
	store.transaction.object_store_handles.delete(store.name_)
	data.name = name
	store.transaction.database.data.stores[name] = data
	store.transaction.scope_names = store.transaction.scope_names.map(if it == store.name_ {
		name
	} else {
		it
	})
	sort_name_list(mut store.transaction.scope_names)
	store.name_ = name
	store.transaction.object_store_handles[name] = store
}

pub fn (mut store IDBObjectStore) add(value Value, key ?Key) !&IDBRequest {
	return store.store_record(value, key, true)
}

pub fn (mut store IDBObjectStore) put(value Value, key ?Key) !&IDBRequest {
	return store.store_record(value, key, false)
}

fn (mut store IDBObjectStore) store_record(input Value, supplied_key ?Key, no_overwrite bool) !&IDBRequest {
	if store.operation_request_ == none { store.transaction.require_writable()! }
	mut data := store.load()!
	mutation_position := data.mutation_log_position()
	mut value := input.clone()
	mut key := invalid_key()
	if path := data.key_path {
		if supplied_key != none {
			return error('DataError: an explicit key is forbidden for inline keys')
		}
		if path is string {
			if extracted := evaluate_string_key_path(value, path) {
				if !value_to_key(extracted).is_valid() { return error('DataError: inline key path yielded an invalid key') }
			}
		}
		key = evaluate_key_path(value, path) or { invalid_key() }
		if !key.is_valid() {
			if !data.auto_increment {
				return error('DataError: inline key path did not yield a key')
			}
			match path {
				string {
					key = number_key(f64(data.generate_a_key()!))
					value = inject_key(value, path, key) or {
						data.revert_mutations_from(mutation_position)
						return completed_error_request(mut store, err.msg())
					}
				}
				[]string {
					return error('DataError: generated key cannot populate a sequence key path')
				}
			}
		} else if data.auto_increment {
			data.possibly_update_the_key_generator(key)
		}
	} else if provided := supplied_key {
		key = provided.clone()
		ensure_valid_key(key)!
		if data.auto_increment {
			data.possibly_update_the_key_generator(key)
		}
	} else if data.auto_increment {
		key = number_key(f64(data.generate_a_key()!))
	} else {
		return error('DataError: out-of-line object store requires a key')
	}
	position := find_record(data.records, key)
	if no_overwrite && position >= 0 {
		data.revert_mutations_from(mutation_position)
		return completed_error_request(mut store, 'ConstraintError: key already exists')
	}
	if position >= 0 {
		range := IDBKeyRange.only(key)!
		data.remove_records_in_range(range)
		for mut index in store.operation_indexes(data) {
			index.remove_records_with_value_in_range(range)
		}
	}
	data.store_a_record(ObjectStoreRecord{
		key:   key
		value: value
	})!
	for mut index in store.operation_indexes(data) {
		index_keys := index_keys_for_value(index, value)
		if index.unique {
			for index_key in index_keys {
				if index.has_record_with_key(index_key) {
					data.revert_mutations_from(mutation_position)
					return completed_error_request(mut store, 'ConstraintError: unique index key already exists')
				}
			}
		}
		for index_key in index_keys {
			index.store_a_record(IndexRecord{
				key:         index_key
				primary_key: key
			})!
		}
	}
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
	if request := store.operation_request_ {
		return request
	}
	mut request := IDBRequest.create_for_global_scope(store.relevant_global_object(), store.name_)
	request.transaction_ = store.transaction
	store.transaction.request_list_.append(request)
	return request
}

pub fn (mut store IDBObjectStore) get(range IDBKeyRange) !&IDBRequest {
	if store.operation_request_ == none { store.transaction.require_active()! }
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
	if store.operation_request_ == none { store.transaction.require_active()! }
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
	if store.operation_request_ == none { store.transaction.require_active()! }
	data := store.load()!
	range := options.range or { IDBKeyRange.unbounded() }
	mut records := records_in_range(data.records, range, options.direction)!
	if count := options.count {
		if count > 0 && records.len > int(count) { records.trim(int(count)) }
	}
	mut request := store.new_request()
	request.values = records.map(it.value.clone())
	request.succeed(.values)
	return request
}

pub fn (mut store IDBObjectStore) get_all_keys(options IDBGetAllOptions) !&IDBRequest {
	if store.operation_request_ == none { store.transaction.require_active()! }
	data := store.load()!
	range := options.range or { IDBKeyRange.unbounded() }
	mut records := records_in_range(data.records, range, options.direction)!
	if count := options.count {
		if count > 0 && records.len > int(count) { records.trim(int(count)) }
	}
	mut request := store.new_request()
	request.keys = records.map(it.key.clone())
	request.succeed(.keys)
	return request
}

pub fn (mut store IDBObjectStore) get_all_records(options IDBGetAllOptions) !&IDBRequest {
	if store.operation_request_ == none { store.transaction.require_active()! }
	data := store.load()!
	range := options.range or { IDBKeyRange.unbounded() }
	mut records := records_in_range(data.records, range, options.direction)!
	if count := options.count {
		if count > 0 && records.len > int(count) { records.trim(int(count)) }
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
	if store.operation_request_ == none { store.transaction.require_active()! }
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
	data.remove_records_in_range(range)
	for _, mut index in data.indexes {
		index.remove_records_with_value_in_range(range)
	}
	mut request := store.new_request()
	request.succeed(.undefined)
	return request
}

pub fn (mut store IDBObjectStore) clear() !&IDBRequest {
	store.transaction.require_writable()!
	mut data := store.load()!
	data.clear_records()
	for _, mut index in data.indexes {
		index.clear_records()
	}
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

pub fn (mut store IDBObjectStore) create_index(name string, key_path KeyPath, parameters IDBIndexParameters) !IDBIndex {
	return store.create_index_schema(name, key_path, parameters, true)
}

fn (mut store IDBObjectStore) create_index_schema(name string, key_path KeyPath, parameters IDBIndexParameters, populate bool) !IDBIndex {
	mut data := store.load()!
	if store.transaction.mode != .versionchange { return error('InvalidStateError: operation requires a versionchange transaction') }
	store.transaction.require_active()!
	if name in data.indexes {
		return error('ConstraintError: index already exists')
	}
	if !is_valid_key_path(key_path) {
		return error('SyntaxError: invalid index key path')
	}
	if parameters.multi_entry {
		match key_path {
			[]string {
				return error('InvalidAccessError: multiEntry cannot use a sequence key path')
			}
			else {}
		}
	}
	mut index := IndexData{
		name:        name
		key_path:    clone_key_path(key_path)
		unique:      parameters.unique
		multi_entry: parameters.multi_entry
	}
	if populate { rebuild_index(data, mut index)! }
	index.store_name = data.name
	index.object_store_ = data
	mut stored_index := &index
	data.indexes[name] = stored_index
	if mut log := data.mutation_log_ {
		log.note_index_created(stored_index)
	}
	return IDBIndex{
		transaction:          store.transaction
		store_name:           store.name_
		name_:                name
		store_:               data
		index_:               stored_index
		object_store_handle_: *store
	}
}

pub fn (store &IDBObjectStore) index(name string) !IDBIndex {
	data := store.load()!
	if store.transaction.state in [.finished, .aborted] {
		return error('InvalidStateError: transaction has finished')
	}
	if name !in data.indexes {
		return error('NotFoundError: index does not exist')
	}
	return IDBIndex{
		transaction:          store.transaction
		store_name:           store.name_
		name_:                name
		store_:               data
		index_:               data.indexes[name] or { return error('NotFoundError: index does not exist') }
		object_store_handle_: *store
	}
}

pub fn (mut store IDBObjectStore) delete_index(name string) ! {
	store.transaction.require_versionchange_active()!
	mut data := store.load()!
	if name !in data.indexes {
		return error('NotFoundError: index does not exist')
	}
	mut index := data.indexes[name] or { return error('NotFoundError: index does not exist') }
	if mut log := data.mutation_log_ {
		log.note_index_deleted(index)
	}
	index.deleted = true
	data.indexes.delete(name)
}

pub fn (mut store IDBObjectStore) open_cursor(range ?IDBKeyRange, direction IDBCursorDirection, keys_only bool) !&IDBRequest {
	store.transaction.require_active()!
	data := store.load()!
	actual := range or { IDBKeyRange.unbounded() }
	mut request := store.new_request()
	mut cursor := IDBCursor.create(store.transaction, data, none, direction, actual, !keys_only, request)
	if !cursor.iterate(none, none, 1)! {
		request.succeed(.undefined)
		return request
	}
	request.cursor = cursor
	request.succeed(.cursor)
	return request
}
