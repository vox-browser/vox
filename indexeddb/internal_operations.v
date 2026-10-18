// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Internal IndexedDB database, object-store, index, mutation-log, connection
// queue, and request-iterator entry points.
@[has_globals]
module indexeddb

__global (
	indexeddb_database_registry = map[string]&DatabaseData{}
	indexeddb_connection_queues = map[string]&RequestList{}
)

fn database_registry_key(storage_key string, name string) string {
	return '${storage_key.len}:${storage_key}${name}'
}

fn idb_has_databases() bool {
	return indexeddb_database_registry.len > 0
}

pub fn idb_databases() map[string]&DatabaseData {
	return indexeddb_database_registry.clone()
}

pub type DatabaseVisitor = fn (&DatabaseData)

pub fn DatabaseData.for_each_database(visitor DatabaseVisitor) {
	for _, database in indexeddb_database_registry {
		visitor(database)
	}
}

pub fn DatabaseData.create(name string) &DatabaseData {
	return &DatabaseData{
		name:   name
		stores: map[string]&ObjectStoreData{}
	}
}

pub fn (database &DatabaseData) object_store_with_name(name string) ?&ObjectStoreData {
	return database.stores[name] or { none }
}

pub fn DatabaseData.for_key(storage_key string) []&DatabaseData {
	mut result := []&DatabaseData{}
	for _, database in indexeddb_database_registry {
		if database.storage_key == storage_key {
			result << database
		}
	}
	return result
}

pub fn DatabaseData.for_key_and_name(storage_key string, name string) ?&DatabaseData {
	return indexeddb_database_registry[database_registry_key(storage_key, name)] or { none }
}

pub fn DatabaseData.create_for_key_and_name(storage_key string, name string) &DatabaseData {
	key := database_registry_key(storage_key, name)
	if existing := indexeddb_database_registry[key] {
		return existing
	}
	database := &DatabaseData{
		name:        name
		storage_key: storage_key
		stores:      map[string]&ObjectStoreData{}
	}
	indexeddb_database_registry[key] = database
	return database
}

pub fn DatabaseData.delete_for_key_and_name(storage_key string, name string) {
	indexeddb_database_registry.delete(database_registry_key(storage_key, name))
}

pub fn (database &DatabaseData) associated_connections_as_heap_vector() []&IDBDatabase {
	return database.associated_connections.clone()
}

pub fn (database &DatabaseData) associated_connections_as_root_vector() []&IDBDatabase {
	return database.associated_connections.clone()
}

pub fn (database &DatabaseData) associated_connections_as_heap_vector_except(connection &IDBDatabase) []&IDBDatabase {
	return database.associated_connections.filter(voidptr(it) != voidptr(connection))
}

pub fn (database &DatabaseData) wait_for_connections_to_close() bool {
	return database.associated_connections.all(it.state == .closed)
}

pub fn (mut database DatabaseData) check_pending_connection_wait() bool {
	wait := database.pending_connection_wait_ or { return true }
	if !wait.connections.all(it.state == .closed) {
		return false
	}
	database.pending_connection_wait_ = none
	queue_a_database_task_for_global_scope(wait.global_scope, wait.callback)
	return true
}

fn (mut database DatabaseData) wait_for_connection_set_to_close(connections []&IDBDatabase, global_scope &IndexedDBGlobalScope, callback DatabaseTask) {
	if connections.all(it.state == .closed) {
		queue_a_database_task_for_global_scope(global_scope, callback)
		return
	}
	assert database.pending_connection_wait_ == none
	database.pending_connection_wait_ = PendingConnectionWait{
		connections: connections.clone()
		global_scope: global_scope
		callback:    callback
	}
}

pub fn (mut database DatabaseData) set_version(version u64) {
	database.version = version
}

pub fn (database &DatabaseData) database_version() u64 {
	return database.version
}

pub fn (database &DatabaseData) database_name() string {
	return database.name
}

pub fn (mut database DatabaseData) set_upgrade_transaction(transaction ?&IDBTransaction) {
	database.upgrade_transaction = transaction
}

pub fn (database &DatabaseData) upgrade_transaction() ?&IDBTransaction {
	return database.upgrade_transaction
}

pub fn (mut database DatabaseData) associate(connection &IDBDatabase) {
	if !database.associated_connections.any(voidptr(it) == voidptr(connection)) {
		database.associated_connections << connection
		database.connections = database.associated_connections.len
	}
}

pub fn (mut database DatabaseData) dissociate(connection &IDBDatabase) {
	database.associated_connections = database.associated_connections.filter(voidptr(it) != voidptr(connection))
	database.connections = database.associated_connections.len
}

// Database is the direct spelling of upstream's internal Database class.
// DatabaseData remains the storage representation used throughout the V port.
pub struct Database {
pub mut:
	data &DatabaseData
}

pub fn Database.from_data(data &DatabaseData) Database {
	return Database{
		data: data
	}
}

pub fn (mut database Database) dissociate(connection &IDBDatabase) {
	unsafe {
		database.data.dissociate(connection)
	}
}

pub fn (database &DatabaseData) object_stores() []&ObjectStoreData {
	return database.stores.values()
}

pub fn (mut database DatabaseData) add_object_store(store &ObjectStoreData) {
	mut stored := unsafe { &ObjectStoreData(store) }
	stored.database_ = &database
	for _, mut index in stored.indexes {
		index.object_store_ = stored
	}
	database.stores[store.name] = stored
}

pub fn (mut database DatabaseData) remove_object_store(name string) {
	database.stores.delete(name)
}

pub struct ConnectionQueueHandler {}

pub fn ConnectionQueueHandler.the() ConnectionQueueHandler {
	return ConnectionQueueHandler{}
}

pub fn (handler ConnectionQueueHandler) for_key_and_name(storage_key string, name string) &RequestList {
	_ = handler
	key := database_registry_key(storage_key, name)
	if queue := indexeddb_connection_queues[key] {
		return queue
	}
	queue := &RequestList{}
	indexeddb_connection_queues[key] = queue
	return queue
}

pub fn ObjectStoreData.create(name string, auto_increment bool, key_path ?KeyPath) &ObjectStoreData {
	return &ObjectStoreData{
		name:           name
		key_path:       key_path
		auto_increment: auto_increment
		indexes:        map[string]&IndexData{}
	}
}

pub fn (store &ObjectStoreData) mutation_log_position() usize {
	log := store.mutation_log_ or { return 0 }
	return log.position()
}

pub fn (mut store ObjectStoreData) revert_mutations_from(position usize) {
	if mut log := store.mutation_log_ {
		log.revert_from(mut store, position)
	}
}

pub fn (mut store ObjectStoreData) remove_records_in_range(range IDBKeyRange) []ObjectStoreRecord {
	if store.records.len == 0 {
		return []ObjectStoreRecord{}
	}
	record_range := record_range_for_key_range(store.records, range)
	mut removed := []ObjectStoreRecord{}
	for i := record_range.start; i < record_range.end; i++ {
		removed << store.records[i]
	}
	if removed.len > 0 {
		if mut log := store.mutation_log_ {
			log.note_records_deleted(removed)
		}
		store.records.delete_many(record_range.start, record_range.end - record_range.start)
	}
	return removed
}

pub fn (mut store ObjectStoreData) remove_record_with_key(key Key) bool {
	position := find_record(store.records, key)
	if position < 0 {
		return false
	}
	store.records.delete(position)
	return true
}

pub fn (store &ObjectStoreData) has_record_with_key(key Key) bool {
	return find_record(store.records, key) >= 0
}

pub fn (mut store ObjectStoreData) store_a_record(record ObjectStoreRecord) ! {
	ensure_valid_key(record.key)!
	if mut log := store.mutation_log_ {
		log.note_record_stored(record.key)
	}
	position := first_record_index_with_key_at_or_after(store.records, record.key, false)
	store.records.insert(position, ObjectStoreRecord{
		key:   record.key
		value: record.value
	})
}

pub fn (store &ObjectStoreData) count_records_in_range(range IDBKeyRange) u64 {
	record_range := record_range_for_key_range(store.records, range)
	return u64(record_range.end - record_range.start)
}

pub fn (store &ObjectStoreData) first_in_range(range IDBKeyRange) ?ObjectStoreRecord {
	record_range := record_range_for_key_range(store.records, range)
	if record_range.start == record_range.end {
		return none
	}
	return store.records[record_range.start]
}

pub fn (mut store ObjectStoreData) clear_records() {
	if mut log := store.mutation_log_ {
		log.note_records_deleted(store.records)
	}
	store.records.clear()
}

pub fn (mut store ObjectStoreData) generate_a_key() !u64 {
	old_value := store.key_generator.current_number
	key := store.key_generator.generate()!
	if mut log := store.mutation_log_ {
		log.note_key_generator_changed(old_value)
	}
	return u64(key.number)
}

pub fn (mut store ObjectStoreData) possibly_update_the_key_generator(key Key) {
	old := store.key_generator.current_number
	store.key_generator.possibly_update(key)
	if old != store.key_generator.current_number {
		if mut log := store.mutation_log_ {
			log.note_key_generator_changed(old)
		}
	}
}

pub fn (store &ObjectStoreData) first_n_in_range(range IDBKeyRange, count ?u32) []ObjectStoreRecord {
	requested := int(count or { u32(store.records.len) })
	limit := if requested == 0 { store.records.len } else { requested }
	mut result := []ObjectStoreRecord{}
	record_range := record_range_for_key_range(store.records, range)
	for i := record_range.start; i < record_range.end; i++ {
		result << store.records[i]
		if result.len == limit {
			break
		}
	}
	return result
}

pub fn (store &ObjectStoreData) last_n_in_range(range IDBKeyRange, count ?u32) []ObjectStoreRecord {
	requested := int(count or { u32(store.records.len) })
	limit := if requested == 0 { store.records.len } else { requested }
	mut result := []ObjectStoreRecord{}
	record_range := record_range_for_key_range(store.records, range)
	for i := record_range.end - 1; i >= record_range.start && result.len < limit; i-- {
		result << store.records[i]
	}
	return result
}

pub fn (store &ObjectStoreData) object_store_name() string {
	return store.name
}

pub fn (mut store ObjectStoreData) set_name(name string) {
	store.name = name
}

pub fn (store &ObjectStoreData) object_store_key_path() ?KeyPath {
	return store.key_path
}

pub fn (store &ObjectStoreData) uses_inline_keys() bool {
	return store.key_path != none
}

pub fn (store &ObjectStoreData) uses_out_of_line_keys() bool {
	return store.key_path == none
}

pub fn (store &ObjectStoreData) key_generator() KeyGenerator {
	return store.key_generator
}

pub fn (store &ObjectStoreData) uses_a_key_generator() bool {
	return store.auto_increment
}

pub fn (store &ObjectStoreData) object_store_index_set() map[string]&IndexData {
	return store.indexes.clone()
}

pub fn (store &ObjectStoreData) is_deleted() bool {
	return store.deleted
}

pub fn (mut store ObjectStoreData) set_deleted(deleted bool) {
	store.deleted = deleted
}

pub fn (store &ObjectStoreData) database() ?&DatabaseData {
	return store.database_
}

pub fn (store &ObjectStoreData) object_store_records() []ObjectStoreRecord {
	return store.records.clone()
}

pub fn (store &ObjectStoreData) mutation_log() ?&MutationLog {
	return store.mutation_log_
}

pub fn (mut store ObjectStoreData) set_mutation_log(log ?&MutationLog) {
	store.mutation_log_ = log
}

pub fn IndexData.create(name string, key_path KeyPath, unique bool, multi_entry bool) IndexData {
	return IndexData{ name: name, key_path: key_path, unique: unique, multi_entry: multi_entry }
}

pub fn (mut index IndexData) set_name(name string) {
	index.name = name
}

pub fn (index &IndexData) has_record_with_key(key Key) bool {
	return index.records.any(keys_equal(it.key, key))
}

pub fn (index &IndexData) referenced_value(record IndexRecord, store &ObjectStoreData) ?Value {
	position := find_record(store.records, record.primary_key)
	if position < 0 {
		return none
	}
	return store.records[position].value
}

pub fn (mut index IndexData) clear_records() {
	deleted := index.records.clone()
	if deleted.len > 0 {
		if store := index.object_store_ {
			if mut log := store.mutation_log_ {
				log.note_index_records_deleted(index, deleted)
			}
		}
	}
	index.records.clear()
}

pub fn (index &IndexData) first_in_range(range IDBKeyRange) ?IndexRecord {
	record_range := record_range_for_key_range(index.records, range)
	if record_range.start == record_range.end {
		return none
	}
	return index.records[record_range.start]
}

pub fn (index &IndexData) first_n_in_range(range IDBKeyRange, count ?u32) []IndexRecord {
	requested := int(count or { u32(index.records.len) })
	limit := if requested == 0 { index.records.len } else { requested }
	mut result := []IndexRecord{}
	record_range := record_range_for_key_range(index.records, range)
	for i := record_range.start; i < record_range.end; i++ {
		result << index.records[i]
		if result.len == limit {
			break
		}
	}
	return result
}

pub fn (index &IndexData) last_n_in_range(range IDBKeyRange, count ?u32) []IndexRecord {
	requested := int(count or { u32(index.records.len) })
	limit := if requested == 0 { index.records.len } else { requested }
	mut result := []IndexRecord{}
	record_range := record_range_for_key_range(index.records, range)
	for i := record_range.end - 1; i >= record_range.start && result.len < limit; i-- {
		result << index.records[i]
	}
	return result
}

pub fn (index &IndexData) count_records_in_range(range IDBKeyRange) u64 {
	record_range := record_range_for_key_range(index.records, range)
	return u64(record_range.end - record_range.start)
}

pub fn (mut index IndexData) store_a_record(record IndexRecord) ! {
	if store := index.object_store_ {
		if mut log := store.mutation_log_ {
			log.note_index_record_stored(index, record)
		}
	}
	index.records << record
	sort_index_records(mut index.records)
}

pub fn (mut index IndexData) remove_record(record IndexRecord) {
	for i, existing in index.records {
		if keys_equal(existing.key, record.key) && keys_equal(existing.primary_key, record.primary_key) {
			index.records.delete(i)
			return
		}
	}
}

pub fn (mut index IndexData) remove_records_with_value_in_range(range IDBKeyRange) {
	mut removed := []IndexRecord{}
	mut i := 0
	for i < index.records.len {
		if range.includes(index.records[i].primary_key) or { false } {
			removed << index.records[i]
			index.records.delete(i)
			continue
		}
		i++
	}
	if removed.len > 0 {
		if store := index.object_store_ {
			if mut log := store.mutation_log_ {
				log.note_index_records_deleted(index, removed)
			}
		}
	}
}

pub fn (index &IndexData) index_name() string {
	return index.name
}

pub fn (index &IndexData) index_unique() bool {
	return index.unique
}

pub fn (index &IndexData) index_multi_entry() bool {
	return index.multi_entry
}

pub fn (index &IndexData) object_store() string {
	return index.store_name
}

pub fn (index &IndexData) index_records() []IndexRecord {
	return index.records.clone()
}

pub fn (index &IndexData) index_key_path() KeyPath {
	return clone_key_path(index.key_path)
}

pub fn (index &IndexData) is_deleted() bool {
	return index.deleted
}

pub fn (mut index IndexData) set_deleted(deleted bool) {
	index.deleted = deleted
}

@[heap]
pub struct MutationLog {
mut:
	entries []MutationEntry
}

pub enum MutationEntryKind {
	object_store_created
	object_store_deleted
	object_store_renamed
	index_created
	index_deleted
	index_renamed
	key_generator_changed
	records_deleted
	record_stored
	index_records_deleted
	index_record_stored
}

pub struct MutationEntry {
	kind          MutationEntryKind
	old_name      string
	old_number    u64
	key           Key
	records       []ObjectStoreRecord
	index_name    string
	index         ?&IndexData
	index_records []IndexRecord
	index_record  IndexRecord
}

pub fn MutationLog.create() &MutationLog {
	return &MutationLog{}
}

pub fn (mut log MutationLog) note_object_store_created() {
	log.entries << MutationEntry{ kind: .object_store_created }
}

pub fn (mut log MutationLog) note_object_store_deleted() {
	log.entries << MutationEntry{ kind: .object_store_deleted }
}

pub fn (mut log MutationLog) note_object_store_renamed(old_name string) {
	log.entries << MutationEntry{ kind: .object_store_renamed, old_name: old_name }
}

pub fn (mut log MutationLog) note_index_created(index &IndexData) {
	log.entries << MutationEntry{ kind: .index_created, index_name: index.name }
}

pub fn (mut log MutationLog) note_index_deleted(index &IndexData) {
	log.entries << MutationEntry{ kind: .index_deleted, index_name: index.name, index: index }
}

pub fn (mut log MutationLog) note_index_renamed(index &IndexData, old_name string) {
	log.entries << MutationEntry{ kind: .index_renamed, index_name: index.name, old_name: old_name, index: index }
}

pub fn (mut log MutationLog) note_key_generator_changed(old_value u64) {
	log.entries << MutationEntry{ kind: .key_generator_changed, old_number: old_value }
}

pub fn (mut log MutationLog) note_records_deleted(records []ObjectStoreRecord) {
	mut copies := []ObjectStoreRecord{}
	for record in records {
		copies << record
	}
	log.entries << MutationEntry{ kind: .records_deleted, records: copies }
}

pub fn (mut log MutationLog) note_record_stored(key Key) {
	log.entries << MutationEntry{ kind: .record_stored, key: key }
}

pub fn (mut log MutationLog) note_index_records_deleted(index &IndexData, records []IndexRecord) {
	log.entries << MutationEntry{ kind: .index_records_deleted, index_name: index.name, index: index, index_records: records.clone() }
}

pub fn (mut log MutationLog) note_index_record_stored(index &IndexData, record IndexRecord) {
	log.entries << MutationEntry{ kind: .index_record_stored, index_name: index.name, index: index, index_record: record }
}

pub fn (log &MutationLog) append_changes(database_name string, object_store_name string, mut changes TransactionChanges) {
	mut stored_keys := []Key{}
	mut changed_keys := []Key{}
	mut deleted_keys := []Key{}

	for entry in log.entries {
		match entry.kind {
			.object_store_created {
				changes.added << TransactionChange{
					database_name:     database_name
					object_store_name: object_store_name
				}
			}
			.object_store_deleted {
				changes.deleted << TransactionChange{
					database_name:     database_name
					object_store_name: object_store_name
				}
			}
			.object_store_renamed {
				changes.deleted << TransactionChange{
					database_name:     database_name
					object_store_name: entry.old_name
				}
				changes.added << TransactionChange{
					database_name:     database_name
					object_store_name: object_store_name
				}
			}
			.records_deleted {
				for record in entry.records {
					if remove_mutation_key(mut stored_keys, record.key) {
						continue
					}
					remove_mutation_key(mut changed_keys, record.key)
					deleted_keys << record.key
				}
			}
			.record_stored {
				if remove_mutation_key(mut deleted_keys, entry.key) {
					changed_keys << entry.key
				} else {
					stored_keys << entry.key
				}
			}
			.index_created, .index_deleted, .index_renamed, .key_generator_changed,
			.index_records_deleted, .index_record_stored {
			}
		}
	}

	for key in stored_keys {
		changes.added << transaction_change_for_key(database_name, object_store_name, key)
	}
	for key in changed_keys {
		changes.changed << transaction_change_for_key(database_name, object_store_name, key)
	}
	for key in deleted_keys {
		changes.deleted << transaction_change_for_key(database_name, object_store_name, key)
	}
}

fn remove_mutation_key(mut keys []Key, key Key) bool {
	for index, existing in keys {
		if keys_equal(existing, key) {
			keys.delete(index)
			return true
		}
	}
	return false
}

fn transaction_change_for_key(database_name string, object_store_name string, key Key) TransactionChange {
	return TransactionChange{
		database_name:     database_name
		object_store_name: object_store_name
		key:               serialize_key_for_inspection(key)
	}
}

pub fn (mut log MutationLog) revert(mut store ObjectStoreData, database &DatabaseData, connection &IDBDatabase) {
	log.revert_entries(mut store, 0, database, connection)
}

pub fn (mut log MutationLog) revert_from(mut store ObjectStoreData, position usize) {
	log.revert_entries(mut store, position, none, none)
}

fn (mut log MutationLog) revert_entries(mut store ObjectStoreData, position usize, database ?&DatabaseData, connection ?&IDBDatabase) {
	if position >= usize(log.entries.len) {
		return
	}
	for i := log.entries.len - 1; i >= int(position); i-- {
		entry := log.entries[i]
		match entry.kind {
			.object_store_created {
				if database_value := database {
					mut mutable_database := unsafe { &DatabaseData(database_value) }
					mutable_database.stores.delete(store.name)
				}
				if connection_value := connection {
					mut mutable_connection := unsafe { &IDBDatabase(connection_value) }
					mutable_connection.object_store_handles.delete(store.name)
				}
			}
			.object_store_deleted {
				store.deleted = false
				for _, mut index in store.indexes {
					index.deleted = false
				}
				if database_value := database {
					mut mutable_database := unsafe { &DatabaseData(database_value) }
					mutable_database.stores[store.name] = &store
				}
			}
			.object_store_renamed {
				current_name := store.name
				store.name = entry.old_name
				if database_value := database {
					mut mutable_database := unsafe { &DatabaseData(database_value) }
					mutable_database.stores.delete(current_name)
					mutable_database.stores[entry.old_name] = &store
				}
			}
			.index_created {
				store.indexes.delete(entry.index_name)
			}
			.index_deleted {
				if mut index := entry.index {
					index.deleted = false
					store.indexes[index.name] = index
				}
			}
			.index_renamed {
				if mut index := entry.index {
					store.indexes.delete(index.name)
					index.name = entry.old_name
					store.indexes[entry.old_name] = index
				}
			}
			.key_generator_changed {
				store.key_generator.current_number = entry.old_number
			}
			.records_deleted {
				for record in entry.records {
					existing := find_record(store.records, record.key)
					if existing < 0 {
						store.records << record
					} else {
						store.records[existing] = record
					}
				}
				sort_object_store_records(mut store.records)
			}
			.record_stored {
				position_to_remove := find_record(store.records, entry.key)
				if position_to_remove >= 0 { store.records.delete(position_to_remove) }
			}
			.index_records_deleted {
				if mut index := entry.index {
					index.records << entry.index_records
					sort_index_records(mut index.records)
				}
			}
			.index_record_stored {
				if mut index := entry.index {
					index.remove_record(entry.index_record)
				}
			}
		}
	}
	log.entries.trim(int(position))
}

pub fn (mut log MutationLog) clear() {
	log.entries.clear()
}

pub fn (log &MutationLog) position() usize {
	return usize(log.entries.len)
}

pub struct RequestIterator {
	requests []&IDBRequest
mut:
	index int
}

pub fn (mut iterator RequestIterator) skip_null() {
	for iterator.index < iterator.requests.len && isnil(iterator.requests[iterator.index]) {
		iterator.index++
	}
}

pub fn (list &RequestList) begin() RequestIterator {
	return RequestIterator{
		requests: list.requests()
	}
}

pub fn (list &RequestList) end() RequestIterator {
	return RequestIterator{
		requests: list.requests()
		index:    list.length()
	}
}

pub fn (cursor &IDBCursor) idb_cursor_with_value_value() !Value {
	return cursor.value()
}
