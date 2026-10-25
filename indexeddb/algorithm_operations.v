// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// IndexedDB algorithms from Internal/Algorithms.cpp. Browser task dispatch is
// queued at the standalone event-loop boundary; the embedding advances them
// with run_database_tasks(), preserving database task order.
@[has_globals]
module indexeddb

pub type DatabaseTask = fn ()

pub type RequestAlgorithm = fn (mut IDBRequest) !RequestResultKind

pub fn open_a_database_connection(mut factory IDBFactory, name string, version ?u64) !&IDBOpenDBRequest {
	return factory.open(name, version)
}

pub fn fire_a_version_change_event(mut connection IDBDatabase, old_version u64, new_version ?u64) IDBVersionChangeEvent {
	event := IDBVersionChangeEvent.create('versionchange', old_version, new_version)
	connection.events << 'versionchange'
	connection.version_change_events << event
	if callback := connection.onversionchange_ {
		callback()
	}
	return event
}

pub fn convert_a_value_to_a_key(value Value) Key {
	return value_to_key(value)
}

pub fn strictly_split_key_path(key_path string) []string {
	mut identifiers := []string{}
	mut start := 0
	for index, byte in key_path.bytes() {
		if byte != `.` {
			continue
		}
		identifiers << key_path[start..index]
		start = index + 1
	}
	identifiers << key_path[start..]
	return identifiers
}

pub fn close_a_database_connection(mut connection IDBDatabase, forced bool) {
	connection.close()
	if forced {
		connection.events << 'close'
		if callback := connection.onclose_ {
			callback()
		}
	}
}

pub fn upgrade_a_database(mut request IDBOpenDBRequest) ! {
	if isnil(request.upgrade_transaction) {
		return error('InvalidStateError: request has no upgrade transaction')
	}
	request.request.events << 'upgradeneeded'
	if callback := request.onupgradeneeded_ {
		callback()
	}
}

pub fn delete_a_database(mut factory IDBFactory, name string) !&IDBOpenDBRequest {
	return factory.delete_database(name)
}

pub fn abort_an_upgrade_transaction(mut request IDBOpenDBRequest, reason string) ! {
	request.abort_upgrade(reason)!
}

pub fn abort_a_transaction(mut transaction IDBTransaction, reason string) ! {
	transaction.abort(reason)!
}

pub fn convert_a_key_to_a_value(key Key) !Value {
	return key_to_value(key)
}

pub struct StoredRecordSerialization {
pub:
	value     ?Value
	corrupted bool
}

pub fn StoredRecordSerialization.from_value(value Value) StoredRecordSerialization {
	return StoredRecordSerialization{
		value: value.clone()
	}
}

pub fn deserialize_a_stored_record(serialized StoredRecordSerialization) !Value {
	if serialized.corrupted {
		return error('NotReadableError: Stored value could not be read')
	}
	value := serialized.value or {
		return error('NotReadableError: Stored value could not be read')
	}
	return value.clone()
}

pub fn create_a_sorted_name_list(names []string) []string {
	mut result := names.clone()
	sort_name_list(mut result)
	return result
}

pub fn commit_a_transaction(mut transaction IDBTransaction) ! {
	transaction.state = .committing
	transaction.set_cleanup_event_loop(unsafe { nil })
	transaction_pointer := voidptr(&transaction)
	mut list := transaction.request_list_
	list.set_on_all_processed(fn [transaction_pointer] () {
		pending := unsafe { &IDBTransaction(transaction_pointer) }
		if pending.state != .committing {
			return
		}
		queue_a_database_task_for_global_scope(pending.relevant_global_scope(), fn [transaction_pointer] () {
			mut transaction := unsafe { &IDBTransaction(transaction_pointer) }
			// A request may fail after an explicit commit queued completion.
			if transaction.state != .committing { return }
			if transaction.mode == .versionchange {
				transaction.database.data.upgrade_transaction = none
			}
			transaction.notify_devtools_of_committed_changes()
			transaction.discard_mutation_logs()
			transaction.state = .finished
			transaction.events << 'complete'
			if callback := transaction.oncomplete_ {
				callback()
			}
			if transaction.mode == .versionchange {
				if mut request := transaction.associated_request_ {
					request.transaction_ = none
				}
				transaction.associated_request_ = none
			}
			// Pending upgrade completion is notified after the complete event,
			// preserving tasks queued by that event before the open success task.
			if callback := transaction.committed_callback_ {
				transaction.committed_callback_ = none
				callback()
			}
			transaction.finish_connection_if_needed()
		})
	})
}

pub fn clone_in_realm(value Value) Value {
	return value.clone()
}

pub fn convert_a_value_to_a_multi_entry_key(value Value) Key {
	if value.kind != .array {
		return value_to_key(value)
	}
	mut keys := []Key{}
	for item in value.items {
		key := value_to_key(item)
		if key.is_valid() && !keys.any(keys_equal(it, key)) {
			keys << key
		}
	}
	return array_key(keys)
}

pub fn evaluate_key_path_on_a_value(value Value, key_path KeyPath) ?Value {
	return match key_path {
		string { evaluate_string_key_path(value, key_path) }
		[]string {
			mut values := []Value{}
			for path in key_path {
				values << evaluate_string_key_path(value, path) or { return none }
			}
			array_value(values)
		}
	}
}

pub fn extract_a_key_from_a_value_using_a_key_path(value Value, key_path KeyPath) ?Key {
	return evaluate_key_path(value, key_path)
}

pub fn check_that_a_key_could_be_injected_into_a_value(value Value, key_path string) bool {
	_ = inject_key(value, key_path, number_key(1)) or { return false }
	return true
}

pub fn fire_an_error_event(mut request IDBRequest, message string) {
	request.fail(message)
}

pub fn fire_a_success_event(mut request IDBRequest, result RequestResultKind) {
	request.succeed(result)
}

pub fn asynchronously_execute_a_request(mut request IDBRequest, algorithm RequestAlgorithm) {
	result := algorithm(mut request) or {
		request.fail(err.msg())
		return
	}
	request.succeed(result)
}

pub fn inject_a_key_into_a_value_using_a_key_path(value Value, key_path string, key Key) !Value {
	return inject_key(value, key_path, key)
}

pub fn delete_records_from_an_object_store(mut store ObjectStoreData, range IDBKeyRange) []ObjectStoreRecord {
	return store.remove_records_in_range(range)
}

pub fn store_a_record_into_an_object_store(mut store ObjectStoreData, record ObjectStoreRecord) ! {
	store.store_a_record(record)!
}

pub fn convert_a_value_to_a_key_range(value Value) !IDBKeyRange {
	key := value_to_key(value)
	ensure_valid_key(key)!
	return IDBKeyRange.only(key)
}

pub fn convert_a_key_path_to_a_value(key_path KeyPath) Value {
	return match key_path {
		string { string_value(key_path) }
		[]string { array_value(key_path.map(string_value(it))) }
	}
}

pub fn set_idb_request_result(mut request IDBRequest, database &IDBDatabase) {
	request.database = database
	request.succeed(.database)
}

pub fn resolve_database_info_list_promise(databases []&DatabaseData) []IDBDatabaseInfo {
	mut result := []IDBDatabaseInfo{}
	for database in databases {
		if database.version == 0 {
			continue
		}
		result << IDBDatabaseInfo{
			name:    database.name
			version: database.version
		}
	}
	return result
}

pub fn append_idb_record(mut list []IDBRecord, index u32, record IDBRecord) {
	for list.len < int(index) {
		list << IDBRecord{}
	}
	if int(index) == list.len {
		list << record
	} else {
		list[int(index)] = record
	}
}

pub fn idb_cursor_result(cursor ?&IDBCursor) ?&IDBCursor {
	return cursor
}

pub fn key_path_value_for_blob_or_file(value Value, identifier string) ?Value {
	if value.kind in [.blob, .file] {
		if identifier == 'size' {
			return number_value(f64(value.blob_size))
		}
		if identifier == 'type' {
			return string_value(value.mime_type)
		}
	}
	if value.kind == .file {
		if identifier == 'name' {
			return string_value(value.file_name)
		}
		if identifier == 'lastModified' {
			return number_value(value.last_modified)
		}
	}
	return none
}

pub fn count_the_records_in_a_range(store &ObjectStoreData, range IDBKeyRange) u64 {
	return store.count_records_in_range(range)
}

pub fn retrieve_a_value_from_an_object_store(store &ObjectStoreData, range IDBKeyRange) ?Value {
	record := store.first_in_range(range) or { return none }
	return record.value.clone()
}

pub fn iterate_a_cursor(mut store IDBObjectStore, range ?IDBKeyRange, direction IDBCursorDirection, key_only bool) !&IDBRequest {
	return store.open_cursor(range, direction, key_only)
}

pub fn clear_an_object_store(mut store ObjectStoreData) {
	store.clear_records()
}

pub fn retrieve_a_key_from_an_object_store(store &ObjectStoreData, range IDBKeyRange) ?Key {
	record := store.first_in_range(range) or { return none }
	return record.key.clone()
}

pub fn retrieve_multiple_values_from_an_object_store(store &ObjectStoreData, range IDBKeyRange, count ?u32) []Value {
	return store.first_n_in_range(range, count).map(it.value.clone())
}

pub fn retrieve_multiple_items_from_an_object_store(store &ObjectStoreData, range IDBKeyRange, count ?u32) []IDBRecord {
	return store.first_n_in_range(range, count).map(IDBRecord.create(it.key, it.key, it.value))
}

pub fn retrieve_multiple_keys_from_an_object_store(store &ObjectStoreData, range IDBKeyRange, count ?u32) []Key {
	return store.first_n_in_range(range, count).map(it.key.clone())
}

pub fn retrieve_a_referenced_value_from_an_index(index &IndexData, store &ObjectStoreData, range IDBKeyRange) ?Value {
	record := index.first_in_range(range) or { return none }
	return (index.referenced_value(record, store) or { return none }).clone()
}

pub fn retrieve_a_value_from_an_index(index &IndexData, range IDBKeyRange) ?Key {
	record := index.first_in_range(range) or { return none }
	return record.primary_key.clone()
}

pub fn retrieve_multiple_referenced_values_from_an_index(index &IndexData, store &ObjectStoreData, range IDBKeyRange, count ?u32) []Value {
	mut values := []Value{}
	for record in index.first_n_in_range(range, count) {
		if value := index.referenced_value(record, store) {
			values << value.clone()
		}
	}
	return values
}

pub fn retrieve_multiple_values_from_an_index(index &IndexData, range IDBKeyRange, count ?u32) []Key {
	return index.first_n_in_range(range, count).map(it.primary_key.clone())
}

__global (
	indexeddb_database_tasks = []DatabaseTask{}
)

pub fn queue_a_database_task(task DatabaseTask) {
	indexeddb_database_tasks << task
}

pub fn queue_a_database_task_for_global_scope(global_scope &IndexedDBGlobalScope, task DatabaseTask) {
	if dispatch := global_scope.queue_database_task {
		dispatch(task)
		return
	}
	queue_a_database_task(task)
}

// One database task, corresponding to an event-loop task-source dispatch.
pub fn run_next_database_task() bool {
	if indexeddb_database_tasks.len == 0 {
		return false
	}
	task := indexeddb_database_tasks[0]
	indexeddb_database_tasks.delete(0)
	task()
	return true
}

pub fn run_database_tasks() {
	for run_next_database_task() {
	}
}

pub fn cleanup_indexed_database_transactions(event_loop voidptr) bool {
	assert event_loop != unsafe { nil }
	// Every microtask checkpoint runs this; most documents never open a
	// database, so skip copying the empty registry.
	if !idb_has_databases() {
		return false
	}
	mut has_matching_event_loop := false
	for _, database in idb_databases() {
		for connection in database.associated_connections_as_root_vector() {
			for transaction_pointer in connection.transactions.clone() {
				mut transaction := unsafe { &IDBTransaction(transaction_pointer) }
				if transaction.cleanup_event_loop() != event_loop {
					continue
				}
				has_matching_event_loop = true
				assert transaction.state == .active
				transaction.state = .inactive
				list := transaction.request_list()
				if !list.execution_is_blocked() && list.is_empty() {
					commit_a_transaction(mut transaction) or { panic(err) }
				}
				transaction.set_cleanup_event_loop(unsafe { nil })
			}
		}
	}
	return has_matching_event_loop
}

pub fn is_a_potentially_valid_key_range(lower ?Key, upper ?Key, lower_open bool, upper_open bool) bool {
	_ = IDBKeyRange.create(lower, upper, lower_open, upper_open) or { return false }
	return true
}

pub fn retrieve_multiple_items_from_an_index(index &IndexData, store &ObjectStoreData, range IDBKeyRange, count ?u32) []IDBRecord {
	mut records := []IDBRecord{}
	for index_record in index.first_n_in_range(range, count) {
		value := index.referenced_value(index_record, store) or { continue }
		records << IDBRecord.create(index_record.key, index_record.primary_key, value)
	}
	return records
}

pub fn create_a_request_to_retrieve_multiple_items(mut store IDBObjectStore, options IDBGetAllOptions, keys_only bool) !&IDBRequest {
	if keys_only {
		return store.get_all_keys(options)
	}
	return store.get_all_records(options)
}

pub fn to_key_value_internal(value Value) Key {
	return value_to_key(value)
}
