// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Entry points for connection, transaction, object-store, index, and cursor
// handles. Handle caches keep identity stable within a transaction, matching
// IndexedDB's get-or-create object-store/index handle rules.
module indexeddb

pub type ObjectStoreHandleCallback = fn (IDBObjectStore)

pub fn IDBDatabase.create(data &DatabaseData) &IDBDatabase {
	return new_connection(data)
}

pub fn (database &IDBDatabase) get_parent() voidptr {
	return unsafe { nil }
}

pub fn (mut database IDBDatabase) set_onabort(callback ?IDBEventHandler) {
	database.onabort_ = callback
}

pub fn (database &IDBDatabase) onabort() ?IDBEventHandler {
	return database.onabort_
}

pub fn (mut database IDBDatabase) set_onerror(callback ?IDBEventHandler) {
	database.onerror_ = callback
}

pub fn (database &IDBDatabase) onerror() ?IDBEventHandler {
	return database.onerror_
}

pub fn (mut database IDBDatabase) set_onclose(callback ?IDBEventHandler) {
	database.onclose_ = callback
}

pub fn (database &IDBDatabase) onclose() ?IDBEventHandler {
	return database.onclose_
}

pub fn (mut database IDBDatabase) set_onversionchange(callback ?IDBEventHandler) {
	database.onversionchange_ = callback
}

pub fn (database &IDBDatabase) onversionchange() ?IDBEventHandler {
	return database.onversionchange_
}

pub fn (mut database IDBDatabase) set_state(state ConnectionState) {
	database.state = state
}

pub fn (database &IDBDatabase) wait_for_transactions_to_finish() bool {
	return database.transactions.all(it.state in [.finished, .aborted])
}

pub fn (database &IDBDatabase) check_pending_transaction_waits() bool {
	return database.wait_for_transactions_to_finish()
}

pub fn (database &IDBDatabase) block_on_conflicting_transactions(transaction &IDBTransaction) bool {
	for other in database.transactions {
		if voidptr(other) == voidptr(transaction) || other.state in [.finished, .aborted] {
			continue
		}
		if transaction.mode == .readonly && other.mode == .readonly {
			continue
		}
		if transaction.scope_names.any(it in other.scope_names) {
			return true
		}
	}
	return false
}

pub fn (mut database IDBDatabase) set_version(version u64) {
	database.data.version = version
}

pub fn (database &IDBDatabase) close_pending() bool {
	return database.state != .open
}

pub fn (mut database IDBDatabase) set_close_pending(close_pending bool) {
	if close_pending && database.state == .open {
		database.state = .closing
	} else if !close_pending && database.state == .closing {
		database.state = .open
	}
}

pub fn (database &IDBDatabase) idb_database_uuid() string {
	return '${database.data.storage_key}:${database.data.name}'
}

pub fn (database &IDBDatabase) idb_database_state() ConnectionState {
	return database.state
}

pub fn (database &IDBDatabase) associated_database() &DatabaseData {
	return database.data
}

pub fn (database &IDBDatabase) object_store_set() map[string]IDBObjectStore {
	return database.object_store_handles.clone()
}

pub fn (mut database IDBDatabase) add_to_object_store_set(store IDBObjectStore) {
	database.object_store_handles[store.name_] = store
}

pub fn (mut database IDBDatabase) remove_from_object_store_set(name string) {
	database.object_store_handles.delete(name)
}

pub fn (database &IDBDatabase) idb_database_transactions() []&IDBTransaction {
	return database.transactions.clone()
}

pub fn (mut database IDBDatabase) add_transaction(transaction &IDBTransaction) {
	if !database.transactions.any(voidptr(it) == voidptr(transaction)) {
		database.transactions << transaction
	}
}

pub fn (transaction &IDBTransaction) get_parent() &IDBDatabase {
	return transaction.database
}

pub fn (mut transaction IDBTransaction) set_onabort(callback ?IDBEventHandler) {
	transaction.onabort_ = callback
}

pub fn (transaction &IDBTransaction) onabort() ?IDBEventHandler {
	return transaction.onabort_
}

pub fn (mut transaction IDBTransaction) set_oncomplete(callback ?IDBEventHandler) {
	transaction.oncomplete_ = callback
}

pub fn (transaction &IDBTransaction) oncomplete() ?IDBEventHandler {
	return transaction.oncomplete_
}

pub fn (mut transaction IDBTransaction) set_onerror(callback ?IDBEventHandler) {
	transaction.onerror_ = callback
}

pub fn (transaction &IDBTransaction) onerror() ?IDBEventHandler {
	return transaction.onerror_
}

pub fn (mut transaction IDBTransaction) object_store_named(name string) !IDBObjectStore {
	return transaction.get_or_create_object_store_handle(name)
}

pub fn (mut transaction IDBTransaction) get_or_create_object_store_handle(name string) !IDBObjectStore {
	if handle := transaction.object_store_handles[name] {
		return handle
	}
	handle := transaction.object_store(name)!
	transaction.object_store_handles[name] = handle
	return handle
}

pub fn (transaction &IDBTransaction) object_store_handle_for(name string) ?IDBObjectStore {
	return transaction.object_store_handles[name] or { none }
}

pub fn (mut transaction IDBTransaction) set_state(state TransactionState) {
	transaction.state = state
}

pub fn (mut transaction IDBTransaction) register_index_handle(index IDBIndex) {
	transaction.index_handles_ << index
}

pub fn (mut transaction IDBTransaction) set_up_mutation_logs() {
	transaction.original_version = transaction.database.data.version
	for name in transaction.scope_names {
		mut store := transaction.database.data.stores[name] or { continue }
		if transaction.store_mutation_logs.any(voidptr(it.store) == voidptr(store)) {
			continue
		}
		mut log := MutationLog.create()
		store.set_mutation_log(log)
		transaction.store_mutation_logs << StoreMutationLogEntry{
			store: store
			log: log
		}
	}
}

pub fn (mut transaction IDBTransaction) set_up_mutation_log_for_new_store(store &ObjectStoreData) {
	mut mutable_store := unsafe { &ObjectStoreData(store) }
	mut log := MutationLog.create()
	mutable_store.set_mutation_log(log)
	transaction.store_mutation_logs << StoreMutationLogEntry{
		store: store
		log: log
	}
	log.note_object_store_created()
}

pub fn (mut transaction IDBTransaction) revert_all_mutations() {
	for i := transaction.store_mutation_logs.len - 1; i >= 0; i-- {
		entry := transaction.store_mutation_logs[i]
		mut log := entry.log
		mut store := entry.store
		log.revert(mut store, transaction.database.data, transaction.database)
	}
	transaction.database.data.version = transaction.original_version
	if transaction.mode == .versionchange {
		transaction.scope_names = transaction.database.data.stores.keys()
		sort_name_list(mut transaction.scope_names)
	}
}

pub fn (mut transaction IDBTransaction) discard_mutation_logs() {
	for entry in transaction.store_mutation_logs {
		mut store := entry.store
		store.set_mutation_log(none)
	}
	transaction.store_mutation_logs.clear()
}

pub fn (mut transaction IDBTransaction) notify_devtools_of_committed_changes() {
	if transaction.database.document_url == '' || !transaction.database.devtools_active {
		return
	}
	mut changes := TransactionChanges{}
	for entry in transaction.store_mutation_logs {
		entry.log.append_changes(transaction.database.data.name, entry.store.name, mut changes)
	}
	if changes.is_empty() {
		return
	}
	unsafe {
		transaction.database.devtools_notifications << IndexedDBDevtoolsNotification{
			document_url: transaction.database.document_url
			changes: changes
		}
	}
}

pub fn (mut database IDBDatabase) set_devtools_inspection_context(document_url string, active bool) {
	database.document_url = document_url
	database.devtools_active = active
}

pub fn (transaction &IDBTransaction) transaction_mode() IDBTransactionMode {
	return transaction.mode
}

pub fn (transaction &IDBTransaction) transaction_state() TransactionState {
	return transaction.state
}

pub fn (transaction &IDBTransaction) transaction_error() string {
	return transaction.error_message
}

pub fn (transaction &IDBTransaction) connection() &IDBDatabase {
	return transaction.database
}

pub fn (transaction &IDBTransaction) transaction_durability() IDBTransactionDurability {
	return transaction.durability
}

pub fn (transaction &IDBTransaction) associated_request() ?&IDBRequest {
	return transaction.associated_request_
}

pub fn (transaction &IDBTransaction) transaction_aborted() bool {
	return transaction.aborted_
}

pub fn (transaction &IDBTransaction) request_list() &RequestList {
	return transaction.request_list_
}

pub fn (transaction &IDBTransaction) transaction_scope() []string {
	return transaction.scope_names.clone()
}

pub fn (transaction &IDBTransaction) transaction_uuid() string {
	return '${transaction.database.data.storage_key}:${transaction.database.data.name}:${transaction.mode}'
}

pub fn (transaction &IDBTransaction) cleanup_event_loop() voidptr {
	return transaction.cleanup_event_loop_
}

pub fn (mut transaction IDBTransaction) set_mode(mode IDBTransactionMode) {
	transaction.mode = mode
}

pub fn (mut transaction IDBTransaction) set_error(message string) {
	transaction.error_message = message
}

pub fn (mut transaction IDBTransaction) set_associated_request(request ?&IDBRequest) {
	transaction.associated_request_ = request
}

pub fn (mut transaction IDBTransaction) set_aborted(aborted bool) {
	transaction.aborted_ = aborted
}

pub fn (mut transaction IDBTransaction) set_cleanup_event_loop(event_loop voidptr) {
	transaction.cleanup_event_loop_ = event_loop
}

pub fn (transaction &IDBTransaction) is_upgrade_transaction() bool {
	return transaction.mode == .versionchange
}

pub fn (transaction &IDBTransaction) is_readonly() bool {
	return transaction.mode == .readonly
}

pub fn (transaction &IDBTransaction) is_readwrite() bool {
	return transaction.mode == .readwrite
}

pub fn (transaction &IDBTransaction) is_finished() bool {
	return transaction.state in [.finished, .aborted]
}

pub fn (transaction &IDBTransaction) is_active() bool {
	return transaction.state == .active
}

pub fn (transaction &IDBTransaction) is_inactive() bool {
	return transaction.state == .inactive
}

pub fn (transaction &IDBTransaction) is_committing() bool {
	return transaction.state == .committing
}

pub fn (mut transaction IDBTransaction) add_to_scope(name string) {
	if name !in transaction.scope_names {
		transaction.scope_names << name
		sort_name_list(mut transaction.scope_names)
	}
}

pub fn (mut transaction IDBTransaction) remove_from_scope(name string) {
	transaction.scope_names = transaction.scope_names.filter(it != name)
}

pub fn (mut transaction IDBTransaction) set_scope(scope []string) {
	transaction.scope_names = scope.clone()
	sort_name_list(mut transaction.scope_names)
}

pub fn (transaction &IDBTransaction) for_each_object_store_handle(callback ObjectStoreHandleCallback) {
	for _, handle in transaction.object_store_handles {
		callback(handle)
	}
}

pub fn (transaction &IDBTransaction) index_handles() []IDBIndex {
	return transaction.index_handles_.clone()
}

pub fn IDBObjectStore.create(transaction &IDBTransaction, name string) IDBObjectStore {
	return IDBObjectStore{
		transaction: transaction
		name_: name
		store_: transaction.database.data.stores[name] or { none }
	}
}

pub fn (mut store IDBObjectStore) set_name(name string) ! {
	store.rename(name)!
}

pub fn (store &IDBObjectStore) store_transaction() &IDBTransaction {
	return store.transaction
}

pub fn (mut store IDBObjectStore) delete_(range IDBKeyRange) !&IDBRequest {
	return store.delete(range)
}

pub fn (mut store IDBObjectStore) add_or_put(value Value, key ?Key, no_overwrite bool) !&IDBRequest {
	return store.store_record(value, key, no_overwrite)
}

pub fn (mut store IDBObjectStore) open_key_cursor(range ?IDBKeyRange, direction IDBCursorDirection) !&IDBRequest {
	return store.open_cursor(range, direction, true)
}

pub fn (store &IDBObjectStore) index_set() map[string]&IndexData {
	data := store.load() or { return map[string]&IndexData{} }
	return data.indexes.clone()
}

pub fn (store &IDBObjectStore) store() !&ObjectStoreData {
	return store.load()
}

pub fn (mut store IDBObjectStore) update_name(name string) ! {
	store.rename(name)!
}

pub fn (mut store IDBObjectStore) update_index_set(indexes map[string]&IndexData) ! {
	mut data := store.load()!
	data.indexes = indexes.clone()
}

pub fn IDBIndex.create(transaction &IDBTransaction, store_name string, name string) IDBIndex {
	store := transaction.database.data.stores[store_name] or { unsafe { nil } }
	object_store_handle := IDBObjectStore.create(transaction, store_name)
	return IDBIndex{
		transaction: transaction
		store_name: store_name
		name_: name
		store_: if isnil(store) { none } else { store }
		index_: if isnil(store) { none } else { store.indexes[name] or { none } }
		object_store_handle_: object_store_handle
	}
}

pub fn (mut index IDBIndex) set_name(name string) ! {
	index.rename(name)!
}

pub fn (mut index IDBIndex) open_key_cursor(range ?IDBKeyRange, direction IDBCursorDirection) !&IDBRequest {
	return index.open_cursor(range, direction, true)
}

pub fn (index &IDBIndex) object_store() IDBObjectStore {
	return index.object_store_handle_
}

pub fn (index &IDBIndex) index_transaction() &IDBTransaction {
	return index.transaction
}

pub fn (index &IDBIndex) index() !&IndexData {
	_, data := index.load()!
	return data
}

pub fn (mut index IDBIndex) update_name(name string) ! {
	index.rename(name)!
}

pub fn (cursor &IDBCursor) is_source_or_object_store_deleted() bool {
	cursor.validate_source() or { return true }
	return false
}

pub fn (cursor &IDBCursor) cursor_transaction() &IDBTransaction {
	return cursor.transaction
}

pub fn (cursor &IDBCursor) internal_source() string {
	return if cursor.index_name == '' { cursor.store_name } else { cursor.index_name }
}

pub fn (mut cursor IDBCursor) continue_(key ?Key) !bool {
	return cursor.continue_to(key)
}

pub fn (cursor &IDBCursor) effective_key() !Key {
	return cursor.key()
}

pub fn (cursor &IDBCursor) effective_object_store() IDBObjectStore {
	return IDBObjectStore.create(cursor.transaction, cursor.store_name)
}

pub fn (mut cursor IDBCursor) delete_() !&IDBRequest {
	return cursor.delete()
}

pub fn (cursor &IDBCursor) source_handle() string {
	return cursor.internal_source()
}

pub fn (cursor &IDBCursor) cursor_direction() IDBCursorDirection {
	return cursor.direction
}

pub fn (cursor &IDBCursor) cursor_request() &IDBRequest {
	return cursor.request
}

pub fn (cursor &IDBCursor) range() IDBKeyRange {
	return cursor.range_
}

pub fn (cursor &IDBCursor) cursor_position() ?Key {
	return if position := cursor.position_ { position.clone() } else { none }
}

pub fn (cursor &IDBCursor) object_store_position() ?Key {
	return if position := cursor.object_store_position_ { position.clone() } else { none }
}

pub fn (cursor &IDBCursor) key_only() bool {
	return !cursor.with_value
}

pub fn (cursor &IDBCursor) cursor_got_value() bool {
	return cursor.got_value
}

pub fn (mut cursor IDBCursor) set_request(request &IDBRequest) {
	cursor.request = request
}

pub fn (mut cursor IDBCursor) set_position(position ?Key) {
	cursor.position_ = if key := position { key.clone() } else { none }
}

pub fn (mut cursor IDBCursor) set_got_value(got_value bool) {
	cursor.got_value = got_value
}

pub fn (mut cursor IDBCursor) set_key(key ?Key) {
	if entry := cursor.current_entry {
		cursor.current_entry = CursorEntry{
			...entry
			key: if value := key { value.clone() } else { invalid_key() }
		}
	}
}

pub fn (mut cursor IDBCursor) set_value(value Value) {
	if entry := cursor.current_entry {
		cursor.current_entry = CursorEntry{
			...entry
			value: value.clone()
		}
	}
}

pub fn (mut cursor IDBCursor) set_object_store_position(position ?Key) {
	cursor.object_store_position_ = if key := position { key.clone() } else { none }
}
