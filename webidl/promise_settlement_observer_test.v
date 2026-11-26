// SPDX-License-Identifier: BSD-2-Clause
module webidl

import platform

@[heap]
struct NativeSettlementRecorder {
mut:
	states []PromiseState
	values []Value
}

fn (record &NativeSettlementRecorder) promise_observer_identity() voidptr { return voidptr(record) }
fn (mut record NativeSettlementRecorder) native_promise_settled(state PromiseState, value Value) {
	record.states << state
	record.values << value
}

fn test_native_promise_observers_settle_once_with_original_native_values() {
	mut promise := create_promise()
	mut sink := &NativeSettlementRecorder{}
	promise.observe_native_settlement(mut sink)
	promise.observe_native_settlement(mut sink)
	reason := object_value_with_id({'marker': number_value(42)}, 7)
	promise.reject(reason)
	promise.resolve(string_value('late'))
	assert sink.states == [.rejected] && sink.values.len == 1
	assert sink.values[0].opaque_id == 7 && (sink.values[0].object_value['marker'] or { panic('Missing marker') }).number_value == 42
	assert promise.is_handled
}

fn test_native_promise_observer_can_be_removed_before_pending_settlement() {
	mut promise := create_promise()
	mut first := &NativeSettlementRecorder{}
	mut second := &NativeSettlementRecorder{}
	promise.observe_native_settlement(mut first); promise.observe_native_settlement(mut second)
	assert promise.remove_native_settlement_observer(first.promise_observer_identity())
	assert !promise.remove_native_settlement_observer(first.promise_observer_identity())
	promise.resolve(number_value(3))
	assert first.values.len == 0 && second.values.len == 1 && second.values[0].number_value == 3
}

fn test_native_promise_observer_sees_already_settled_capability_without_new_jobs() {
	mut promise := create_resolved_promise(string_value('ready'))
	mut sink := &NativeSettlementRecorder{}
	promise.observe_native_settlement(mut sink)
	assert sink.states == [.fulfilled] && sink.values[0].string_value == 'ready'
	assert !promise.remove_native_settlement_observer(sink.promise_observer_identity())
}

fn test_native_promise_observation_tracks_adoption_and_preserves_existing_reactions() {
	mut source := create_promise()
	mut target := create_promise()
	mut sink := &NativeSettlementRecorder{}
	target.observe_native_settlement(mut sink)
	target.resolve(promise_value(source))
	assert sink.values.len == 0 && target.state == .pending
	child := target.upon_fulfillment(fn (value Value) !Value { return number_value(value.number_value + 1) })
	source.resolve(number_value(8))
	assert sink.states == [.fulfilled] && sink.values[0].number_value == 8
	assert child.state == .fulfilled && child.result.number_value == 9
}

fn test_native_promise_observer_slots_survive_temporary_arena_reset() {
	mut promise := create_promise()
	mut sink := &NativeSettlementRecorder{}
	mut arena := platform.new_arena('native Promise settlement observer slots')
	entry := arena.enter()
	promise.observe_native_settlement(mut sink)
	arena.leave(entry); arena.reset(); arena.release()
	promise.resolve(number_value(5))
	assert sink.states == [.fulfilled] && sink.values[0].number_value == 5
}
