// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebIDL/AsyncIterator.{h,cpp}.
module webidl

pub enum IterationKind {
	key
	value
	key_value
}

@[heap]
pub struct AsyncIterator {
pub:
	kind IterationKind
mut:
	realm_id    u64
	values      []Value
	next_index  int
	is_finished bool
}

pub fn AsyncIterator.create(values []Value, kind IterationKind) &AsyncIterator {
	return AsyncIterator.create_in_realm(values, kind, 0)
}

pub fn AsyncIterator.create_in_realm(values []Value, kind IterationKind, realm_id u64) &AsyncIterator {
	return &AsyncIterator{
		kind: kind
		values: values.clone()
		realm_id: realm_id
	}
}

pub fn (iterator &AsyncIterator) promise_realm() u64 {
	return iterator.realm_id
}

fn (iterator &AsyncIterator) promise_context() PromiseContext {
	return PromiseContext{
		realm_id: iterator.promise_realm()
	}
}

pub fn (mut iterator AsyncIterator) next() &Promise {
	if iterator.is_finished || iterator.next_index >= iterator.values.len {
		iterator.is_finished = true
		return create_resolved_promise_for(iterator.promise_context(), iterator_result(undefined_value(), true))
	}
	index := iterator.next_index
	value := iterator.values[index]
	iterator.next_index++
	result := match iterator.kind {
		.key { number_value(index) }
		.value { value }
		.key_value { sequence_value([number_value(index), value]) }
	}
	return create_resolved_promise_for(iterator.promise_context(), iterator_result(result, false))
}

pub fn (mut iterator AsyncIterator) iterator_next_impl() &Promise {
	return iterator.next()
}

pub fn (mut iterator AsyncIterator) return_(value Value) &Promise {
	iterator.is_finished = true
	iterator.next_index = iterator.values.len
	return create_resolved_promise_for(iterator.promise_context(), iterator_result(value, true))
}

pub fn (mut iterator AsyncIterator) iterator_return_impl(value Value) &Promise {
	return iterator.return_(value)
}

pub fn (mut iterator AsyncIterator) iterator_return(value Value) &Promise {
	return iterator.return_(value)
}

pub fn (mut iterator AsyncIterator) throw_(reason Value) &Promise {
	iterator.is_finished = true
	iterator.next_index = iterator.values.len
	return create_rejected_promise_for(iterator.promise_context(), reason)
}

fn iterator_result(value Value, done bool) Value {
	return object_value({
		'value': value
		'done':  boolean_value(done)
	})
}

// CachedAttribute models WebIDL/CachedAttribute.h: the first computed value is
// retained until explicitly cleared.
pub struct CachedAttribute {
mut:
	value ?Value
}

pub fn (mut attribute CachedAttribute) get_or_set(value Value) Value {
	if cached := attribute.value {
		return cached
	}
	attribute.value = value
	return value
}

pub fn (mut attribute CachedAttribute) clear() {
	attribute.value = none
}
