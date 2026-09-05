// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IDBFactory.{h,cpp,idl} and connection/open/delete/database
// algorithms from Internal/Algorithms.{h,cpp} and
// Internal/ConnectionQueueHandler.h.
module indexeddb

pub struct IDBDatabaseInfo {
pub:
	name    string
	version u64
}

@[heap]
pub struct IDBFactory {
pub:
	storage_key string
pub mut:
	databases map[string]&DatabaseData
}

pub fn IDBFactory.create(storage_key string) !&IDBFactory {
	if storage_key == '' {
		return error('SecurityError: failed to obtain a storage key')
	}
	return &IDBFactory{
		storage_key: storage_key
		databases: map[string]&DatabaseData{}
	}
}

// https://w3c.github.io/IndexedDB/#dom-idbfactory-cmp
pub fn (factory &IDBFactory) cmp(first Key, second Key) !int {
	_ = factory
	return compare_two_keys(first, second)
}

// Opening is deterministic in the standalone runtime. A version change leaves
// an active transaction exposed on the request, corresponding to the browser's
// upgradeneeded callback. The caller applies schema changes then calls
// finish_upgrade (or abort_upgrade).
pub fn (mut factory IDBFactory) open(name string, requested_version ?u64) !&IDBOpenDBRequest {
	if version := requested_version {
		if version == 0 {
			return error('TypeError: version must not be zero')
		}
	}
	mut request := &IDBOpenDBRequest{
		request: IDBRequest.create('factory')
		factory: &factory
		database_name: name
	}
	if name !in factory.databases {
		if existing := DatabaseData.for_key_and_name(factory.storage_key, name) {
			factory.databases[name] = existing
		}
	}
	if name !in factory.databases {
		mut data := DatabaseData.create_for_key_and_name(factory.storage_key, name)
		factory.databases[name] = data
		mut connection := new_connection(data)
		request.connection = connection
		request.old_version = 0
		target := requested_version or { u64(1) }
		request.new_version = target
		mut upgrade := IDBTransaction.create(connection, .versionchange, .default_, [])
		connection.transactions << upgrade
		connection.upgrade_active = true
		data.version = target
		request.upgrade_transaction = upgrade
		request.request.events << 'upgradeneeded'
		return request
	}
	mut data := factory.databases[name] or { return error('UnknownError: database disappeared') }
	old_version := data.version
	target := requested_version or { old_version }
	if target < old_version {
		request.request.fail('VersionError: requested version is lower than database version')
		return request
	}
	mut connection := new_connection(data)
	request.connection = connection
	request.old_version = old_version
	request.new_version = target
	if target > old_version {
		// IDBTransaction::set_up_mutation_logs captures the pre-upgrade
		// version before the upgrade algorithm updates the database.
		data.version = old_version
		mut upgrade := IDBTransaction.create(connection, .versionchange, .default_, data.stores.keys())
		connection.transactions << upgrade
		connection.upgrade_active = true
		data.version = target
		request.upgrade_transaction = upgrade
		request.request.events << 'upgradeneeded'
	} else {
		request.request.succeed(.undefined)
	}
	return request
}

pub fn (mut request IDBOpenDBRequest) finish_upgrade() ! {
	if isnil(request.upgrade_transaction) {
		return error('InvalidStateError: request has no upgrade transaction')
	}
	unsafe {
		request.upgrade_transaction.commit()!
		request.connection.upgrade_active = false
	}
	request.request.succeed(.undefined)
}

pub fn (mut request IDBOpenDBRequest) abort_upgrade(reason string) ! {
	if isnil(request.upgrade_transaction) {
		return error('InvalidStateError: request has no upgrade transaction')
	}
	unsafe {
		request.upgrade_transaction.abort(reason)!
		request.connection.upgrade_active = false
		request.connection.close()
		if request.old_version == 0 && !isnil(request.factory) {
			request.factory.databases.delete(request.database_name)
			DatabaseData.delete_for_key_and_name(request.factory.storage_key, request.database_name)
		}
	}
	request.request.fail(if reason == '' { 'AbortError: upgrade aborted' } else { reason })
}

pub fn (mut factory IDBFactory) delete_database(name string) &IDBOpenDBRequest {
	mut request := &IDBOpenDBRequest{
		request: IDBRequest.create('factory')
		factory: &factory
		database_name: name
	}
	if name !in factory.databases {
		if existing := DatabaseData.for_key_and_name(factory.storage_key, name) {
			factory.databases[name] = existing
		}
	}
	if name !in factory.databases {
		request.request.succeed(.undefined)
		return request
	}
	mut data := factory.databases[name] or { return request }
	request.old_version = data.version
	if data.connections > 0 {
		data.delete_pending = true
		request.request.events << 'blocked'
		return request
	}
	factory.databases.delete(name)
	DatabaseData.delete_for_key_and_name(factory.storage_key, name)
	request.request.succeed(.undefined)
	return request
}

pub fn (mut factory IDBFactory) retry_delete(mut request IDBOpenDBRequest, name string) bool {
	if name !in factory.databases {
		if existing := DatabaseData.for_key_and_name(factory.storage_key, name) {
			factory.databases[name] = existing
		}
	}
	if name !in factory.databases {
		return false
	}
	data := factory.databases[name] or { return false }
	if data.connections > 0 {
		return false
	}
	factory.databases.delete(name)
	DatabaseData.delete_for_key_and_name(factory.storage_key, name)
	request.request.succeed(.undefined)
	return true
}

pub fn (factory &IDBFactory) database_infos() []IDBDatabaseInfo {
	mut result := []IDBDatabaseInfo{}
	for database in DatabaseData.for_key(factory.storage_key) {
		if database.version > 0 {
			result << IDBDatabaseInfo{
				name: database.name
				version: database.version
			}
		}
	}
	result.sort_with_compare(fn (a &IDBDatabaseInfo, b &IDBDatabaseInfo) int {
		return compare_utf16_code_units(a.name, b.name)
	})
	return result
}
