// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IDBRequest.{h,cpp,idl}, IDBOpenDBRequest.{h,cpp,idl}, and
// IDBVersionChangeEvent.{h,cpp,idl}.
module indexeddb

pub enum IDBRequestReadyState {
	pending
	done
}

pub enum RequestResultKind {
	undefined
	value
	key
	values
	keys
	count
	records
	cursor
}

@[heap]
pub struct IDBRequest {
pub:
	source_name string
pub mut:
	ready_state   IDBRequestReadyState = .pending
	result_kind   RequestResultKind
	value         Value
	key           ?Key
	values        []Value
	keys          []Key
	count         u64
	records       []IDBRecord
	cursor        &IDBCursor = unsafe { nil }
	error_message string
	events        []string
	processed     bool
	aborted       bool
}

pub fn IDBRequest.create(source_name string) &IDBRequest {
	return &IDBRequest{
		source_name: source_name
	}
}

pub fn (request &IDBRequest) result() !RequestResultKind {
	if request.ready_state != .done {
		return error('InvalidStateError: request is pending')
	}
	if request.error_message != '' {
		return error(request.error_message)
	}
	return request.result_kind
}

pub fn (request &IDBRequest) error() !string {
	if request.ready_state != .done {
		return error('InvalidStateError: request is pending')
	}
	return request.error_message
}

fn (mut request IDBRequest) succeed(kind RequestResultKind) {
	request.result_kind = kind
	request.processed = true
	request.ready_state = .done
	request.events << 'success'
}

fn (mut request IDBRequest) fail(message string) {
	request.error_message = message
	request.processed = true
	request.ready_state = .done
	request.events << 'error'
}

@[heap]
pub struct IDBOpenDBRequest {
pub mut:
	request             &IDBRequest
	factory             &IDBFactory = unsafe { nil }
	database_name       string
	connection          &IDBDatabase = unsafe { nil }
	old_version         u64
	new_version         ?u64
	upgrade_transaction &IDBTransaction = unsafe { nil }
}

pub struct IDBVersionChangeEvent {
pub:
	type_       string
	old_version u64
	new_version ?u64
	bubbles     bool
	cancelable  bool
}

pub fn new_version_change_event(type_ string, old_version u64, new_version ?u64) IDBVersionChangeEvent {
	return IDBVersionChangeEvent{
		type_:       type_
		old_version: old_version
		new_version: new_version
	}
}
