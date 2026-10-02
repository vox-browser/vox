module streams

import webidl

fn test_pipe_through_returns_already_locked_readable_side_and_handles_internal_promise() {
	mut source := ReadableStream.create(StreamRealm{}, UnderlyingSource{}, QueuingStrategy{})!
	source.close()
	mut readable := ReadableStream.create(StreamRealm{}, UnderlyingSource{}, QueuingStrategy{})!
	_ := readable.get_default_reader()!
	writable := WritableStream.create(StreamRealm{}, UnderlyingSink{}, QueuingStrategy{})!
	returned := source.pipe_through(ReadableWritablePair{readable: readable, writable: writable}, StreamPipeOptions{})!
	assert voidptr(returned) == voidptr(readable) && returned.locked()
	assert source.pipe_promise_.state() == .fulfilled
	assert source.pipe_promise_.as_webidl_promise().is_handled
	assert !source.locked() && !writable.locked()
}

fn test_pipe_through_returns_readable_even_when_source_pipe_rejects_immediately() {
	mut source := ReadableStream.create(StreamRealm{}, UnderlyingSource{}, QueuingStrategy{})!
	reason := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('OperationError', 'source already failed'))
	source.error_value(reason)
	readable := ReadableStream.create(StreamRealm{}, UnderlyingSource{}, QueuingStrategy{})!
	writable := WritableStream.create(StreamRealm{}, UnderlyingSink{}, QueuingStrategy{})!
	returned := source.pipe_through(ReadableWritablePair{readable: readable, writable: writable}, StreamPipeOptions{})!
	assert voidptr(returned) == voidptr(readable)
	assert source.pipe_promise_.state() == .rejected
	native := source.pipe_promise_.as_webidl_promise()
	assert native.is_handled && native.result.opaque_id == reason.opaque_id
}

fn test_pipe_through_checks_source_lock_before_destination_lock_without_starting_pipe() {
	mut source := ReadableStream.create(StreamRealm{}, UnderlyingSource{}, QueuingStrategy{})!
	mut readable := ReadableStream.create(StreamRealm{}, UnderlyingSource{}, QueuingStrategy{})!
	mut writable := WritableStream.create(StreamRealm{}, UnderlyingSink{}, QueuingStrategy{})!
	mut source_reader := source.get_default_reader()!
	mut writer := writable.get_writer()!
	pair := ReadableWritablePair{readable: readable, writable: writable}
	if _ := source.pipe_through(pair, StreamPipeOptions{}) { assert false } else { assert err.msg() == 'TypeError: Source ReadableStream is locked' }
	source_reader.release_lock()!
	if _ := source.pipe_through(pair, StreamPipeOptions{}) { assert false } else { assert err.msg() == 'TypeError: Transform writable side is locked' }
	assert isnil(source.pipe_promise_) && !readable.locked()
	writer.release_lock()
}
