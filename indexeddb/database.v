// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IDBDatabase.{h,cpp,idl}, ConnectionState.h, and
// Internal/Database.{h,cpp}.
module indexeddb

pub enum ConnectionState {
	open
	closing
	closed
}

struct PendingConnectionWait {
	connections []&IDBDatabase
	global_scope &IndexedDBGlobalScope
	callback    DatabaseTask = unsafe { nil }
}

@[heap]
pub struct DatabaseData {
mut:
	pending_connection_wait_ ?PendingConnectionWait
pub:
	name        string
	storage_key string
pub mut:
	version                u64
	stores                 map[string]&ObjectStoreData
	connections            int
	delete_pending         bool
	associated_connections []&IDBDatabase
	upgrade_transaction    ?&IDBTransaction
}

@[heap]
pub struct IDBDatabase {
mut:
	version_ u64
pub mut:
	data                   &DatabaseData
	global_scope           &IndexedDBGlobalScope
	state                  ConnectionState = .open
	upgrade_active         bool
	transactions           []&IDBTransaction
	events                 []string
	version_change_events  []IDBVersionChangeEvent
	document_url           string
	devtools_active        bool
	devtools_notifications []IndexedDBDevtoolsNotification
	object_store_handles   map[string]IDBObjectStore
	onabort_               ?IDBEventHandler
	onerror_               ?IDBEventHandler
	onclose_               ?IDBEventHandler
	onversionchange_       ?IDBEventHandler
}

fn new_connection(data &DatabaseData) &IDBDatabase {
	return new_connection_for_global_scope(data, IndexedDBGlobalScope.create(data.storage_key))
}

fn new_connection_for_global_scope(data &DatabaseData, global_scope &IndexedDBGlobalScope) &IDBDatabase {
	unsafe {
		data.connections++
	}
	mut connection := &IDBDatabase{
		data:         data
		global_scope: global_scope
		version_:     data.version
	}
	unsafe {
		data.associated_connections << connection
	}
	return connection
}

pub fn (database &IDBDatabase) name() string {
	return database.data.name
}

pub fn (database &IDBDatabase) version() u64 {
	return database.version_
}

pub fn (database &IDBDatabase) object_store_names() []string {
	mut names := database.data.stores.keys()
	sort_name_list(mut names)
	return names
}

pub fn (mut database IDBDatabase) close() {
	if database.state != .open {
		return
	}
	database.state = .closing
	if !database.transactions.any(it.state !in [.finished, .aborted]) {
		database.finish_close()
	}
}

fn (mut database IDBDatabase) finish_close() {
	if database.state == .closed {
		return
	}
	database.state = .closed
	unsafe {
		database.data.dissociate(&database)
		database.data.check_pending_connection_wait()
	}
}

pub struct IDBObjectStoreParameters {
pub:
	key_path       ?KeyPath
	auto_increment bool
}

pub struct IDBTransactionOptions {
pub:
	durability IDBTransactionDurability
}

pub fn (mut database IDBDatabase) create_object_store(mut transaction IDBTransaction, name string, parameters IDBObjectStoreParameters) !IDBObjectStore {
	transaction.require_versionchange_active()!
	if path := parameters.key_path {
		if !is_valid_key_path(path) {
			return error('SyntaxError: invalid object store key path')
		}
	}
	if name in database.data.stores {
		return error('ConstraintError: object store already exists')
	}
	if parameters.auto_increment {
		if path := parameters.key_path {
			match path {
				[]string {
					return error('InvalidAccessError: autoIncrement cannot use a sequence key path')
				}
				string {
					if path == '' {
						return error('InvalidAccessError: autoIncrement cannot use an empty key path')
					}
				}
			}
		}
	}
	mut object_store := &ObjectStoreData{
		name:           name
		key_path:       parameters.key_path
		auto_increment: parameters.auto_increment
		indexes:        map[string]&IndexData{}
		database_:      database.data
	}
	database.data.stores[name] = object_store
	transaction.set_up_mutation_log_for_new_store(object_store)
	if name !in transaction.scope_names {
		transaction.scope_names << name
		sort_name_list(mut transaction.scope_names)
	}
	return IDBObjectStore{
		transaction: &transaction
		name_:       name
		store_:      object_store
	}
}

pub fn (mut database IDBDatabase) delete_object_store(mut transaction IDBTransaction, name string) ! {
	transaction.require_versionchange_active()!
	if name !in database.data.stores {
		return error('NotFoundError: object store not found')
	}
	mut store := database.data.stores[name] or { return error('NotFoundError: object store not found') }
	if mut log := store.mutation_log_ {
		log.note_object_store_deleted()
	}
	store.deleted = true
	for _, mut index in store.indexes {
		index.deleted = true
	}
	database.data.stores.delete(name)
	transaction.scope_names = transaction.scope_names.filter(it != name)
}

pub fn (mut database IDBDatabase) transaction(store_names []string, mode IDBTransactionMode, options IDBTransactionOptions) !&IDBTransaction {
	if database.upgrade_active {
		return error('InvalidStateError: an upgrade transaction is active')
	}
	if database.state != .open {
		return error('InvalidStateError: database connection is closing')
	}
	if store_names.len == 0 {
		return error('InvalidAccessError: transaction scope is empty')
	}
	mut unique_names := map[string]bool{}
	for name in store_names {
		if name !in database.data.stores {
			return error('NotFoundError: object store ${name} does not exist')
		}
		unique_names[name] = true
	}
	mut normalized := unique_names.keys()
	sort_name_list(mut normalized)
	if mode == .versionchange {
		return error('TypeError: versionchange transactions cannot be created directly')
	}
	mut transaction := IDBTransaction.create(&database, mode, options.durability, normalized)
	transaction.set_cleanup_event_loop(database.global_scope.event_loop_handle)
	return transaction
}
