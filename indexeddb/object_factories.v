// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Direct entry points for IndexedDB's Web-facing objects and small internal
// value records. The standalone translation stores event handlers as typed
// callbacks and represents browser-only EventTarget parents with their owning
// database/transaction objects.
module indexeddb

pub fn Key.create(value Value) Key {
	return value_to_key(value)
}

pub fn (key Key) key_value() Value {
	return key_to_value(key) or { undefined_value() }
}

pub fn (key Key) key_compare_two_keys(other Key) !int {
	return compare_two_keys(key, other)
}

pub fn (key Key) dump() string {
	return key.str()
}

pub fn (key Key) key_type() KeyType {
	return key.kind
}

pub fn (key Key) is_invalid() bool {
	return !key.is_valid()
}

pub fn (key Key) value_as_double() !f64 {
	if key.kind !in [.number, .date] {
		return error('Key is not numeric')
	}
	return key.number
}

pub fn (key Key) value_as_string() !string {
	if key.kind != .string_ {
		return error('Key is not a string')
	}
	return key.text
}

pub fn (key Key) value_as_byte_buffer() ![]u8 {
	if key.kind != .binary {
		return error('Key is not binary')
	}
	return key.bytes.clone()
}

pub fn (key Key) value_as_vector() ![]Key {
	if key.kind != .array {
		return error('Key is not an array')
	}
	return key.items.map(it.clone())
}

pub fn (key Key) subkeys() []Key {
	if key.kind != .array {
		return []Key{}
	}
	return key.items.map(it.clone())
}

pub fn Key.create_number(value f64) Key {
	return number_key(value)
}

pub fn Key.create_date(value f64) Key {
	return date_key(value)
}

pub fn Key.create_string(value string) Key {
	return string_key(value)
}

pub fn Key.create_binary(value []u8) Key {
	return binary_key(value)
}

pub fn Key.create_array(value []Key) Key {
	return array_key(value)
}

pub fn Key.create_invalid() Key {
	return invalid_key()
}

pub fn (key Key) less_than(other Key) bool {
	return (compare_two_keys(key, other) or { 0 }) < 0
}

pub fn (key Key) greater_than(other Key) bool {
	return (compare_two_keys(key, other) or { 0 }) > 0
}

pub fn (key Key) less_than_or_equal(other Key) bool {
	return (compare_two_keys(key, other) or { 1 }) <= 0
}

pub fn (key Key) greater_than_or_equal(other Key) bool {
	return (compare_two_keys(key, other) or { -1 }) >= 0
}

pub fn IDBKeyRange.create(lower ?Key, upper ?Key, lower_open bool, upper_open bool) !IDBKeyRange {
	if low := lower {
		ensure_valid_key(low)!
	}
	if high := upper {
		ensure_valid_key(high)!
	}
	if low := lower {
		if high := upper {
			comparison := compare_two_keys(low, high)!
			if comparison > 0 || (comparison == 0 && (lower_open || upper_open)) {
				return error('DataError: key range is empty')
			}
		}
	}
	return IDBKeyRange{
		lower: if key := lower { key.clone() } else { none }
		upper: if key := upper { key.clone() } else { none }
		lower_open: lower_open
		upper_open: upper_open
	}
}

pub fn (range IDBKeyRange) is_in_range(key Key) !bool {
	return range.includes(key)
}

pub fn (range IDBKeyRange) key_range_lower() ?Value {
	key := range.lower or { return none }
	return key_to_value(key) or { none }
}

pub fn (range IDBKeyRange) key_range_upper() ?Value {
	key := range.upper or { return none }
	return key_to_value(key) or { none }
}

pub fn (range IDBKeyRange) key_range_lower_open() bool {
	return range.lower_open
}

pub fn (range IDBKeyRange) key_range_upper_open() bool {
	return range.upper_open
}

pub fn (range IDBKeyRange) is_unbound() bool {
	return range.lower == none && range.upper == none
}

pub fn (range IDBKeyRange) lower_key() ?Key {
	return if key := range.lower { key.clone() } else { none }
}

pub fn (range IDBKeyRange) upper_key() ?Key {
	return if key := range.upper { key.clone() } else { none }
}

pub fn IDBRecord.create(key Key, primary_key Key, value Value) IDBRecord {
	return IDBRecord{
		key: key.clone()
		primary_key: primary_key.clone()
		value: value.clone()
	}
}

pub fn (record IDBRecord) idb_record_key() Key {
	return record.key.clone()
}

pub fn (record IDBRecord) idb_record_primary_key() Key {
	return record.primary_key.clone()
}

pub fn (record IDBRecord) idb_record_value() Value {
	return record.value.clone()
}

pub fn (generator &KeyGenerator) key_generator_current_number() u64 {
	return generator.current_number
}

pub fn (mut generator KeyGenerator) increment() {
	if generator.current_number <= maximum_key_generator_value {
		generator.current_number++
	}
}

pub fn (mut generator KeyGenerator) set(value u64) {
	generator.current_number = value
}

pub fn (request &IDBRequest) get_parent() ?&IDBTransaction {
	return request.transaction_
}

pub fn (mut request IDBRequest) set_onsuccess(callback ?IDBEventHandler) {
	request.onsucceed_ = callback
}

pub fn (request &IDBRequest) onsuccess() ?IDBEventHandler {
	return request.onsucceed_
}

pub fn (mut request IDBRequest) set_onerror(callback ?IDBEventHandler) {
	request.onerror_ = callback
}

pub fn (request &IDBRequest) onerror() ?IDBEventHandler {
	return request.onerror_
}

pub fn (request &IDBRequest) ready_state() IDBRequestReadyState {
	return request.ready_state
}

pub fn (request &IDBRequest) done() bool {
	return request.ready_state == .done
}

pub fn (request &IDBRequest) request_processed() bool {
	return request.processed
}

pub fn (request &IDBRequest) source() string {
	return request.source_name
}

pub fn (request &IDBRequest) request_transaction() ?&IDBTransaction {
	return request.transaction_
}

pub fn (request &IDBRequest) uuid() string {
	return request.uuid_
}

pub fn (mut request IDBRequest) set_done(done bool) {
	request.ready_state = if done { .done } else { .pending }
}

pub fn (mut request IDBRequest) set_result(result RequestResultKind) {
	request.result_kind = result
}

pub fn (mut request IDBRequest) set_error(message string) {
	request.error_message = message
}

pub fn (mut request IDBRequest) set_processed(processed bool) {
	request.processed = processed
}

pub fn (mut request IDBRequest) set_source(source string) {
	request.source_name = source
}

pub fn (mut request IDBRequest) set_transaction(transaction ?&IDBTransaction) {
	request.transaction_ = transaction
}

pub fn (request &IDBRequest) has_error() bool {
	return request.error_message != ''
}

pub fn (request &IDBRequest) request_aborted() bool {
	return request.aborted
}

pub fn (mut request IDBRequest) set_aborted(aborted bool) {
	request.aborted = aborted
}

pub fn IDBOpenDBRequest.create(source string) &IDBOpenDBRequest {
	return &IDBOpenDBRequest{
		request: IDBRequest.create(source)
	}
}

pub fn (request &IDBOpenDBRequest) get_parent() ?&IDBTransaction {
	return request.request.transaction_
}

pub fn (mut request IDBOpenDBRequest) set_onblocked(callback ?IDBEventHandler) {
	request.onblocked_ = callback
}

pub fn (request &IDBOpenDBRequest) onblocked() ?IDBEventHandler {
	return request.onblocked_
}

pub fn (mut request IDBOpenDBRequest) set_onupgradeneeded(callback ?IDBEventHandler) {
	request.onupgradeneeded_ = callback
}

pub fn (request &IDBOpenDBRequest) onupgradeneeded() ?IDBEventHandler {
	return request.onupgradeneeded_
}

pub fn IDBVersionChangeEvent.create(type_ string, old_version u64, new_version ?u64) IDBVersionChangeEvent {
	return new_version_change_event(type_, old_version, new_version)
}

pub fn (event IDBVersionChangeEvent) old_version() u64 {
	return event.old_version
}

pub fn (event IDBVersionChangeEvent) new_version() ?u64 {
	return event.new_version
}

pub fn (factory &IDBFactory) databases() []IDBDatabaseInfo {
	return factory.database_infos()
}
