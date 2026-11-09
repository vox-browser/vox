// SPDX-License-Identifier: BSD-2-Clause
module indexeddb

// Retrieval joins the same ordered queue as writes and cursor iterations.
pub fn (mut index IDBIndex) get_async(range IDBKeyRange, keys_only bool) !&IDBRequest {
	index.require_cursor_source()!
	return index.enqueue_operation(fn [range, keys_only] (mut handle IDBIndex) !&IDBRequest {
		if keys_only { return handle.get_key(range) }
		return handle.get(range)
	})
}

pub fn (mut index IDBIndex) count_async(range ?IDBKeyRange) !&IDBRequest {
	index.require_cursor_source()!
	return index.enqueue_operation(fn [range] (mut handle IDBIndex) !&IDBRequest {
		return handle.count(range)
	})
}

type IndexOperation = fn (mut IDBIndex) !&IDBRequest

fn (mut index IDBIndex) enqueue_operation(operation IndexOperation) &IDBRequest {
	mut request := IDBRequest.create_for_global_scope(index.relevant_global_object(), index.name())
	request.transaction_ = index.transaction
	handle := index
	mut list := index.transaction.request_list_
	list.enqueue(request, fn [handle, operation] (mut pending IDBRequest) {
		if pending.aborted { return }
		mut transaction := handle.transaction
		if transaction.state == .aborted { return }
		was_committing := transaction.state == .committing
		transaction.set_cleanup_event_loop(unsafe { nil })
		if !was_committing { transaction.state = .active }
		mut executing := handle
		executing.operation_request_ = &pending
		operation(mut executing) or { pending.fail(err.msg()) }
		if (pending.event_listener_threw_ || (pending.error_message != '' && !pending.error_event_canceled_)) && transaction.state !in [.aborted, .finished] {
			if transaction.state == .committing { transaction.state = .inactive }
			transaction.abort(if pending.event_listener_threw_ { 'AbortError: request listener threw' } else { pending.error_message }) or { panic(err) }
			return
		}
		if transaction.state == .active { transaction.state = if was_committing { .committing } else { .inactive } }
		if transaction.state == .inactive && transaction.request_list_.is_empty() { commit_a_transaction(mut transaction) or { panic(err) } }
	})
	return request
}
