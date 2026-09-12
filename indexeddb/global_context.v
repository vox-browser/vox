// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// The browser embedding supplies separate EventTarget, global-scope, and
// environment-settings views of one realm. The standalone V boundary keeps
// their shared identity in this compact context record.
module indexeddb

@[heap]
pub struct IndexedDBGlobalScope {
pub:
	storage_key string
	identifier  string
}

pub fn IndexedDBGlobalScope.create(storage_key string) &IndexedDBGlobalScope {
	return &IndexedDBGlobalScope{
		storage_key: storage_key
		identifier: 'indexeddb:${storage_key}'
	}
}

pub fn IDBFactory.create_for_global_scope(global_scope &IndexedDBGlobalScope) !&IDBFactory {
	if global_scope.storage_key == '' {
		return error('SecurityError: failed to obtain a storage key')
	}
	return &IDBFactory{
		storage_key: global_scope.storage_key
		global_scope: global_scope
		databases: map[string]&DatabaseData{}
	}
}

pub fn (factory &IDBFactory) relevant_global_scope() &IndexedDBGlobalScope {
	return factory.global_scope
}

pub fn (factory &IDBFactory) relevant_global_object() &IndexedDBGlobalScope {
	return factory.relevant_global_scope()
}

pub fn (factory &IDBFactory) relevant_settings_object() &IndexedDBGlobalScope {
	return factory.relevant_global_scope()
}

pub fn (database &IDBDatabase) relevant_global_scope() &IndexedDBGlobalScope {
	return database.global_scope
}

pub fn (database &IDBDatabase) relevant_global_object() &IndexedDBGlobalScope {
	return database.relevant_global_scope()
}

pub fn (transaction &IDBTransaction) relevant_global_scope() &IndexedDBGlobalScope {
	return transaction.database.relevant_global_scope()
}

pub fn (transaction &IDBTransaction) relevant_global_object() &IndexedDBGlobalScope {
	return transaction.database.relevant_global_object()
}

pub fn (request &IDBRequest) relevant_global_scope() &IndexedDBGlobalScope {
	return request.global_scope
}

pub fn (request &IDBRequest) relevant_global_object() &IndexedDBGlobalScope {
	return request.relevant_global_scope()
}

pub fn (store &IDBObjectStore) relevant_global_object() &IndexedDBGlobalScope {
	return store.transaction.relevant_global_object()
}

pub fn (index &IDBIndex) relevant_global_object() &IndexedDBGlobalScope {
	return index.transaction.relevant_global_object()
}

pub fn (cursor &IDBCursor) relevant_global_object() &IndexedDBGlobalScope {
	return cursor.transaction.relevant_global_object()
}
