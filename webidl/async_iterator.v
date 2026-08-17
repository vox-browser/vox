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
	values      []Value
	next_index  int
	is_finished bool
}

pub fn AsyncIterator.create(values []Value, kind IterationKind) &AsyncIterator {
	return &AsyncIterator{
		values: values.clone()
		kind:   kind
	}
}

pub fn (mut iterator AsyncIterator) next() &Promise {
	if iterator.is_finished || iterator.next_index >= iterator.values.len {
		iterator.is_finished = true
		return create_resolved_promise(iterator_result(undefined_value(), true))
	}
	index := iterator.next_index
	value := iterator.values[index]
	iterator.next_index++
	result := match iterator.kind {
		.key { number_value(index) }
		.value { value }
		.key_value { sequence_value([number_value(index), value]) }
	}
	return create_resolved_promise(iterator_result(result, false))
}

pub fn (mut iterator AsyncIterator) return_(value Value) &Promise {
	iterator.is_finished = true
	iterator.next_index = iterator.values.len
	return create_resolved_promise(iterator_result(value, true))
}

pub fn (mut iterator AsyncIterator) throw_(reason Value) &Promise {
	iterator.is_finished = true
	iterator.next_index = iterator.values.len
	return create_rejected_promise(reason)
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
