// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import platform
import streams
import webidl

@[heap]
struct StreamSourceJob {
mut:
	host ?&Host
	callback ?fn ()
	wrapper voidptr
}

fn (mut host Host) release_retired_stream_jobs() {
	if host.stream_source_job_depth != 0 { return }
	for callback in host.retired_stream_source_jobs { platform.release_closure(callback) }
	host.retired_stream_source_jobs.clear()
}

fn (mut host Host) schedule_stream_source_job(callback fn ()) {
	if host.closed { platform.release_closure(voidptr(callback)); return }
	// An adoption handler already occupies the source Promise reaction's turn.
	// Consume only its immediate native reaction here; subsequent jobs retain
	// their ordinary FIFO position in the owning VM/HTML microtask queue.
	if host.stream_inline_native_job {
		host.stream_inline_native_job = false
		callback()
		platform.release_closure(voidptr(callback))
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	host.release_retired_stream_jobs()
	mut record := &StreamSourceJob{host: &host, callback: callback}
	wrapper := fn [mut record] () !libjs.Value {
		mut owner := record.host or { return libjs.js_undefined() }
		owner.release_retired_stream_jobs()
		owner.stream_source_job_depth++
		defer {
			owner.stream_source_job_depth--
			owner.stream_source_jobs.delete(voidptr(record))
			owner.retired_stream_source_jobs << record.wrapper
			record.host = none
		}
		job := record.callback or { return libjs.js_undefined() }
		record.callback = none
		defer { platform.release_closure(voidptr(job)) }
		return owner.stream_entry(fn [job] (mut vm libjs.VM) !libjs.Value {
			vm.consume_execution_budget()!
			job()
			return libjs.js_undefined()
		})
	}
	record.wrapper = voidptr(wrapper)
	host.stream_source_jobs[voidptr(record)] = record
	host.vm.host_enqueue_promise_job(wrapper, host.realm)
}

fn (mut host Host) authored_stream_realm() streams.StreamRealm {
	if realm := host.stream_source_realm { return realm }
	schedule := fn [mut host] (job fn ()) { host.schedule_stream_source_job(job) }
	bytes := fn [mut host] (value webidl.Value) !streams.ReadLoopChunkBytes {
		host.require_open(mut host.vm)!
		actual := host.abort_reason_value(mut host.vm, value)!
		if !actual.is_object() { return streams.ReadLoopChunkBytes{} }
		array := actual.as_object().typed_array or { return streams.ReadLoopChunkBytes{} }
		if array.kind != .uint8 { return streams.ReadLoopChunkBytes{} }
		return streams.ReadLoopChunkBytes{bytes: copy_native_buffer_source(mut host.vm, actual.as_object())!}
	}
	host.closures << voidptr(schedule)
	host.closures << voidptr(bytes)
	realm := streams.StreamRealm{
		id: u64(voidptr(host.realm))
		promise_context_: &webidl.PromiseContext{realm_id: u64(voidptr(host.realm)), job_scheduler: schedule}
		uint8_array_bytes: bytes
	}
	host.stream_source_realm = realm
	return realm
}

fn (mut host Host) close_stream_sources() {
	for _, mut source in host.stream_sources { source.clear() }
	host.stream_sources.clear()
	for _, mut adoption in host.stream_adoptions { adoption.host = none; adoption.native = none }
	host.stream_adoptions.clear()
	// Host.close is called after the embedding has stopped VM entry. Pending
	// jobs become inert before their callback/trampoline captures are released.
	for _, mut record in host.stream_source_jobs {
		record.host = none
		if callback := record.callback { platform.release_closure(voidptr(callback)) }
		record.callback = none
		platform.release_closure(record.wrapper)
	}
	host.stream_source_jobs.clear()
	host.release_retired_stream_jobs()
	host.stream_source_realm = none
}
