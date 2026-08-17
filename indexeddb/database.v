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

@[heap]
pub struct DatabaseData {
pub:
	name        string
	storage_key string
pub mut:
	version        u64
	stores         map[string]ObjectStoreData
	connections    int
	delete_pending bool
}

fn (database &DatabaseData) clone_stores() map[string]ObjectStoreData {
	mut stores := map[string]ObjectStoreData{}
	for name, store in database.stores {
		stores[name] = store.clone()
	}
	return stores
}

@[heap]
pub struct IDBDatabase {
pub mut:
	data           &DatabaseData
	state          ConnectionState = .open
	upgrade_active bool
	transactions   []&IDBTransaction
	events         []string
}

fn new_connection(data &DatabaseData) &IDBDatabase {
	unsafe {
		data.connections++
	}
	return &IDBDatabase{
		data: data
	}
}

pub fn (database &IDBDatabase) name() string {
	return database.data.name
}

pub fn (database &IDBDatabase) version() u64 {
	return database.data.version
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
	if database.data.connections > 0 {
		database.data.connections--
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
	if database.state != .open {
		return error('InvalidStateError: database connection is closing')
	}
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
	database.data.stores[name] = ObjectStoreData{
		name:           name
		key_path:       parameters.key_path
		auto_increment: parameters.auto_increment
		indexes:        map[string]IndexData{}
	}
	if name !in transaction.scope_names {
		transaction.scope_names << name
		sort_name_list(mut transaction.scope_names)
	}
	return IDBObjectStore{
		transaction: &transaction
		name_:       name
	}
}

pub fn (mut database IDBDatabase) delete_object_store(mut transaction IDBTransaction, name string) ! {
	transaction.require_versionchange_active()!
	if name !in database.data.stores {
		return error('NotFoundError: object store not found')
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
	database.transactions << transaction
	return transaction
}
