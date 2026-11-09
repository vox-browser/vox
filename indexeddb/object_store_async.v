// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module indexeddb

// Browser entry points retain synchronous argument validation, then execute
// through the transaction's ordered request list. Standalone typed callers
// can continue using the immediate algorithm entry points.
pub fn (mut store IDBObjectStore) get_async(range IDBKeyRange) !&IDBRequest {
	store.load()!
	store.transaction.require_active()!
	return store.enqueue_operation(fn [range] (mut handle IDBObjectStore) !&IDBRequest {
		return handle.get(range)
	})
}

pub fn (mut store IDBObjectStore) get_key_async(range IDBKeyRange) !&IDBRequest {
	store.require_cursor_source()!
	return store.enqueue_operation(fn [range] (mut handle IDBObjectStore) !&IDBRequest {
		return handle.get_key(range)
	})
}

pub fn (mut store IDBObjectStore) put_async(input Value, key ?Key, no_overwrite bool) !&IDBRequest {
	data := store.load()!
	store.transaction.require_writable()!
	if path := data.key_path {
		if key != none { return error('DataError: an explicit key is forbidden for inline keys') }
		if path is string {
			if extracted := evaluate_string_key_path(input, path) {
				if !value_to_key(extracted).is_valid() { return error('DataError: inline key path yielded an invalid key') }
			}
		}
		if actual := evaluate_key_path(input, path) {
			ensure_valid_key(actual)!
		} else {
			if !data.auto_increment {
				return error('DataError: inline key path did not yield a key')
			}
			match path {
				string { inject_key(input, path, number_key(1))! }
				[]string {
					return error('DataError: generated key cannot populate a sequence key path')
				}
			}
		}
	} else if supplied := key {
		ensure_valid_key(supplied)!
	} else if !data.auto_increment {
		return error('DataError: out-of-line object store requires a key')
	}
	value := input.clone()
	supplied := if actual := key { ?Key(actual.clone()) } else { none }
	return store.enqueue_operation(fn [value, supplied, no_overwrite] (mut handle IDBObjectStore) !&IDBRequest {
		return handle.store_record(value, supplied, no_overwrite)
	})
}

type ObjectStoreOperation = fn (mut IDBObjectStore) !&IDBRequest

fn (mut store IDBObjectStore) enqueue_operation(operation ObjectStoreOperation) &IDBRequest {
	mut request := IDBRequest.create_for_global_scope(store.relevant_global_object(), store.name_)
	request.transaction_ = store.transaction
	mut handle := store
	if data := store.store_ {
		handle.operation_indexes_ = data.indexes.values()
		handle.has_operation_indexes_ = true
	}
	mut list := store.transaction.request_list_
	list.enqueue(request, fn [handle, operation] (mut pending IDBRequest) {
		if pending.aborted { return }
		mut transaction := handle.transaction
		if transaction.state == .aborted { return }
		was_committing := transaction.state == .committing
		transaction.set_cleanup_event_loop(unsafe { nil })
		// The operation algorithms and their result event run while active.
		if !was_committing { transaction.state = .active }
		mut executing := handle
		executing.operation_request_ = &pending
		operation(mut executing) or { pending.fail(err.msg()) }
		if (pending.event_listener_threw_ || (pending.error_message != '' && !pending.error_event_canceled_)) && transaction.state !in [
			.aborted,
			.finished,
		] {
			// Public abort() rejects an explicit commit, but request failures
			// must still abort the committing transaction's native operation.
			if transaction.state == .committing { transaction.state = .inactive }
			reason := if pending.event_listener_threw_ {
				'AbortError: request listener threw'
			} else {
				pending.error_message
			}
			transaction.abort(reason) or { panic(err) }
			return
		}
		if transaction.state == .active {
			transaction.state = if was_committing { .committing } else { .inactive }
		}
		if transaction.state == .inactive && transaction.request_list_.is_empty() {
			commit_a_transaction(mut transaction) or { panic(err) }
		}
	})
	return request
}

fn (store &IDBObjectStore) operation_indexes(data &ObjectStoreData) []&IndexData {
	return if store.has_operation_indexes_ { store.operation_indexes_ } else { data.indexes.values() }
}

pub fn (mut store IDBObjectStore) count_async(range ?IDBKeyRange) !&IDBRequest {
	store.require_cursor_source()!
	return store.enqueue_operation(fn [range] (mut handle IDBObjectStore) !&IDBRequest { return handle.count(range) })
}

// Schema handles exist synchronously, while population runs between the
// transaction's earlier and later requests. A population failure aborts the
// transaction without dispatching an error at an author-visible request.
pub fn (mut store IDBObjectStore) create_index_async(name string, path KeyPath, parameters IDBIndexParameters) !IDBIndex {
	index := store.create_index_schema(name, path, parameters, false)!
	data := index.store_ or { return error('InvalidStateError: Missing store') }
	mut actual := index.index_ or { return error('InvalidStateError: Missing index') }
	mut transaction := store.transaction
	mut request := IDBRequest.create_for_global_scope(store.relevant_global_object(), name)
	request.transaction_ = transaction
	mut list := transaction.request_list_
	list.enqueue(request, fn [data, mut actual, mut transaction] (mut pending IDBRequest) {
		if pending.aborted || transaction.state == .aborted { return }
		rebuild_index(data, mut actual) or {
			pending.fail(err.msg())
			if transaction.state == .committing { transaction.state = .inactive }
			transaction.abort(err.msg()) or { panic(err) }
			return
		}
		pending.succeed(.undefined)
		if transaction.state == .inactive && transaction.request_list_.is_empty() { commit_a_transaction(mut transaction) or { panic(err) } }
	})
	return index
}
