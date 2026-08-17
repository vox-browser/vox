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

@[heap]
pub struct IDBCursor {
pub:
	transaction &IDBTransaction
	store_name  string
	index_name  string
	direction   IDBCursorDirection
	with_value  bool
	request     &IDBRequest
pub mut:
	entries   []CursorEntry
	position  int
	got_value bool = true
}

pub fn IDBCursor.create(transaction &IDBTransaction, store_name string, index_name string, direction IDBCursorDirection, entries []CursorEntry, with_value bool, request &IDBRequest) &IDBCursor {
	return &IDBCursor{
		transaction: transaction
		store_name:  store_name
		index_name:  index_name
		direction:   direction
		entries:     entries
		with_value:  with_value
		request:     request
	}
}

pub fn (cursor &IDBCursor) key() !Key {
	if !cursor.got_value || cursor.position >= cursor.entries.len {
		return error('InvalidStateError: cursor has no value')
	}
	return cursor.entries[cursor.position].key.clone()
}

pub fn (cursor &IDBCursor) primary_key() !Key {
	if !cursor.got_value || cursor.position >= cursor.entries.len {
		return error('InvalidStateError: cursor has no value')
	}
	return cursor.entries[cursor.position].primary_key.clone()
}

pub fn (cursor &IDBCursor) value() !Value {
	if !cursor.with_value || !cursor.got_value || cursor.position >= cursor.entries.len {
		return error('InvalidStateError: cursor has no value')
	}
	return cursor.entries[cursor.position].value.clone()
}

fn (cursor &IDBCursor) validate_source() ! {
	if cursor.store_name !in cursor.transaction.database.data.stores {
		return error('InvalidStateError: cursor object store was deleted')
	}
	if cursor.index_name != '' {
		store := cursor.transaction.database.data.stores[cursor.store_name]
		if cursor.index_name !in store.indexes {
			return error('InvalidStateError: cursor index was deleted')
		}
	}
}

pub fn (mut cursor IDBCursor) advance(count u32) !bool {
	if count == 0 {
		return error('TypeError: advance count must be greater than zero')
	}
	cursor.transaction.require_active()!
	cursor.validate_source()!
	if !cursor.got_value {
		return error('InvalidStateError: cursor is iterating')
	}
	cursor.position += int(count)
	cursor.got_value = cursor.position < cursor.entries.len
	return cursor.got_value
}

pub fn (mut cursor IDBCursor) continue_to(key ?Key) !bool {
	cursor.transaction.require_active()!
	cursor.validate_source()!
	if !cursor.got_value {
		return error('InvalidStateError: cursor is exhausted')
	}
	if target := key {
		ensure_valid_key(target)!
		current := cursor.entries[cursor.position].key
		comparison := compare_two_keys(target, current)!
		if (cursor.direction in [.next, .nextunique] && comparison <= 0)
			|| (cursor.direction in [.prev, .prevunique] && comparison >= 0) {
			return error('DataError: continuation key does not advance cursor')
		}
		mut next := cursor.position + 1
		for next < cursor.entries.len {
			candidate := compare_two_keys(cursor.entries[next].key, target)!
			if (cursor.direction in [.next, .nextunique] && candidate >= 0)
				|| (cursor.direction in [.prev, .prevunique] && candidate <= 0) {
				break
			}
			next++
		}
		cursor.position = next
	} else {
		cursor.position++
	}
	cursor.got_value = cursor.position < cursor.entries.len
	return cursor.got_value
}

pub fn (mut cursor IDBCursor) continue_primary_key(key Key, primary_key Key) !bool {
	cursor.transaction.require_active()!
	cursor.validate_source()!
	if cursor.index_name == '' || cursor.direction in [.nextunique, .prevunique] {
		return error('InvalidAccessError: continuePrimaryKey requires a non-unique index cursor')
	}
	if !cursor.got_value {
		return error('InvalidStateError: cursor is exhausted')
	}
	ensure_valid_key(key)!
	ensure_valid_key(primary_key)!
	current := cursor.entries[cursor.position]
	key_cmp := compare_two_keys(key, current.key)!
	primary_cmp := compare_two_keys(primary_key, current.primary_key)!
	if (cursor.direction == .next && (key_cmp < 0 || (key_cmp == 0 && primary_cmp <= 0)))
		|| (cursor.direction == .prev && (key_cmp > 0 || (key_cmp == 0 && primary_cmp >= 0))) {
		return error('DataError: continuation key and primary key do not advance cursor')
	}
	for i := cursor.position + 1; i < cursor.entries.len; i++ {
		entry := cursor.entries[i]
		candidate_key_cmp := compare_two_keys(entry.key, key)!
		candidate_primary_cmp := compare_two_keys(entry.primary_key, primary_key)!
		if (cursor.direction == .next && (candidate_key_cmp > 0
			|| (candidate_key_cmp == 0 && candidate_primary_cmp >= 0)))
			|| (cursor.direction == .prev && (candidate_key_cmp < 0
			|| (candidate_key_cmp == 0 && candidate_primary_cmp <= 0))) {
			cursor.position = i
			cursor.got_value = true
			return true
		}
	}
	cursor.position = cursor.entries.len
	cursor.got_value = false
	return false
}

pub fn (mut cursor IDBCursor) update(value Value) !&IDBRequest {
	cursor.transaction.require_writable()!
	cursor.validate_source()!
	if !cursor.got_value || cursor.position >= cursor.entries.len {
		return error('InvalidStateError: cursor has no value')
	}
	if !cursor.with_value {
		return error('InvalidStateError: key-only cursor cannot update')
	}
	mut store := IDBObjectStore{
		transaction: cursor.transaction
		name_:       cursor.store_name
	}
	data := store.load()!
	if path := data.key_path {
		value_key := evaluate_key_path(value, path) or {
			return error('DataError: updated value does not contain the cursor primary key')
		}
		if !keys_equal(value_key, cursor.entries[cursor.position].primary_key) {
			return error('DataError: updated value changed the cursor primary key')
		}
		return store.put(value, none)
	}
	return store.put(value, cursor.entries[cursor.position].primary_key)
}

pub fn (mut cursor IDBCursor) delete() !&IDBRequest {
	cursor.transaction.require_writable()!
	cursor.validate_source()!
	if !cursor.got_value || cursor.position >= cursor.entries.len {
		return error('InvalidStateError: cursor has no value')
	}
	if !cursor.with_value {
		return error('InvalidStateError: key-only cursor cannot delete')
	}
	mut store := IDBObjectStore{
		transaction: cursor.transaction
		name_:       cursor.store_name
	}
	range := IDBKeyRange.only(cursor.entries[cursor.position].primary_key)!
	return store.delete(range)
}
