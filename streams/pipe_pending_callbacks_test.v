module streams

import webidl

@[heap]
struct PipeCallbackJobs {
mut:
	jobs []fn ()
	written []string
	aborts int
	cancels int
	closes int
}

fn (mut jobs PipeCallbackJobs) realm(id u64) StreamRealm {
	return StreamRealm.create_with_promise_context(webidl.PromiseContext{
		realm_id: id
		job_scheduler: fn [mut jobs] (job fn ()) { jobs.jobs << job }
	})
}

fn (mut jobs PipeCallbackJobs) drain() {
	mut count := 0
	for jobs.jobs.len > 0 {
		count++
		assert count < 200
		job := jobs.jobs[0]
		jobs.jobs.delete(0)
		job()
	}
}

fn test_pipe_waits_for_pending_write_and_close_before_unlocking() {
	mut jobs := &PipeCallbackJobs{}
	realm := jobs.realm(731)
	mut write := webidl.create_promise_for(realm.promise_context())
	mut close := webidl.create_promise_for(realm.promise_context())
	mut source := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	mut destination := WritableStream.create(realm, UnderlyingSink{
		write_promise: fn [mut jobs, write] (chunk Value) !&webidl.Promise {
			jobs.written << chunk.text
			return write
		}
		close_promise: fn [mut jobs, close] () !&webidl.Promise {
			jobs.closes++
			return close
		}
	}, QueuingStrategy{}) or { panic(err) }
	piped := source.pipe_to(mut destination, StreamPipeOptions{})
	jobs.drain()
	source.enqueue(string_value('last chunk')) or { panic(err) }
	source.close()
	jobs.drain()
	assert jobs.written == ['last chunk']
	assert jobs.closes == 0
	assert piped.state() == .pending
	assert source.locked() && destination.locked()
	write.resolve(webidl.undefined_value())
	jobs.drain()
	assert jobs.closes == 1
	assert piped.state() == .pending
	assert source.locked() && destination.locked()
	close.resolve(webidl.undefined_value())
	jobs.drain()
	assert piped.state() == .fulfilled
	assert !source.locked() && !destination.locked()
	assert destination.state() == .closed
}

fn test_pipe_prevent_close_still_waits_for_pending_write() {
	mut jobs := &PipeCallbackJobs{}
	realm := jobs.realm(732)
	mut write := webidl.create_promise_for(realm.promise_context())
	mut source := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	mut destination := WritableStream.create(realm, UnderlyingSink{
		write_promise: fn [write] (_ Value) !&webidl.Promise { return write }
	}, QueuingStrategy{}) or { panic(err) }
	piped := source.pipe_to(mut destination, StreamPipeOptions{ prevent_close: true })
	jobs.drain()
	source.enqueue(string_value('retained write')) or { panic(err) }
	source.close()
	jobs.drain()
	assert piped.state() == .pending
	assert source.locked() && destination.locked()
	write.resolve(webidl.undefined_value())
	jobs.drain()
	assert piped.state() == .fulfilled
	assert destination.state() == .writable
	assert !source.locked() && !destination.locked()
}

fn test_pipe_source_error_waits_for_write_then_rejecting_abort_action() {
	mut jobs := &PipeCallbackJobs{}
	realm := jobs.realm(733)
	mut write := webidl.create_promise_for(realm.promise_context())
	mut abort := webidl.create_promise_for(realm.promise_context())
	mut source := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	mut destination := WritableStream.create(realm, UnderlyingSink{
		write_promise: fn [write] (_ Value) !&webidl.Promise { return write }
		abort_promise: fn [mut jobs, abort] (_ Value) !&webidl.Promise {
			jobs.aborts++
			return abort
		}
	}, QueuingStrategy{}) or { panic(err) }
	piped := source.pipe_to(mut destination, StreamPipeOptions{})
	jobs.drain()
	source.enqueue(string_value('already read')) or { panic(err) }
	jobs.drain()
	source.error('source failure')
	jobs.drain()
	assert jobs.aborts == 0
	assert piped.state() == .pending
	write.resolve(webidl.undefined_value())
	jobs.drain()
	assert jobs.aborts == 1
	assert piped.state() == .pending
	abort.reject(webidl.string_value('abort action failure'))
	jobs.drain()
	assert piped.reason() == 'abort action failure'
	assert !source.locked() && !destination.locked()
}

fn test_pipe_write_failure_waits_for_real_source_cancel_promise() {
	mut jobs := &PipeCallbackJobs{}
	realm := jobs.realm(734)
	mut write := webidl.create_promise_for(realm.promise_context())
	mut cancel := webidl.create_promise_for(realm.promise_context())
	mut source := ReadableStream.create(realm, UnderlyingSource{
		cancel_promise: fn [mut jobs, cancel] (_ Value) !&webidl.Promise {
			jobs.cancels++
			return cancel
		}
	}, QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	mut destination := WritableStream.create(realm, UnderlyingSink{
		write_promise: fn [write] (_ Value) !&webidl.Promise { return write }
	}, QueuingStrategy{}) or { panic(err) }
	piped := source.pipe_to(mut destination, StreamPipeOptions{})
	jobs.drain()
	source.enqueue(string_value('rejected write')) or { panic(err) }
	jobs.drain()
	write.reject(webidl.string_value('sink failure'))
	jobs.drain()
	assert jobs.cancels == 1
	assert source.state() == .closed
	assert piped.state() == .pending
	assert source.locked() && destination.locked()
	cancel.resolve(webidl.undefined_value())
	jobs.drain()
	assert piped.reason() == 'sink failure'
	assert !source.locked() && !destination.locked()
}

fn test_pipe_abort_signal_waits_for_both_real_shutdown_actions() {
	mut jobs := &PipeCallbackJobs{}
	realm := jobs.realm(735)
	mut abort := webidl.create_promise_for(realm.promise_context())
	mut cancel := webidl.create_promise_for(realm.promise_context())
	mut signal := AbortSignal.create()
	mut source := ReadableStream.create(realm, UnderlyingSource{
		cancel_promise: fn [mut jobs, cancel] (_ Value) !&webidl.Promise {
			jobs.cancels++
			return cancel
		}
	}, QueuingStrategy{ high_water_mark: 0 }) or { panic(err) }
	mut destination := WritableStream.create(realm, UnderlyingSink{
		abort_promise: fn [mut jobs, abort] (_ Value) !&webidl.Promise {
			jobs.aborts++
			return abort
		}
	}, QueuingStrategy{}) or { panic(err) }
	piped := source.pipe_to(mut destination, StreamPipeOptions{ signal: signal })
	jobs.drain()
	signal.abort(string_value('signal stop'))
	jobs.drain()
	assert jobs.aborts == 1 && jobs.cancels == 1
	assert piped.state() == .pending
	abort.resolve(webidl.undefined_value())
	jobs.drain()
	assert piped.state() == .pending
	cancel.resolve(webidl.undefined_value())
	jobs.drain()
	assert piped.reason() == 'signal stop'
	assert !source.locked() && !destination.locked()
}
