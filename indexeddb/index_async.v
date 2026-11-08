// SPDX-License-Identifier: BSD-2-Clause
module indexeddb

// Retrieval joins the same ordered queue as writes and cursor iterations.
pub fn (mut index IDBIndex) get_async(range IDBKeyRange, keys_only bool) !&IDBRequest {
	index.require_cursor_source()!
	mut request := IDBRequest.create_for_global_scope(index.relevant_global_object(), index.name())
	request.transaction_ = index.transaction
	handle := index
	mut list := index.transaction.request_list_
	list.enqueue(request, fn [handle, range, keys_only] (mut pending IDBRequest) {
		if pending.aborted { return }
		mut transaction := handle.transaction
		if transaction.state == .aborted { return }
		was_committing := transaction.state == .committing
		transaction.set_cleanup_event_loop(unsafe { nil })
		if !was_committing { transaction.state = .active }
		mut executing := handle
		executing.operation_request_ = &pending
		if keys_only { executing.get_key(range) or { pending.fail(err.msg()) } }
		else { executing.get(range) or { pending.fail(err.msg()) } }
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
