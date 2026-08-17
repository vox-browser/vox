// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Shared typed values and synchronous promise records used by the standalone
// Streams translation. LibWeb stores arbitrary JS values and WebIDL promises;
// this package preserves their state transitions without depending on LibJS.
module streams

pub enum ValueKind {
	undefined
	null_
	boolean
	number
	string_
	bytes
	array
}

pub struct Value {
pub mut:
	kind    ValueKind
	boolean bool
	number  f64
	text    string
	bytes_  []u8
	items   []Value
}

pub fn undefined_value() Value {
	return Value{}
}

pub fn null_value() Value {
	return Value{
		kind: .null_
	}
}

pub fn bool_value(value bool) Value {
	return Value{
		kind:    .boolean
		boolean: value
	}
}

pub fn number_value(value f64) Value {
	return Value{
		kind:   .number
		number: value
	}
}

pub fn string_value(value string) Value {
	return Value{
		kind: .string_
		text: value
	}
}

pub fn bytes_value(value []u8) Value {
	return Value{
		kind:   .bytes
		bytes_: value.clone()
	}
}

pub fn array_value(value []Value) Value {
	mut items := []Value{cap: value.len}
	for item in value {
		items << item.clone()
	}
	return Value{
		kind:  .array
		items: items
	}
}

pub fn (value Value) clone() Value {
	mut items := []Value{cap: value.items.len}
	for item in value.items {
		items << item.clone()
	}
	return Value{
		kind:    value.kind
		boolean: value.boolean
		number:  value.number
		text:    value.text
		bytes_:  value.bytes_.clone()
		items:   items
	}
}

pub fn (value Value) byte_length() int {
	return if value.kind == .bytes { value.bytes_.len } else { 0 }
}

pub fn (value Value) description() string {
	return match value.kind {
		.undefined { 'undefined' }
		.null_ { 'null' }
		.boolean { value.boolean.str() }
		.number { value.number.str() }
		.string_ { value.text }
		.bytes { '${value.bytes_.len} bytes' }
		.array { '${value.items.len} values' }
	}
}

pub enum PromiseState {
	pending
	fulfilled
	rejected
}

@[heap]
pub struct VoidPromise {
pub mut:
	state_  PromiseState
	reason_ string
}

pub fn VoidPromise.pending() &VoidPromise {
	return &VoidPromise{}
}

pub fn VoidPromise.fulfilled() &VoidPromise {
	return &VoidPromise{
		state_: .fulfilled
	}
}

pub fn VoidPromise.rejected(reason string) &VoidPromise {
	return &VoidPromise{
		state_:  .rejected
		reason_: reason
	}
}

pub fn (promise &VoidPromise) state() PromiseState {
	return promise.state_
}

pub fn (promise &VoidPromise) reason() string {
	return promise.reason_
}

pub fn (mut promise VoidPromise) resolve() {
	if promise.state_ == .pending {
		promise.state_ = .fulfilled
	}
}

pub fn (mut promise VoidPromise) reject(reason string) {
	if promise.state_ == .pending {
		promise.state_ = .rejected
		promise.reason_ = reason
	}
}

pub struct ReadResult {
pub:
	value Value
	done  bool
}

@[heap]
pub struct ReadPromise {
pub mut:
	state_  PromiseState
	result_ ReadResult
	reason_ string
}

pub fn ReadPromise.pending() &ReadPromise {
	return &ReadPromise{}
}

pub fn ReadPromise.fulfilled(value Value, done bool) &ReadPromise {
	return &ReadPromise{
		state_:  .fulfilled
		result_: ReadResult{
			value: value.clone()
			done:  done
		}
	}
}

pub fn ReadPromise.rejected(reason string) &ReadPromise {
	return &ReadPromise{
		state_:  .rejected
		reason_: reason
	}
}

pub fn (promise &ReadPromise) state() PromiseState {
	return promise.state_
}

pub fn (promise &ReadPromise) result() ReadResult {
	return ReadResult{
		value: promise.result_.value.clone()
		done:  promise.result_.done
	}
}

pub fn (promise &ReadPromise) reason() string {
	return promise.reason_
}

fn (mut promise ReadPromise) resolve(value Value, done bool) {
	if promise.state_ == .pending {
		promise.state_ = .fulfilled
		promise.result_ = ReadResult{
			value: value.clone()
			done:  done
		}
	}
}

fn (mut promise ReadPromise) reject(reason string) {
	if promise.state_ == .pending {
		promise.state_ = .rejected
		promise.reason_ = reason
	}
}

pub struct BYOBReadResult {
pub:
	value []u8
	done  bool
}

@[heap]
pub struct BYOBReadPromise {
pub mut:
	state_  PromiseState
	result_ BYOBReadResult
	reason_ string
}

pub fn BYOBReadPromise.pending() &BYOBReadPromise {
	return &BYOBReadPromise{}
}

pub fn BYOBReadPromise.fulfilled(value []u8, done bool) &BYOBReadPromise {
	return &BYOBReadPromise{
		state_:  .fulfilled
		result_: BYOBReadResult{
			value: value.clone()
			done:  done
		}
	}
}

pub fn BYOBReadPromise.rejected(reason string) &BYOBReadPromise {
	return &BYOBReadPromise{
		state_:  .rejected
		reason_: reason
	}
}

pub fn (promise &BYOBReadPromise) state() PromiseState {
	return promise.state_
}

pub fn (promise &BYOBReadPromise) result() BYOBReadResult {
	return BYOBReadResult{
		value: promise.result_.value.clone()
		done:  promise.result_.done
	}
}

pub fn (promise &BYOBReadPromise) reason() string {
	return promise.reason_
}

fn (mut promise BYOBReadPromise) resolve(value []u8, done bool) {
	if promise.state_ == .pending {
		promise.state_ = .fulfilled
		promise.result_ = BYOBReadResult{
			value: value.clone()
			done:  done
		}
	}
}

fn (mut promise BYOBReadPromise) reject(reason string) {
	if promise.state_ == .pending {
		promise.state_ = .rejected
		promise.reason_ = reason
	}
}

pub type AbortAlgorithm = fn (Value) !

pub type CancelAlgorithm = fn (Value) !

pub type CloseAlgorithm = fn () !

pub type FlushAlgorithm = fn () ![]Value

pub type PullAlgorithm = fn () !

pub type SizeAlgorithm = fn (Value) !f64

pub type StartAlgorithm = fn () !

pub type TransformAlgorithm = fn (Value) ![]Value

pub type WriteAlgorithm = fn (Value) !

pub fn default_size_algorithm(_ Value) !f64 {
	return 1.0
}

pub fn byte_length_size_algorithm(value Value) !f64 {
	return f64(value.byte_length())
}

pub fn count_size_algorithm(_ Value) !f64 {
	return 1.0
}

@[heap]
pub struct AbortSignal {
mut:
	aborted_ bool
	reason_  Value
	pipes_   []&ReadableStream
}

pub fn AbortSignal.create() &AbortSignal {
	return &AbortSignal{}
}

pub fn (signal &AbortSignal) aborted() bool {
	return signal.aborted_
}

pub fn (signal &AbortSignal) reason() Value {
	return signal.reason_.clone()
}

pub fn (mut signal AbortSignal) abort(reason Value) {
	if !signal.aborted_ {
		signal.aborted_ = true
		signal.reason_ = reason.clone()
		for mut source in signal.pipes_ {
			pump_readable_pipe(mut source)
		}
		signal.pipes_.clear()
	}
}
