// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IDBTransaction.{h,cpp,idl} and
// Internal/MutationLog.{h,cpp}.
module indexeddb

pub enum IDBTransactionMode {
	readonly
	readwrite
	versionchange
}

pub enum IDBTransactionDurability {
	default_
	strict
	relaxed
}

pub enum TransactionState {
	active
	inactive
	committing
	finished
	aborted
}

pub struct StoreMutationLogEntry {
pub:
	store &ObjectStoreData
	log   &MutationLog
}

@[heap]
pub struct IDBTransaction {
pub mut:
	database             &IDBDatabase
	mode                 IDBTransactionMode
	durability           IDBTransactionDurability
	scope_names          []string
	state                TransactionState = .active
	error_message        string
	events               []string
	request_list_        &RequestList = &RequestList{}
	store_mutation_logs  []StoreMutationLogEntry
	original_version     u64
	associated_request_  ?&IDBRequest
	aborted_             bool
	cleanup_event_loop_  voidptr
	committed_callback_  ?fn ()
	aborted_callback_    ?fn ()
	object_store_handles map[string]IDBObjectStore
	index_handles_       []IDBIndex
	onabort_             ?IDBEventHandler
	oncomplete_          ?IDBEventHandler
	onerror_             ?IDBEventHandler
}

pub fn IDBTransaction.create(database &IDBDatabase, mode IDBTransactionMode, durability IDBTransactionDurability, scope []string) &IDBTransaction {
	mut transaction := &IDBTransaction{
		database:         database
		mode:             mode
		durability:       durability
		scope_names:      scope.clone()
		original_version: database.data.version
	}
	if mode != .readonly {
		transaction.set_up_mutation_logs()
	}
	unsafe {
		database.transactions << transaction
	}
	return transaction
}

pub fn IDBTransaction.connection_offset() uint {
	return uint(__offsetof(IDBTransaction, database))
}

pub fn IDBTransaction.error_offset() uint {
	return uint(__offsetof(IDBTransaction, error_message))
}

pub fn (transaction &IDBTransaction) object_store_names() []string {
	mut names := transaction.scope_names.clone()
	sort_name_list(mut names)
	return names
}

pub fn (transaction &IDBTransaction) require_active() ! {
	if transaction.state != .active {
		return error('TransactionInactiveError: transaction is not active')
	}
}

pub fn (transaction &IDBTransaction) require_writable() ! {
	transaction.require_active()!
	if transaction.mode == .readonly {
		return error('ReadOnlyError: transaction is read-only')
	}
}

pub fn (transaction &IDBTransaction) require_versionchange_active() ! {
	transaction.require_active()!
	if transaction.mode != .versionchange {
		return error('InvalidStateError: operation requires a versionchange transaction')
	}
}

pub fn (mut transaction IDBTransaction) object_store(name string) !IDBObjectStore {
	if transaction.state in [.finished, .aborted] {
		return error('InvalidStateError: transaction has finished')
	}
	if name !in transaction.scope_names || name !in transaction.database.data.stores {
		return error('NotFoundError: object store is not in the transaction scope')
	}
	store := transaction.database.data.stores[name] or {
		return error('NotFoundError: object store is not in the transaction scope')
	}
	return IDBObjectStore{
		transaction: &transaction
		name_:       name
		store_:      store
	}
}

pub fn (mut transaction IDBTransaction) commit() ! {
	if transaction.state != .active {
		return error('InvalidStateError: transaction is not active')
	}
	commit_a_transaction(mut transaction)!
}

pub fn (mut transaction IDBTransaction) abort(reason string) ! {
	if transaction.state in [.committing, .finished, .aborted] {
		return error('InvalidStateError: transaction is ending')
	}
	if transaction.mode != .readonly {
		transaction.revert_all_mutations()
		transaction.discard_mutation_logs()
	}
	transaction.error_message = reason
	transaction.aborted_ = true
	transaction.cleanup_event_loop_ = unsafe { nil }
	transaction.state = .aborted
	for mut request in transaction.request_list_.requests() {
		if request.ready_state == .pending {
			request.aborted = true
			request.processed = true
			queue_a_database_task_for_global_scope(request.global_scope, fn [mut request] () {
				request.result_kind = .undefined
				request.fail('AbortError: transaction aborted')
			})
		}
	}
	transaction.request_list_.clear_on_all_processed()
	transaction_pointer := voidptr(&transaction)
	queue_a_database_task_for_global_scope(transaction.relevant_global_scope(), fn [transaction_pointer] () {
		mut transaction := unsafe { &IDBTransaction(transaction_pointer) }
		if transaction.mode == .versionchange { transaction.database.data.upgrade_transaction = none }
		transaction.events << 'abort'
		if callback := transaction.onabort_ { callback() }
		transaction.finish_connection_if_needed()
		if callback := transaction.aborted_callback_ {
			transaction.aborted_callback_ = none
			callback()
		}
	})
}

fn (mut transaction IDBTransaction) finish_connection_if_needed() {
	unsafe {
		mut connection := transaction.database
		if connection.state == .closing && !connection.transactions.any(it.state !in [
			.finished,
			.aborted,
		]) {
			connection.finish_close()
		}
	}
}

pub fn (mut transaction IDBTransaction) deactivate() {
	if transaction.state == .active {
		transaction.state = .inactive
	}
}

pub fn (mut transaction IDBTransaction) activate() {
	if transaction.state == .inactive {
		transaction.state = .active
	}
}
