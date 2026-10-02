module streams

import math
import webidl

fn test_queue_validates_genuine_size_value_without_coercing_non_numbers() {
	mut queue := QueueWithSizes{}
	for size in [webidl.undefined_value(), webidl.null_value(), webidl.boolean_value(true), webidl.string_value('1'), webidl.bigint_value(1), webidl.object_value({}), webidl.runtime_value(webidl.RuntimeValue{string_conversion: fn () !string { assert false; return error('queue must not coerce') }})] {
		if _ := queue.enqueue_value_with_size_value(string_value('chunk'), size) { assert false } else { assert err.msg().starts_with('RangeError:') }
		assert queue.len() == 0 && queue.total_size() == 0
	}
	for number in [-1.0, math.nan(), math.inf(1)] {
		if _ := queue.enqueue_value_with_size_value(string_value('chunk'), webidl.number_value(number)) { assert false } else { assert err.msg().starts_with('RangeError:') }
	}
	queue.enqueue_value_with_size_value(string_value('zero'), webidl.number_value(0))!
	queue.enqueue_value_with_size_value(string_value('fraction'), webidl.runtime_value(webidl.RuntimeValue{
		number_primitive: 2.5
		string_conversion: fn () !string { assert false; return error('queue must not stringify number') }
	}))!
	assert queue.len() == 2 && queue.total_size() == 2.5
}

fn test_readable_size_value_errors_original_stream_and_skips_callback_for_pending_read() {
	mut stream := ReadableStream.create(StreamRealm{}, UnderlyingSource{}, QueuingStrategy{
		high_water_mark: 4
		size_value: fn (_ Value) !webidl.Value { return webidl.number_value(1.75) }
	})!
	stream.enqueue(string_value('first'))!
	assert stream.queue_.total_size() == 1.75
	stream.size_value_algorithm_ = fn (_ Value) !webidl.Value { return webidl.object_value({}) }
	if _ := stream.enqueue(string_value('invalid')) { assert false } else { assert err.msg().starts_with('RangeError:') }
	assert stream.state() == .errored && stream.queue_.total_size() == 0
	assert stream.size_value_algorithm_ == none

	mut direct := ReadableStream.create(StreamRealm{}, UnderlyingSource{}, QueuingStrategy{
		high_water_mark: 0
		size_value: fn (_ Value) !webidl.Value { assert false; return error('pending read bypasses size callback') }
	})!
	mut reader := direct.get_default_reader()!
	read := reader.read()
	direct.enqueue(string_value('direct'))!
	assert read.state() == .fulfilled
	assert read.result().value.text == 'direct'
	if _ := ReadableStream.create(StreamRealm{}, UnderlyingSource{type_: .bytes}, QueuingStrategy{size_value: fn (_ Value) !webidl.Value { return webidl.number_value(1) }}) {
		assert false
	} else { assert err.msg().starts_with('RangeError:') }
}

@[heap]
struct SizeWriterState {
mut:
	writer &WritableStreamDefaultWriter = unsafe { nil }
	writes int
}

fn test_writer_rechecks_original_locked_stream_after_size_callback_before_error_state() {
	for throws in [false, true] {
		state := &SizeWriterState{}
		original := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('OperationError', 'size callback completion'))
		mut stream := WritableStream.create(StreamRealm{}, UnderlyingSink{
			write: fn [state] (_ Value) ! { mut observed := unsafe { &SizeWriterState(state) }; observed.writes++ }
		}, QueuingStrategy{
			size_value: fn [state, throws, original] (_ Value) !webidl.Value {
				mut observed := unsafe { &SizeWriterState(state) }
				observed.writer.release_lock()
				if throws { return webidl.throw_value(original) }
				return webidl.object_value({})
			}
		})!
		mut writer := stream.get_writer()!
		mut observed := unsafe { &SizeWriterState(state) }
		observed.writer = writer
		request := writer.write(string_value('chunk'))
		assert request.state() == .rejected
		assert request.reason().contains("Writer's locked stream changed during write")
		assert !stream.locked() && stream.queue_total_size() == 0 && observed.writes == 0
		assert stream.state() == if throws { WritableStreamState.errored } else { WritableStreamState.writable }
		if throws { assert stream.stored_error_value().opaque_id == original.opaque_id }
	}
}

fn test_writer_checks_closed_state_before_validating_actual_size_result() {
	state := &SizeWriterState{}
	mut stream := WritableStream.create(StreamRealm{}, UnderlyingSink{}, QueuingStrategy{
		size_value: fn [state] (_ Value) !webidl.Value {
			mut observed := unsafe { &SizeWriterState(state) }
			assert observed.writer.close().state() == .fulfilled
			return webidl.object_value({})
		}
	})!
	mut writer := stream.get_writer()!
	mut observed := unsafe { &SizeWriterState(state) }
	observed.writer = writer
	request := writer.write(string_value('chunk'))
	assert request.state() == .rejected && request.reason().starts_with('TypeError:')
	assert stream.state() == .closed && stream.queue_total_size() == 0
}

fn test_transform_installs_actual_component_size_callbacks_before_transformer_start() {
	mut transform := TransformStream.create(StreamRealm{}, Transformer{}, QueuingStrategy{
		size_value: fn (_ Value) !webidl.Value { return webidl.number_value(3) }
	}, QueuingStrategy{
		high_water_mark: 4
		size_value: fn (_ Value) !webidl.Value { return webidl.number_value(2) }
	})!
	mut writable := transform.writable()
	mut writer := writable.get_writer()!
	assert writer.write(string_value('actual')).state() == .fulfilled
	assert transform.readable().queue_.total_size() == 2
	assert transform.writable().queue_total_size() == 0
}
