// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Internal IndexedDB database, object-store, index, mutation-log, connection
// queue, and request-iterator entry points.
@[has_globals]
module indexeddb

__global (
	indexeddb_database_registry = map[string]&DatabaseData{}
)

fn database_registry_key(storage_key string, name string) string {
	return '${storage_key}\n${name}'
}

pub type DatabaseVisitor = fn (&DatabaseData)

pub fn DatabaseData.for_each_database(visitor DatabaseVisitor) {
	for _, database in indexeddb_database_registry {
		visitor(database)
	}
}

pub fn DatabaseData.create(name string) &DatabaseData {
	return &DatabaseData{
		name: name
		stores: map[string]ObjectStoreData{}
	}
}

pub fn (database &DatabaseData) object_store_with_name(name string) ?ObjectStoreData {
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
		name: name
		storage_key: storage_key
		stores: map[string]ObjectStoreData{}
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

pub fn (database &DatabaseData) check_pending_connection_wait() bool {
	return database.wait_for_connections_to_close()
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

pub fn (database &DatabaseData) object_stores() []ObjectStoreData {
	return database.stores.values().map(it.clone())
}

pub fn (mut database DatabaseData) add_object_store(store ObjectStoreData) {
	database.stores[store.name] = store.clone()
}

pub fn (mut database DatabaseData) remove_object_store(name string) {
	database.stores.delete(name)
}

pub struct ConnectionQueueHandler {}

pub fn ConnectionQueueHandler.the() ConnectionQueueHandler {
	return ConnectionQueueHandler{}
}

pub fn (handler ConnectionQueueHandler) for_key_and_name(storage_key string, name string) ?&DatabaseData {
	_ = handler
	return DatabaseData.for_key_and_name(storage_key, name)
}

pub fn ObjectStoreData.create(name string, auto_increment bool, key_path ?KeyPath) ObjectStoreData {
	return ObjectStoreData{
		name: name
		key_path: key_path
		auto_increment: auto_increment
		indexes: map[string]IndexData{}
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
	mut removed := []ObjectStoreRecord{}
	mut retained := []ObjectStoreRecord{}
	for record in store.records {
		if range.includes(record.key) or { false } {
			removed << ObjectStoreRecord{ key: record.key.clone(), value: record.value.clone() }
		} else {
			retained << record
		}
	}
	if mut log := store.mutation_log_ {
		log.note_records_deleted(removed)
	}
	store.records = retained
	rebuild_all_indexes(mut store) or {}
	return removed
}

pub fn (mut store ObjectStoreData) remove_record_with_key(key Key) bool {
	position := find_record(store.records, key)
	if position < 0 {
		return false
	}
	record := store.records[position]
	if mut log := store.mutation_log_ {
		log.note_records_deleted([record])
	}
	store.records.delete(position)
	rebuild_all_indexes(mut store) or {}
	return true
}

pub fn (store &ObjectStoreData) has_record_with_key(key Key) bool {
	return find_record(store.records, key) >= 0
}

pub fn (mut store ObjectStoreData) store_a_record(record ObjectStoreRecord) ! {
	ensure_valid_key(record.key)!
	position := find_record(store.records, record.key)
	if position >= 0 {
		if mut log := store.mutation_log_ {
			log.note_records_deleted([store.records[position]])
		}
		store.records[position] = ObjectStoreRecord{
			key: record.key.clone()
			value: record.value.clone()
		}
	} else {
		if mut log := store.mutation_log_ {
			log.note_record_stored(record.key)
		}
		store.records << ObjectStoreRecord{
			key: record.key.clone()
			value: record.value.clone()
		}
		sort_object_store_records(mut store.records)
	}
	rebuild_all_indexes(mut store)!
}

pub fn (store &ObjectStoreData) count_records_in_range(range IDBKeyRange) u64 {
	return u64(store.records.count(range.includes(it.key) or { false }))
}

pub fn (store &ObjectStoreData) first_in_range(range IDBKeyRange) ?ObjectStoreRecord {
	for record in store.records {
		if range.includes(record.key) or { false } {
			return ObjectStoreRecord{ key: record.key.clone(), value: record.value.clone() }
		}
	}
	return none
}

pub fn (mut store ObjectStoreData) clear_records() {
	if mut log := store.mutation_log_ {
		log.note_records_deleted(store.records)
	}
	store.records.clear()
	for _, mut index in store.indexes {
		index.records.clear()
	}
}

pub fn (mut store ObjectStoreData) generate_a_key() !u64 {
	key := store.key_generator.generate()!
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
	limit := int(count or { u32(store.records.len) })
	mut result := []ObjectStoreRecord{}
	for record in store.records {
		if range.includes(record.key) or { false } {
			result << ObjectStoreRecord{ key: record.key.clone(), value: record.value.clone() }
			if result.len == limit { break }
		}
	}
	return result
}

pub fn (store &ObjectStoreData) last_n_in_range(range IDBKeyRange, count ?u32) []ObjectStoreRecord {
	limit := int(count or { u32(store.records.len) })
	mut result := []ObjectStoreRecord{}
	for i := store.records.len - 1; i >= 0 && result.len < limit; i-- {
		record := store.records[i]
		if range.includes(record.key) or { false } {
			result << ObjectStoreRecord{ key: record.key.clone(), value: record.value.clone() }
		}
	}
	return result
}

pub fn (store &ObjectStoreData) object_store_name() string { return store.name }
pub fn (mut store ObjectStoreData) set_name(name string) { store.name = name }
pub fn (store &ObjectStoreData) object_store_key_path() ?KeyPath { return store.key_path }
pub fn (store &ObjectStoreData) uses_inline_keys() bool { return store.key_path != none }
pub fn (store &ObjectStoreData) uses_out_of_line_keys() bool { return store.key_path == none }
pub fn (store &ObjectStoreData) key_generator() KeyGenerator { return store.key_generator }
pub fn (store &ObjectStoreData) uses_a_key_generator() bool { return store.auto_increment }
pub fn (store &ObjectStoreData) object_store_index_set() map[string]IndexData { return store.indexes.clone() }
pub fn (store &ObjectStoreData) is_deleted() bool { return store.deleted }
pub fn (mut store ObjectStoreData) set_deleted(deleted bool) { store.deleted = deleted }
pub fn (store &ObjectStoreData) database() ?&DatabaseData { return store.database_ }
pub fn (store &ObjectStoreData) object_store_records() []ObjectStoreRecord { return store.records.clone() }
pub fn (store &ObjectStoreData) mutation_log() ?&MutationLog { return store.mutation_log_ }
pub fn (mut store ObjectStoreData) set_mutation_log(log ?&MutationLog) { store.mutation_log_ = log }

pub fn IndexData.create(name string, key_path KeyPath, unique bool, multi_entry bool) IndexData {
	return IndexData{name: name, key_path: key_path, unique: unique, multi_entry: multi_entry}
}

pub fn (mut index IndexData) set_name(name string) { index.name = name }
pub fn (index &IndexData) has_record_with_key(key Key) bool { return index.records.any(keys_equal(it.key, key)) }
pub fn (index &IndexData) referenced_value(record IndexRecord, store &ObjectStoreData) ?Value {
	position := find_record(store.records, record.primary_key)
	if position < 0 { return none }
	return store.records[position].value.clone()
}
pub fn (mut index IndexData) clear_records() { index.records.clear() }
pub fn (index &IndexData) first_in_range(range IDBKeyRange) ?IndexRecord {
	for record in index.records { if range.includes(record.key) or { false } { return record } }
	return none
}
pub fn (index &IndexData) first_n_in_range(range IDBKeyRange, count ?u32) []IndexRecord {
	limit := int(count or { u32(index.records.len) })
	mut result := []IndexRecord{}
	for record in index.records { if range.includes(record.key) or { false } { result << record; if result.len == limit { break } } }
	return result
}
pub fn (index &IndexData) last_n_in_range(range IDBKeyRange, count ?u32) []IndexRecord {
	limit := int(count or { u32(index.records.len) })
	mut result := []IndexRecord{}
	for i := index.records.len - 1; i >= 0 && result.len < limit; i-- { if range.includes(index.records[i].key) or { false } { result << index.records[i] } }
	return result
}
pub fn (index &IndexData) count_records_in_range(range IDBKeyRange) u64 { return u64(index.records.count(range.includes(it.key) or { false })) }
pub fn (mut index IndexData) store_a_record(record IndexRecord) ! {
	if index.unique && index.records.any(keys_equal(it.key, record.key) && !keys_equal(it.primary_key, record.primary_key)) { return error('ConstraintError: duplicate index key') }
	if !index.records.any(keys_equal(it.key, record.key) && keys_equal(it.primary_key, record.primary_key)) { index.records << record; sort_index_records(mut index.records) }
}
pub fn (mut index IndexData) remove_record(record IndexRecord) { index.records = index.records.filter(!(keys_equal(it.key, record.key) && keys_equal(it.primary_key, record.primary_key))) }
pub fn (mut index IndexData) remove_records_with_value_in_range(range IDBKeyRange) { index.records = index.records.filter(!(range.includes(it.primary_key) or { false })) }
pub fn (index &IndexData) index_name() string { return index.name }
pub fn (index &IndexData) index_unique() bool { return index.unique }
pub fn (index &IndexData) index_multi_entry() bool { return index.multi_entry }
pub fn (index &IndexData) object_store() string { return index.store_name }
pub fn (index &IndexData) index_records() []IndexRecord { return index.records.clone() }
pub fn (index &IndexData) index_key_path() KeyPath { return clone_key_path(index.key_path) }
pub fn (index &IndexData) is_deleted() bool { return index.deleted }
pub fn (mut index IndexData) set_deleted(deleted bool) { index.deleted = deleted }

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
	kind              MutationEntryKind
	old_name          string
	old_number        u64
	key               Key
	records           []ObjectStoreRecord
	index_name        string
	index              ?IndexData
	index_records      []IndexRecord
	index_record       IndexRecord
	store_snapshot     ?&ObjectStoreData
}

pub fn MutationLog.create() &MutationLog {
	return &MutationLog{}
}

pub fn (mut log MutationLog) note_object_store_created() {
	log.entries << MutationEntry{kind: .object_store_created}
}

pub fn (mut log MutationLog) note_object_store_deleted(store ObjectStoreData) {
	mut snapshot := store.clone()
	log.entries << MutationEntry{kind: .object_store_deleted, store_snapshot: &snapshot}
}

pub fn (mut log MutationLog) note_object_store_renamed(_ ObjectStoreData, old_name string) {
	log.entries << MutationEntry{kind: .object_store_renamed, old_name: old_name}
}

pub fn (mut log MutationLog) note_index_created(_ ObjectStoreData, index IndexData) {
	log.entries << MutationEntry{kind: .index_created, index_name: index.name}
}

pub fn (mut log MutationLog) note_index_deleted(_ ObjectStoreData, index IndexData) {
	log.entries << MutationEntry{kind: .index_deleted, index_name: index.name, index: index.clone()}
}

pub fn (mut log MutationLog) note_index_renamed(_ ObjectStoreData, index IndexData, old_name string) {
	log.entries << MutationEntry{kind: .index_renamed, index_name: index.name, old_name: old_name}
}

pub fn (mut log MutationLog) note_key_generator_changed(old_value u64) {
	log.entries << MutationEntry{kind: .key_generator_changed, old_number: old_value}
}

pub fn (mut log MutationLog) note_records_deleted(records []ObjectStoreRecord) {
	mut copies := []ObjectStoreRecord{}
	for record in records {
		copies << ObjectStoreRecord{key: record.key.clone(), value: record.value.clone()}
	}
	log.entries << MutationEntry{kind: .records_deleted, records: copies}
}

pub fn (mut log MutationLog) note_record_stored(key Key) {
	log.entries << MutationEntry{kind: .record_stored, key: key.clone()}
}

pub fn (mut log MutationLog) note_index_records_deleted(index IndexData, records []IndexRecord) {
	log.entries << MutationEntry{kind: .index_records_deleted, index_name: index.name, index_records: records.clone()}
}

pub fn (mut log MutationLog) note_index_record_stored(index IndexData, record IndexRecord) {
	log.entries << MutationEntry{kind: .index_record_stored, index_name: index.name, index_record: record}
}
pub fn (mut log MutationLog) revert(mut store ObjectStoreData) { log.revert_entries(mut store, 0) }
pub fn (mut log MutationLog) revert_from(mut store ObjectStoreData, position usize) { log.revert_entries(mut store, position) }
pub fn (mut log MutationLog) revert_entries(mut store ObjectStoreData, position usize) {
	if position >= usize(log.entries.len) {
		return
	}
	for i := log.entries.len - 1; i >= int(position); i-- {
		entry := log.entries[i]
		match entry.kind {
			.object_store_created { store.deleted = true }
			.object_store_deleted {
				if snapshot := entry.store_snapshot { store = snapshot.clone() }
			}
			.object_store_renamed { store.name = entry.old_name }
			.index_created { store.indexes.delete(entry.index_name) }
			.index_deleted {
				if index := entry.index { store.indexes[index.name] = index.clone() }
			}
			.index_renamed {
				if mut index := store.indexes[entry.index_name] {
					store.indexes.delete(entry.index_name)
					index.name = entry.old_name
					store.indexes[entry.old_name] = index
				}
			}
			.key_generator_changed { store.key_generator.current_number = entry.old_number }
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
				if mut index := store.indexes[entry.index_name] {
					index.records << entry.index_records
					sort_index_records(mut index.records)
					store.indexes[entry.index_name] = index
				}
			}
			.index_record_stored {
				if mut index := store.indexes[entry.index_name] {
					index.remove_record(entry.index_record)
					store.indexes[entry.index_name] = index
				}
			}
		}
	}
	log.entries = log.entries[..int(position)].clone()
}
pub fn (mut log MutationLog) clear() { log.entries.clear() }
pub fn (log &MutationLog) position() usize { return usize(log.entries.len) }

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
		index: list.length()
	}
}

pub fn (cursor &IDBCursor) idb_cursor_with_value_value() !Value { return cursor.value() }
