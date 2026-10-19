// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Shared typed values and promise records used by the standalone
// Streams translation. LibWeb stores arbitrary JS values and WebIDL promises;
// this package preserves their state transitions without depending on LibJS.
module streams

import webidl
import dom

pub enum ValueKind {
	undefined
	null_
	boolean
	number
	string_
	bytes
	array
	runtime_value
}

pub struct Value {
pub mut:
	kind    ValueKind
	boolean bool
	number  f64
	text    string
	bytes_  []u8
	items   []Value
	runtime_value_ ?webidl.Value
}

pub fn runtime_value(value webidl.Value) Value {
	return Value{ kind: .runtime_value, runtime_value_: value }
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
		bytes_: value
	}
}

pub fn array_value(value []Value) Value {
	return Value{
		kind:  .array
		items: value.clone()
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
		runtime_value_: value.runtime_value_
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
		.runtime_value { '[native JavaScript value]' }
	}
}

pub enum PromiseState {
	pending
	fulfilled
	rejected
}

// Streams which are exposed in different JavaScript realms can outlive the
// wrapper which created them. Ladybird therefore carries the realm alongside
// the stream or promise instead of recovering it from a PlatformObject. The V
// translation uses a small, embeddable identity because it deliberately does
// not depend on LibJS.
pub struct StreamRealm {
pub:
	id               u64
	promise_context_ ?&webidl.PromiseContext
	transform_wrapper_preparer ?fn (&TransformStream)
	structured_clone_algorithm ?fn (Value) !Value
	uint8_array_bytes ?fn (webidl.Value) !ReadLoopChunkBytes
	array_buffer_create ?fn ([]u8) !webidl.Value
	array_buffer_copy ?fn (webidl.Value) ![]u8
	uint8_array_create ?fn (webidl.Value) !webidl.Value
}

// Bindings::prepare_transform_stream_readable_writable_wrappers wraps both
// native components in the owning wrapper world before the start callback.
pub fn (realm StreamRealm) with_transform_wrapper_preparer(prepare fn (&TransformStream)) StreamRealm {
	return StreamRealm{...realm, transform_wrapper_preparer: prepare}
}

// AbstractOperations.cpp StructuredClone selects the operation's owning realm
// for StructuredSerialize/StructuredDeserialize at the actual engine boundary.
pub fn (realm StreamRealm) with_structured_clone_algorithm(clone fn (Value) !Value) StreamRealm {
	return StreamRealm{...realm, structured_clone_algorithm: clone}
}

pub fn StreamRealm.create_with_promise_context(context webidl.PromiseContext) StreamRealm {
	return StreamRealm{
		id:               context.realm_id
		promise_context_: &webidl.PromiseContext{ ...context }
	}
}

pub fn (realm StreamRealm) promise_context() webidl.PromiseContext {
	if context := realm.promise_context_ { return *context }
	return webidl.PromiseContext{ realm_id: realm.id }
}

pub fn StreamRealm.create(id u64) StreamRealm {
	return StreamRealm{
		id: id
	}
}

@[heap]
pub struct VoidPromise {
pub mut:
	state_  PromiseState
	reason_ string
	realm_  StreamRealm
mut:
	native_promise_ &webidl.Promise = unsafe { nil }
	reason_value_ ?webidl.Value
	resolution_started_ bool
}

pub fn VoidPromise.pending() &VoidPromise {
	return VoidPromise.pending_in(StreamRealm{})
}

pub fn VoidPromise.pending_in(realm StreamRealm) &VoidPromise {
	return &VoidPromise{
		realm_:          realm
		native_promise_: webidl.create_promise_for(realm.promise_context())
	}
}

pub fn VoidPromise.fulfilled() &VoidPromise {
	return VoidPromise.fulfilled_in(StreamRealm{})
}

pub fn VoidPromise.fulfilled_in(realm StreamRealm) &VoidPromise {
	mut promise := VoidPromise.pending_in(realm)
	promise.resolve()
	return promise
}

pub fn VoidPromise.rejected(reason string) &VoidPromise {
	return VoidPromise.rejected_in(StreamRealm{}, reason)
}

pub fn VoidPromise.rejected_in(realm StreamRealm, reason string) &VoidPromise {
	mut promise := VoidPromise.pending_in(realm)
	promise.reject(reason)
	return promise
}

pub fn (promise &VoidPromise) state() PromiseState {
	if promise.resolution_started_ && !isnil(promise.native_promise_) {
		return match promise.native_promise_.state {
			.pending { PromiseState.pending }
			.fulfilled { PromiseState.fulfilled }
			.rejected { PromiseState.rejected }
		}
	}
	return promise.state_
}

pub fn (promise &VoidPromise) reason() string {
	if promise.resolution_started_ && !isnil(promise.native_promise_)
		&& promise.native_promise_.state == .rejected {
		return callback_reason(promise.native_promise_.result)
	}
	return promise.reason_
}

pub fn (promise &VoidPromise) realm() StreamRealm {
	return promise.realm_
}

pub fn (mut promise VoidPromise) resolve() {
	if promise.state_ == .pending && !promise.resolution_started_ {
		mut native := promise.ensure_native_promise()
		promise.resolution_started_ = true
		promise.state_ = .fulfilled
		native.resolve(webidl.undefined_value())
	}
}

// WebIDL::resolve_promise calls the retained capability's actual Resolve
// function with the source Promise. Resolution begins immediately, even while
// adoption stays pending; subsequent Resolve/Reject calls cannot overtake it.
pub fn (mut promise VoidPromise) resolve_with_promise(result &webidl.Promise) {
	if promise.state_ != .pending || promise.resolution_started_ { return }
	mut native := promise.ensure_native_promise()
	promise.resolution_started_ = true
	native.resolve(webidl.promise_value(result))
}

pub fn (mut promise VoidPromise) reject(reason string) {
	promise.reject_value(webidl.string_value(reason))
}

pub fn (mut promise VoidPromise) reject_value(reason webidl.Value) {
	if promise.state_ == .pending && !promise.resolution_started_ {
		mut native := promise.ensure_native_promise()
		promise.resolution_started_ = true
		promise.state_ = .rejected
		promise.reason_ = callback_reason(reason)
		promise.reason_value_ = reason
		native.reject(reason)
	}
}

// The public typed promise keeps the actual WebIDL promise identity and job
// scheduler. Controllers attach source reactions to this object rather than
// polling a callback's state or treating a pending callback as fulfilled.
pub fn (promise &VoidPromise) as_webidl_promise() &webidl.Promise {
	mut owner := unsafe { &VoidPromise(promise) }
	return owner.ensure_native_promise()
}

fn (mut promise VoidPromise) ensure_native_promise() &webidl.Promise {
	if isnil(promise.native_promise_) {
		mut native := webidl.create_promise_for(promise.realm_.promise_context())
		promise.native_promise_ = native
		match promise.state_ {
			.pending {}
			.fulfilled { native.resolve(webidl.undefined_value()) }
			.rejected { native.reject(promise.reason_value_ or { webidl.string_value(promise.reason_) }) }
		}
	}
	return promise.native_promise_
}

@[heap]
struct VoidPromiseEntry {
mut:
	value &VoidPromise
	next_ &VoidPromiseEntry = unsafe { nil }
}

// WritableStream::m_write_requests is an AK::SinglyLinkedList.
struct VoidPromiseList {
mut:
	head_ &VoidPromiseEntry = unsafe { nil }
	tail_ &VoidPromiseEntry = unsafe { nil }
pub mut:
	len int
}

fn (mut list VoidPromiseList) append(value &VoidPromise) {
	entry := &VoidPromiseEntry{
		value: value
	}
	if isnil(list.tail_) {
		list.head_ = entry
	} else {
		mut tail := list.tail_
		tail.next_ = entry
	}
	list.tail_ = entry
	list.len++
}

fn (mut list VoidPromiseList) shift() !&VoidPromise {
	if isnil(list.head_) {
		return error('InternalError: No pending write request')
	}
	mut entry := list.head_
	list.head_ = entry.next_
	entry.next_ = unsafe { nil }
	if isnil(list.head_) {
		list.tail_ = unsafe { nil }
	}
	list.len--
	return entry.value
}

fn (mut list VoidPromiseList) clear() {
	list.head_ = unsafe { nil }
	list.tail_ = unsafe { nil }
	list.len = 0
}

fn (list &VoidPromiseList) values() []&VoidPromise {
	mut values := []&VoidPromise{cap: list.len}
	mut entry := list.head_
	for !isnil(entry) {
		values << entry.value
		entry = entry.next_
	}
	return values
}

pub struct ReadResult {
pub:
	value Value
	done  bool
}

pub type ReadPromiseFulfilledCallback = fn (ReadResult)

pub type ReadPromiseRejectedCallback = fn (string)

@[heap]
pub struct ReadPromise {
pub mut:
	state_        PromiseState
	result_       ReadResult
	reason_       string
	realm_        StreamRealm
	result_realm_ ?StreamRealm
mut:
	fulfilled_callback_ ?ReadPromiseFulfilledCallback
	rejected_callback_  ?ReadPromiseRejectedCallback
	native_promise_     &webidl.Promise = unsafe { nil }
	reason_value_       ?webidl.Value
}

pub fn ReadPromise.pending() &ReadPromise {
	return ReadPromise.pending_in(StreamRealm{}, none)
}

pub fn ReadPromise.pending_in(realm StreamRealm, result_realm ?StreamRealm) &ReadPromise {
	return &ReadPromise{
		realm_:        realm
		result_realm_: result_realm
		native_promise_: webidl.create_promise_for(realm.promise_context())
	}
}

pub fn ReadPromise.fulfilled(value Value, done bool) &ReadPromise {
	return ReadPromise.fulfilled_in(StreamRealm{}, none, value, done)
}

pub fn ReadPromise.fulfilled_in(realm StreamRealm, result_realm ?StreamRealm, value Value, done bool) &ReadPromise {
	mut promise := ReadPromise.pending_in(realm, result_realm)
	promise.resolve(value, done)
	return promise
}

pub fn ReadPromise.rejected(reason string) &ReadPromise {
	return ReadPromise.rejected_in(StreamRealm{}, none, reason)
}

pub fn ReadPromise.rejected_in(realm StreamRealm, result_realm ?StreamRealm, reason string) &ReadPromise {
	mut promise := ReadPromise.pending_in(realm, result_realm)
	promise.reject(reason)
	return promise
}

pub fn (promise &ReadPromise) state() PromiseState {
	return promise.state_
}

pub fn (promise &ReadPromise) result() ReadResult {
	return promise.result_
}

pub fn (promise &ReadPromise) reason() string {
	return promise.reason_
}

pub fn (promise &ReadPromise) realm() StreamRealm {
	return promise.realm_
}

pub fn (promise &ReadPromise) result_realm() ?StreamRealm {
	return promise.result_realm_
}

pub fn (mut promise ReadPromise) upon_settlement(fulfilled ReadPromiseFulfilledCallback, rejected ReadPromiseRejectedCallback) {
	match promise.state_ {
		.pending {
			promise.fulfilled_callback_ = fulfilled
			promise.rejected_callback_ = rejected
		}
		.fulfilled {
			fulfilled(promise.result_)
		}
		.rejected {
			rejected(promise.reason_)
		}
	}
}

fn (mut promise ReadPromise) resolve(value Value, done bool) {
	if promise.state_ == .pending {
		mut native := promise.ensure_native_promise()
		promise.state_ = .fulfilled
		promise.result_ = ReadResult{
			value: value
			done:  done
		}
		native.resolve(stream_read_result_value(value, done))
		if callback := promise.fulfilled_callback_ {
			promise.fulfilled_callback_ = none
			promise.rejected_callback_ = none
			callback(promise.result_)
		}
	}
}

fn (mut promise ReadPromise) reject(reason string) {
	promise.reject_value(webidl.string_value(reason))
}

pub fn (mut promise ReadPromise) reject_value(reason webidl.Value) {
	if promise.state_ == .pending {
		mut native := promise.ensure_native_promise()
		promise.state_ = .rejected
		promise.reason_ = callback_reason(reason)
		promise.reason_value_ = reason
		native.reject(reason)
		if callback := promise.rejected_callback_ {
			promise.fulfilled_callback_ = none
			promise.rejected_callback_ = none
			callback(promise.reason_)
		}
	}
}

@[heap]
struct ReadPromiseEntry {
mut:
	value ReadRequest
	next_ &ReadPromiseEntry = unsafe { nil }
}

// ReadableStreamDefaultReader::m_read_requests is an AK::SinglyLinkedList.
// Keep the same FIFO shape so fulfilling reads does not move all later requests.
struct ReadPromiseList {
mut:
	head_ &ReadPromiseEntry = unsafe { nil }
	tail_ &ReadPromiseEntry = unsafe { nil }
pub mut:
	len int
}

fn (mut list ReadPromiseList) append(value ReadRequest) {
	entry := &ReadPromiseEntry{
		value: value
	}
	if isnil(list.tail_) {
		list.head_ = entry
	} else {
		mut tail := list.tail_
		tail.next_ = entry
	}
	list.tail_ = entry
	list.len++
}

fn (mut list ReadPromiseList) shift() !ReadRequest {
	if isnil(list.head_) {
		return error('InternalError: No pending read request')
	}
	mut entry := list.head_
	list.head_ = entry.next_
	entry.next_ = unsafe { nil }
	if isnil(list.head_) {
		list.tail_ = unsafe { nil }
	}
	list.len--
	return entry.value
}

fn (mut list ReadPromiseList) remove(value ReadRequest) bool {
	mut previous := &ReadPromiseEntry(unsafe { nil })
	mut entry := list.head_
	for !isnil(entry) {
		if entry.value.read_request_identity() == value.read_request_identity() {
			if isnil(previous) {
				list.head_ = entry.next_
			} else {
				previous.next_ = entry.next_
			}
			if voidptr(list.tail_) == voidptr(entry) {
				list.tail_ = previous
			}
			entry.next_ = unsafe { nil }
			list.len--
			return true
		}
		previous = entry
		entry = entry.next_
	}
	return false
}

fn (mut list ReadPromiseList) clear() {
	list.head_ = unsafe { nil }
	list.tail_ = unsafe { nil }
	list.len = 0
}

fn (list &ReadPromiseList) values() []ReadRequest {
	mut values := []ReadRequest{cap: list.len}
	mut entry := list.head_
	for !isnil(entry) {
		values << entry.value
		entry = entry.next_
	}
	return values
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
	realm_  StreamRealm
mut:
	native_promise_ &webidl.Promise = unsafe { nil }
	reason_value_ ?webidl.Value
}

pub fn BYOBReadPromise.pending() &BYOBReadPromise {
	return BYOBReadPromise.pending_in(StreamRealm{})
}

pub fn BYOBReadPromise.pending_in(realm StreamRealm) &BYOBReadPromise {
	return &BYOBReadPromise{
		realm_: realm
		native_promise_: webidl.create_promise_for(realm.promise_context())
	}
}

pub fn BYOBReadPromise.fulfilled(value []u8, done bool) &BYOBReadPromise {
	return BYOBReadPromise.fulfilled_in(StreamRealm{}, value, done)
}

pub fn BYOBReadPromise.fulfilled_in(realm StreamRealm, value []u8, done bool) &BYOBReadPromise {
	mut promise := BYOBReadPromise.pending_in(realm)
	promise.resolve(value, done)
	return promise
}

pub fn BYOBReadPromise.rejected(reason string) &BYOBReadPromise {
	return BYOBReadPromise.rejected_in(StreamRealm{}, reason)
}

pub fn BYOBReadPromise.rejected_in(realm StreamRealm, reason string) &BYOBReadPromise {
	mut promise := BYOBReadPromise.pending_in(realm)
	promise.reject(reason)
	return promise
}

pub fn (promise &BYOBReadPromise) state() PromiseState {
	return promise.state_
}

pub fn (promise &BYOBReadPromise) result() BYOBReadResult {
	return promise.result_
}

pub fn (promise &BYOBReadPromise) reason() string {
	return promise.reason_
}

pub fn (promise &BYOBReadPromise) realm() StreamRealm {
	return promise.realm_
}

fn (mut promise BYOBReadPromise) resolve(value []u8, done bool) {
	if promise.state_ == .pending {
		mut native := promise.ensure_native_promise()
		promise.state_ = .fulfilled
		promise.result_ = BYOBReadResult{
			value: value
			done:  done
		}
		native.resolve(stream_read_result_value(bytes_value(value), done))
	}
}

fn (mut promise BYOBReadPromise) reject(reason string) {
	promise.reject_value(webidl.string_value(reason))
}

pub fn (mut promise BYOBReadPromise) reject_value(reason webidl.Value) {
	if promise.state_ == .pending {
		mut native := promise.ensure_native_promise()
		promise.state_ = .rejected
		promise.reason_ = callback_reason(reason)
		promise.reason_value_ = reason
		native.reject(reason)
	}
}

pub type AbortAlgorithm = fn (Value) !

pub type CancelAlgorithm = fn (Value) !

pub type CloseAlgorithm = fn () !

pub type FlushAlgorithm = fn () ![]Value

pub type PullAlgorithm = fn () !

pub type SizeAlgorithm = fn (Value) !f64

// Source SizeAlgorithm returns JS::Value; legacy native scalar callers retain
// SizeAlgorithm while actual engine callbacks use this completion boundary.
pub type ValueSizeAlgorithm = fn (Value) !webidl.Value

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
	native_ &dom.AbortSignal = unsafe { nil }
}

pub fn AbortSignal.create() &AbortSignal {
	return AbortSignal.from_dom(dom.AbortSignal.new())
}

pub fn AbortSignal.from_dom(signal &dom.AbortSignal) &AbortSignal {
	return &AbortSignal{native_: signal}
}

pub fn (signal &AbortSignal) dom_signal() &dom.AbortSignal {
	if signal.native_ == unsafe { nil } {
		mut mutable_signal := unsafe { &AbortSignal(signal) }
		mutable_signal.native_ = dom.AbortSignal.new()
	}
	return signal.native_
}

pub fn (signal &AbortSignal) aborted() bool {
	return signal.dom_signal().aborted()
}

pub fn (signal &AbortSignal) reason() Value {
	return stream_value_from_webidl(signal.dom_signal().reason().as_webidl_value() or { panic(err) })
}

pub fn (mut signal AbortSignal) abort(reason Value) {
	mut native := signal.dom_signal()
	native.signal_abort(dom.js_webidl_value(stream_value_to_webidl(reason)))
}
