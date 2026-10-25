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
	storage_key  string
	global_scope &IndexedDBGlobalScope
pub mut:
	databases map[string]&DatabaseData
}

pub fn IDBFactory.create(storage_key string) !&IDBFactory {
	if storage_key == '' {
		return error('SecurityError: failed to obtain a storage key')
	}
	return IDBFactory.create_for_global_scope(IndexedDBGlobalScope.create(storage_key))
}

// https://w3c.github.io/IndexedDB/#dom-idbfactory-cmp
pub fn (factory &IDBFactory) cmp(first Key, second Key) !int {
	_ = factory
	return compare_two_keys(first, second)
}

// Internal/Algorithms.cpp:open_a_database_connection. Requests for the same
// storage key and name run in their shared connection queue.
pub fn (mut factory IDBFactory) open(name string, requested_version ?u64) !&IDBOpenDBRequest {
	if version := requested_version {
		if version == 0 {
			return error('TypeError: version must not be zero')
		}
	}
	if factory.storage_key == '' {
		return error('SecurityError: failed to obtain a storage key')
	}
	mut queue := ConnectionQueueHandler.the().for_key_and_name(factory.storage_key, name)
	request := &IDBOpenDBRequest{
		request:       IDBRequest.create_for_global_scope(factory.global_scope, 'factory')
		factory:       &factory
		database_name: name
		queue_:        queue
	}
	queue.enqueue(request.request, fn [request, requested_version] (mut _ IDBRequest) {
		mut pending := unsafe { &IDBOpenDBRequest(request) }
		pending.process_open(requested_version)
	})
	return request
}

fn (mut request IDBOpenDBRequest) process_open(requested_version ?u64) {
	request_ptr := voidptr(&request)
	mut factory := request.factory
	existing := DatabaseData.for_key_and_name(factory.storage_key, request.database_name)
	data_ptr := existing or { DatabaseData.create_for_key_and_name(factory.storage_key, request.database_name) }
	mut data := unsafe { &DatabaseData(data_ptr) }
	factory.databases[request.database_name] = data
	target := requested_version or { if existing == none { u64(1) } else { data.version } }
	request.old_version = data.version
	request.new_version = target
	if data.version > target {
		request.request.fail('VersionError: requested version is lower than database version')
		request.complete_connection_request()
		return
	}
	mut connection := new_connection_for_global_scope(data, factory.global_scope)
	connection.version_ = target
	request.connection = connection
	if data.version == target {
		request.request.database = connection
		request.request.succeed(.database)
		request.complete_connection_request()
		return
	}
	open_connections := data.associated_connections_as_heap_vector_except(connection)
	request.notify_connections_then_wait(open_connections, fn [request_ptr] () {
		mut pending := unsafe { &IDBOpenDBRequest(request_ptr) }
		pending.begin_upgrade()
	})
}

@[heap]
struct VersionChangeTaskCounter {
mut:
	remaining int
	after_all DatabaseTask = unsafe { nil }
}

// Internal/Algorithms.cpp:TaskCounterState and open/delete coordination.
fn (mut request IDBOpenDBRequest) notify_connections_then_wait(connections []&IDBDatabase, completion DatabaseTask) {
	request_ptr := voidptr(&request)
	global_scope := request.request.global_scope
	mut data := DatabaseData.for_key_and_name(request.factory.storage_key, request.database_name) or { return }
	after_all := fn [request_ptr, connections, data, completion, global_scope] () {
		if !connections.all(it.state == .closed) {
			queue_a_database_task_for_global_scope(global_scope, fn [request_ptr] () {
				mut blocked := unsafe { &IDBOpenDBRequest(request_ptr) }
				blocked.request.events << 'blocked'
				blocked.version_change_events << IDBVersionChangeEvent.create('blocked', blocked.old_version, blocked.new_version)
				if callback := blocked.onblocked_ { callback() }
			})
		}
		mut database := unsafe { &DatabaseData(data) }
		database.wait_for_connection_set_to_close(connections, global_scope, completion)
	}
	old_version := request.old_version
	new_version := request.new_version
	mut counter := &VersionChangeTaskCounter{ after_all: after_all }
	for connection in connections {
		if connection.state == .open {
			counter.remaining++
		}
	}
	if counter.remaining == 0 {
		queue_a_database_task_for_global_scope(global_scope, after_all)
		return
	}
	for connection in connections {
		if connection.state != .open { continue }
		queue_a_database_task_for_global_scope(global_scope, fn [old_version, new_version, connection, counter, global_scope] () {
			mut old_connection := unsafe { &IDBDatabase(connection) }
			fire_a_version_change_event(mut old_connection, old_version, new_version)
			mut task_counter := unsafe { &VersionChangeTaskCounter(counter) }
			task_counter.remaining--
			if task_counter.remaining == 0 {
				queue_a_database_task_for_global_scope(global_scope, task_counter.after_all)
			}
		})
	}
}

fn (mut request IDBOpenDBRequest) begin_upgrade() {
	mut connection := request.connection
	mut data := connection.data
	mut upgrade := IDBTransaction.create(connection, .versionchange, .default_, data.stores.keys())
	connection.upgrade_active = true
	data.upgrade_transaction = upgrade
	data.version = request.new_version or { data.version }
	request.upgrade_transaction = upgrade
	request.request.database = connection
	request.request.result_kind = .database
	request.request.transaction_ = upgrade
	request.request.events << 'upgradeneeded'
	request.version_change_events << IDBVersionChangeEvent.create('upgradeneeded', request.old_version, request.new_version)
	if callback := request.onupgradeneeded_ { callback() }
}

fn (mut request IDBOpenDBRequest) complete_connection_request() {
	if !isnil(request.queue_) {
		mut queue := request.queue_
		queue.on_request_processed()
	}
}

pub fn (mut request IDBOpenDBRequest) finish_upgrade() ! {
	request.prepare_upgrade_completion()!
	mut upgrade := request.upgrade_transaction
	upgrade.commit()!
}

// Install completion before firing the browser's upgrade event. Its queued
// requests may finish in later tasks and enqueue further requests from handlers.
pub fn (mut request IDBOpenDBRequest) prepare_upgrade_completion() ! {
	request_ptr := voidptr(&request)
	if isnil(request.upgrade_transaction) {
		return error('InvalidStateError: request has no upgrade transaction')
	}
	mut upgrade := request.upgrade_transaction
	upgrade.associated_request_ = request.request
	upgrade.committed_callback_ = fn [request_ptr] () {
		mut pending := unsafe { &IDBOpenDBRequest(request_ptr) }
		pending.connection.upgrade_active = false
		queue_a_database_task_for_global_scope(pending.request.global_scope, fn [request_ptr] () {
			mut completed := unsafe { &IDBOpenDBRequest(request_ptr) }
			if completed.connection.state == .closed {
				completed.request.fail('AbortError: Connection was closed')
			} else {
				completed.request.succeed(.database)
			}
			completed.complete_connection_request()
		})
	}
	upgrade.aborted_callback_ = fn [request_ptr] () {
		mut pending := unsafe { &IDBOpenDBRequest(request_ptr) }
		pending.abort_upgrade(pending.upgrade_transaction.error_message) or {}
	}
}

pub fn (mut request IDBOpenDBRequest) abort_upgrade(reason string) ! {
	request_ptr := voidptr(&request)
	if isnil(request.upgrade_transaction) {
		return error('InvalidStateError: request has no upgrade transaction')
	}
	if request.upgrade_abort_finished_ { return }
	request.upgrade_abort_finished_ = true
	mut upgrade := request.upgrade_transaction
	if upgrade.state != .aborted { upgrade.abort(reason)! }
	mut connection := request.connection
	connection.upgrade_active = false
	connection.data.upgrade_transaction = none
	connection.version_ = request.old_version
	connection.close()
	if request.old_version == 0 {
		request.factory.databases.delete(request.database_name)
		DatabaseData.delete_for_key_and_name(request.factory.storage_key, request.database_name)
	}
	request.request.transaction_ = none
	queue_a_database_task_for_global_scope(request.request.global_scope, fn [request_ptr, reason] () {
		mut completed := unsafe { &IDBOpenDBRequest(request_ptr) }
		completed.request.fail(if reason == '' { 'AbortError: upgrade aborted' } else { reason })
		completed.complete_connection_request()
	})
}

// Internal/Algorithms.cpp:delete_a_database shares the open connection queue.
pub fn (mut factory IDBFactory) delete_database(name string) !&IDBOpenDBRequest {
	if factory.storage_key == '' {
		return error('SecurityError: failed to obtain a storage key')
	}
	mut queue := ConnectionQueueHandler.the().for_key_and_name(factory.storage_key, name)
	request := &IDBOpenDBRequest{
		request:       IDBRequest.create_for_global_scope(factory.global_scope, 'factory')
		factory:       &factory
		database_name: name
		queue_:        queue
	}
	queue.enqueue(request.request, fn [request] (mut _ IDBRequest) {
		mut pending := unsafe { &IDBOpenDBRequest(request) }
		pending.process_delete()
	})
	return request
}

fn (mut request IDBOpenDBRequest) process_delete() {
	request_ptr := voidptr(&request)
	data := DatabaseData.for_key_and_name(request.factory.storage_key, request.database_name) or {
		request.request.succeed(.undefined)
		request.complete_connection_request()
		return
	}
	request.old_version = data.version
	request.new_version = none
	request.notify_connections_then_wait(data.associated_connections_as_heap_vector(), fn [request_ptr] () {
		mut pending := unsafe { &IDBOpenDBRequest(request_ptr) }
		pending.factory.databases.delete(pending.database_name)
		DatabaseData.delete_for_key_and_name(pending.factory.storage_key, pending.database_name)
		pending.request.succeed(.undefined)
		pending.complete_connection_request()
	})
}

// Kept for typed consumers; deletion now resumes from the connection-close task.
pub fn (mut factory IDBFactory) retry_delete(mut request IDBOpenDBRequest, name string) bool {
	_ = factory
	_ = name
	run_database_tasks()
	return request.request.ready_state == .done && request.request.error_message == ''
}

pub fn (factory &IDBFactory) database_infos() []IDBDatabaseInfo {
	mut result := []IDBDatabaseInfo{}
	for database in DatabaseData.for_key(factory.storage_key) {
		if database.version > 0 {
			result << IDBDatabaseInfo{
				name:    database.name
				version: database.version
			}
		}
	}
	result.sort_with_compare(fn (a &IDBDatabaseInfo, b &IDBDatabaseInfo) int {
		return compare_utf16_code_units(a.name, b.name)
	})
	return result
}
