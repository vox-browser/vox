// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IDBCursor.{h,cpp,idl} and IDBCursorWithValue.{h,idl}.
module indexeddb

pub enum IDBCursorDirection {
	next
	nextunique
	prev
	prevunique
}

pub struct CursorEntry {
pub:
	key         Key
	primary_key Key
	value       Value
}

pub struct IDBCursorWithValue {
pub:
	cursor &IDBCursor
}

pub fn IDBCursorWithValue.from_cursor(cursor &IDBCursor) !IDBCursorWithValue {
	if !cursor.with_value {
		return error('InvalidStateError: cursor does not expose values')
	}
	return IDBCursorWithValue{
		cursor: cursor
	}
}

pub fn (cursor &IDBCursorWithValue) current_value() ?Value {
	return cursor.cursor.current_value()
}

@[heap]
pub struct IDBCursor {
pub:
	transaction &IDBTransaction
	store_name  string
	index_name  string
	store_      &ObjectStoreData
	index_      ?&IndexData
	direction   IDBCursorDirection
	with_value  bool
pub mut:
	request                &IDBRequest
	position_              ?Key
	object_store_position_ ?Key
	current_entry          ?CursorEntry
	got_value              bool
	range_                 IDBKeyRange = IDBKeyRange.unbounded()
}

pub fn IDBCursor.create(transaction &IDBTransaction, store &ObjectStoreData, index ?&IndexData, direction IDBCursorDirection, range IDBKeyRange, with_value bool, request &IDBRequest) &IDBCursor {
	return &IDBCursor{
		transaction: transaction
		store_name: store.name
		index_name: if data := index { data.name } else { '' }
		store_: store
		index_: index
		direction: direction
		with_value: with_value
		request: request
		range_: range
	}
}

pub fn (cursor &IDBCursor) key() !Key {
	if !cursor.got_value {
		return error('InvalidStateError: cursor has no value')
	}
	entry := cursor.current_entry or { return error('InvalidStateError: cursor has no value') }
	return entry.key.clone()
}

pub fn (cursor &IDBCursor) primary_key() !Key {
	if !cursor.got_value {
		return error('InvalidStateError: cursor has no value')
	}
	entry := cursor.current_entry or { return error('InvalidStateError: cursor has no value') }
	return entry.primary_key.clone()
}

pub fn (cursor &IDBCursor) value() !Value {
	if !cursor.with_value || !cursor.got_value {
		return error('InvalidStateError: cursor has no value')
	}
	entry := cursor.current_entry or { return error('InvalidStateError: cursor has no value') }
	return entry.value.clone()
}

pub fn IDBCursor.request_offset() uint {
	return uint(__offsetof(IDBCursor, request))
}

pub fn (cursor &IDBCursor) current_key() ?Key {
	entry := cursor.current_entry or { return none }
	return entry.key.clone()
}

pub fn (cursor &IDBCursor) current_value() ?Value {
	if !cursor.with_value {
		return none
	}
	entry := cursor.current_entry or { return none }
	return entry.value.clone()
}

fn (cursor &IDBCursor) validate_source() ! {
	if cursor.store_.deleted {
		return error('InvalidStateError: cursor object store was deleted')
	}
	if index := cursor.index_ {
		if index.deleted {
			return error('InvalidStateError: cursor index was deleted')
		}
	}
}

pub fn (mut cursor IDBCursor) advance(count u32) !bool {
	cursor.validate_advance(count)!
	return cursor.iterate(none, none, u64(count))
}

fn (cursor &IDBCursor) validate_advance(count u32) ! {
	if count == 0 {
		return error('TypeError: advance count must be greater than zero')
	}
	cursor.require_iteration(false)!
}

pub fn (mut cursor IDBCursor) continue_to(key ?Key) !bool {
	cursor.validate_continue(key)!
	return cursor.iterate(key, none, 1)
}

fn (cursor &IDBCursor) validate_continue(key ?Key) ! {
	cursor.require_iteration(false)!
	if target := key {
		ensure_valid_key(target)!
		current := cursor.key()!
		comparison := compare_two_keys(target, current)!
		if (cursor.direction in [.next, .nextunique] && comparison <= 0) || (cursor.direction in [
			.prev,
			.prevunique,
		] && comparison >= 0) {
			return error('DataError: continuation key does not advance cursor')
		}
	}
}

pub fn (mut cursor IDBCursor) continue_primary_key(key Key, primary_key Key) !bool {
	cursor.validate_continue_primary_key(key, primary_key)!
	return cursor.iterate(key, primary_key, 1)
}

fn (cursor &IDBCursor) validate_continue_primary_key(key Key, primary_key Key) ! {
	cursor.require_iteration(true)!
	ensure_valid_key(key)!
	ensure_valid_key(primary_key)!
	current_key := cursor.key()!
	current_primary_key := cursor.primary_key()!
	key_cmp := compare_two_keys(key, current_key)!
	primary_cmp := compare_two_keys(primary_key, current_primary_key)!
	if (cursor.direction == .next && (key_cmp < 0 || (key_cmp == 0 && primary_cmp <= 0))) || (cursor.direction == .prev && (key_cmp > 0 || (key_cmp == 0 && primary_cmp >= 0))) {
		return error('DataError: continuation key and primary key do not advance cursor')
	}
}

// Bindings must check these gates before converting an author-supplied key.
pub fn (cursor &IDBCursor) require_iteration(primary_key bool) ! {
	cursor.transaction.require_active()!
	cursor.validate_source()!
	if primary_key && (cursor.index_ == none || cursor.direction in [.nextunique, .prevunique]) {
		return error('InvalidAccessError: continuePrimaryKey requires a non-unique index cursor')
	}
	if !cursor.got_value {
		return error('InvalidStateError: cursor is exhausted')
	}
}

struct CursorSearchResult {
	found bool
	entry CursorEntry
}

fn (cursor &IDBCursor) object_store_cursor_entry(record ObjectStoreRecord) CursorEntry {
	return CursorEntry{
		key: record.key
		primary_key: record.key
		value: if cursor.with_value { record.value.clone() } else { undefined_value() }
	}
}

fn (cursor &IDBCursor) index_cursor_entry(index &IndexData, store &ObjectStoreData, record IndexRecord) CursorEntry {
	value := if cursor.with_value {
		(index.referenced_value(record, store) or { undefined_value() }).clone()
	} else {
		undefined_value()
	}
	return CursorEntry{
		key: record.key
		primary_key: record.primary_key
		value: value
	}
}

fn (cursor &IDBCursor) find_object_store_record(store &ObjectStoreData, key ?Key, position ?Key) !CursorSearchResult {
	if cursor.direction in [.next, .nextunique] {
		for record in store.records {
			if target := key {
				if compare_two_keys(record.key, target)! < 0 {
					continue
				}
			}
			if current := position {
				if compare_two_keys(record.key, current)! <= 0 {
					continue
				}
			}
			if cursor.range_.includes(record.key)! {
				return CursorSearchResult{true, cursor.object_store_cursor_entry(record)}
			}
		}
	} else {
		for i := store.records.len - 1; i >= 0; i-- {
			record := store.records[i]
			if target := key {
				if compare_two_keys(record.key, target)! > 0 {
					continue
				}
			}
			if current := position {
				if compare_two_keys(record.key, current)! >= 0 {
					continue
				}
			}
			if cursor.range_.includes(record.key)! {
				return CursorSearchResult{true, cursor.object_store_cursor_entry(record)}
			}
		}
	}
	return CursorSearchResult{}
}

fn (cursor &IDBCursor) index_record_matches(record IndexRecord, key ?Key, primary_key ?Key, position ?Key, object_store_position ?Key) !bool {
	if !cursor.range_.includes(record.key)! {
		return false
	}
	forward := cursor.direction in [.next, .nextunique]
	unique := cursor.direction in [.nextunique, .prevunique]
	if target := key {
		comparison := compare_two_keys(record.key, target)!
		if (forward && comparison < 0) || (!forward && comparison > 0) {
			return false
		}
		if target_primary_key := primary_key {
			primary_comparison := compare_two_keys(record.primary_key, target_primary_key)!
			if comparison == 0 && ((forward && primary_comparison < 0) || (!forward && primary_comparison > 0)) {
				return false
			}
			if comparison != 0 && ((forward && comparison <= 0) || (!forward && comparison >= 0)) {
				return false
			}
		}
	}
	if current := position {
		comparison := compare_two_keys(record.key, current)!
		if unique {
			return if forward { comparison > 0 } else { comparison < 0 }
		}
		if comparison == 0 {
			current_primary_key := object_store_position or { return false }
			primary_comparison := compare_two_keys(record.primary_key, current_primary_key)!
			return if forward { primary_comparison > 0 } else { primary_comparison < 0 }
		}
		return if forward { comparison > 0 } else { comparison < 0 }
	}
	return true
}

fn (cursor &IDBCursor) find_index_record(store &ObjectStoreData, index &IndexData, key ?Key, primary_key ?Key, position ?Key, object_store_position ?Key) !CursorSearchResult {
	if cursor.direction in [.next, .nextunique] {
		for record in index.records {
			if cursor.index_record_matches(record, key, primary_key, position, object_store_position)! {
				return CursorSearchResult{true, cursor.index_cursor_entry(index, store, record)}
			}
		}
	} else {
		for i := index.records.len - 1; i >= 0; i-- {
			record := index.records[i]
			if !cursor.index_record_matches(record, key, primary_key, position, object_store_position)! {
				continue
			}
			if cursor.direction == .prevunique {
				for first_record in index.records {
					if keys_equal(first_record.key, record.key) {
						return CursorSearchResult{true, cursor.index_cursor_entry(index, store, first_record)}
					}
				}
			}
			return CursorSearchResult{true, cursor.index_cursor_entry(index, store, record)}
		}
	}
	return CursorSearchResult{}
}

fn (mut cursor IDBCursor) iterate(key ?Key, primary_key ?Key, count u64) !bool {
	store := cursor.store_
	mut position := cursor.position_
	mut object_store_position := cursor.object_store_position_
	mut found := CursorSearchResult{}
	for _ in 0 .. int(count) {
		found = if cursor.index_ == none {
			cursor.find_object_store_record(store, key, position)!
		} else {
			index := cursor.index_ or { return error('InvalidStateError: cursor index was deleted') }
			cursor.find_index_record(store, index, key, primary_key, position, object_store_position)!
		}
		if !found.found {
			cursor.position_ = none
			cursor.object_store_position_ = none
			cursor.current_entry = none
			cursor.got_value = false
			return false
		}
		position = found.entry.key
		if cursor.index_ != none {
			object_store_position = found.entry.primary_key
		}
	}
	cursor.position_ = position
	cursor.object_store_position_ = object_store_position
	cursor.current_entry = found.entry
	cursor.got_value = true
	return true
}

pub fn (mut cursor IDBCursor) update(value Value) !&IDBRequest {
	cursor.transaction.require_writable()!
	cursor.validate_source()!
	if !cursor.got_value {
		return error('InvalidStateError: cursor has no value')
	}
	if !cursor.with_value {
		return error('InvalidStateError: key-only cursor cannot update')
	}
	mut store := IDBObjectStore{
		transaction: cursor.transaction
		name_: cursor.store_.name
		store_: cursor.store_
	}
	data := store.load()!
	if path := data.key_path {
		value_key := evaluate_key_path(value, path) or {
			return error('DataError: updated value does not contain the cursor primary key')
		}
		if !keys_equal(value_key, cursor.primary_key()!) {
			return error('DataError: updated value changed the cursor primary key')
		}
		return store.put(value, none)
	}
	return store.put(value, cursor.primary_key()!)
}

pub fn (mut cursor IDBCursor) delete() !&IDBRequest {
	cursor.transaction.require_writable()!
	cursor.validate_source()!
	if !cursor.got_value {
		return error('InvalidStateError: cursor has no value')
	}
	if !cursor.with_value {
		return error('InvalidStateError: key-only cursor cannot delete')
	}
	mut store := IDBObjectStore{
		transaction: cursor.transaction
		name_: cursor.store_.name
		store_: cursor.store_
	}
	range := IDBKeyRange.only(cursor.primary_key()!)!
	return store.delete(range)
}
