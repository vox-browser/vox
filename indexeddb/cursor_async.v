// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module indexeddb

// Browser cursor operations share the transaction's ordered request queue.
// The synchronous typed entry points remain available for standalone callers.
pub fn (mut store IDBObjectStore) open_cursor_async(range ?IDBKeyRange, direction IDBCursorDirection, keys_only bool) !&IDBRequest {
	data := store.load()!
	store.require_cursor_source()!
	mut request := IDBRequest.create_for_global_scope(store.relevant_global_object(), store.name())
	request.transaction_ = store.transaction
	mut cursor := IDBCursor.create(store.transaction, data, none, direction, range or { IDBKeyRange.unbounded() }, !keys_only, request)
	cursor.enqueue_iteration(none, none, 1)
	return request
}

pub fn (mut index IDBIndex) open_cursor_async(range ?IDBKeyRange, direction IDBCursorDirection, keys_only bool) !&IDBRequest {
	store, data := index.load()!
	index.require_cursor_source()!
	mut request := IDBRequest.create_for_global_scope(index.relevant_global_object(), index.name())
	request.transaction_ = index.transaction
	mut cursor := IDBCursor.create(index.transaction, store, data, direction, range or { IDBKeyRange.unbounded() }, !keys_only, request)
	cursor.enqueue_iteration(none, none, 1)
	return request
}

pub fn (store &IDBObjectStore) require_cursor_source() ! {
	store.load()!
	store.transaction.require_active()!
}

pub fn (index &IDBIndex) require_cursor_source() ! {
	index.load()!
	index.transaction.require_active()!
}

pub fn (mut cursor IDBCursor) continue_async(key ?Key) ! {
	cursor.validate_continue(key)!
	cursor.enqueue_iteration(key, none, 1)
}

pub fn (mut cursor IDBCursor) advance_async(count u32) ! {
	cursor.validate_advance(count)!
	cursor.enqueue_iteration(none, none, u64(count))
}

pub fn (mut cursor IDBCursor) continue_primary_key_async(key Key, primary_key Key) ! {
	cursor.validate_continue_primary_key(key, primary_key)!
	cursor.enqueue_iteration(key, primary_key, 1)
}

fn (mut cursor IDBCursor) enqueue_iteration(key ?Key, primary_key ?Key, count u64) {
	mut request := cursor.request
	request.ready_state = .pending
	request.processed = false
	request.error_message = ''
	request.error_event_canceled_ = false
	request.event_listener_threw_ = false
	cursor.got_value = false
	key_copy := if value := key { ?Key(value.clone()) } else { none }
	primary_copy := if value := primary_key { ?Key(value.clone()) } else { none }
	mut list := cursor.transaction.request_list_
	list.reuse(request, fn [mut cursor, key_copy, primary_copy, count] (mut pending IDBRequest) {
		if pending.aborted { return }
		mut transaction := cursor.transaction
		if transaction.state == .aborted { return }
		was_committing := transaction.state == .committing
		transaction.set_cleanup_event_loop(unsafe { nil })
		if !was_committing { transaction.state = .active }
		found := cursor.iterate(key_copy, primary_copy, count) or {
			pending.fail(err.msg())
			false
		}
		if pending.ready_state == .pending {
			if found {
				pending.cursor = cursor
				pending.succeed(.cursor)
			} else {
				pending.value = null_value()
				pending.succeed(.value)
			}
		}
		if (pending.event_listener_threw_ || (pending.error_message != '' && !pending.error_event_canceled_)) && transaction.state !in [.aborted, .finished] {
			if was_committing { transaction.state = .inactive }
			transaction.abort(if pending.event_listener_threw_ { 'AbortError: cursor listener threw' } else { pending.error_message }) or { panic(err) }
			return
		}
		if transaction.state == .active {
			transaction.state = if was_committing { .committing } else { .inactive }
		}
		if transaction.state == .inactive && transaction.request_list_.is_empty() {
			commit_a_transaction(mut transaction) or { panic(err) }
		}
	})
}
