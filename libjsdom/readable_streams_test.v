// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import streams
import platform

fn readable_stream_fixture() !(&Host, &libjs.VM, &streams.ReadableStream) {
	mut host, mut vm := text_encoding_fixture()!
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	native := streams.ReadableStream.construct_impl(streams.UnderlyingSource{type_: .bytes}, streams.QueuingStrategy{})!
	value := host.wrap_readable_stream(native, none)
	mut global := vm.global_object()
	global.create_data_property_or_throw(mut vm, libjs.PropertyName.from_str('stream'), value)!
	return host, vm, native
}

fn stream_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-stream.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 200000}) or { return error(exception_message(err)) }
}

fn test_native_stream_reader_returns_real_promises_and_uint8_chunks_without_early_jobs() {
	mut host, mut vm, mut native := readable_stream_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var reader=stream.getReader(),values=[],finished=false,p=reader.read();p.then(x=>values.push(x));reader.closed.then(()=>finished=true);p instanceof Promise&&reader instanceof ReadableStreamDefaultReader&&stream.locked&&values.length===0&&!finished')!.as_bool()
	native.enqueue(streams.bytes_value('abc'.bytes()))!
	native.close()
	assert stream_eval(mut vm, 'values.length===0&&!finished')!.as_bool()
	vm.run_queued_promise_jobs()
	assert stream_eval(mut vm, 'values.length===1&&values[0].value instanceof Uint8Array&&values[0].value.join()==="97,98,99"&&!values[0].done&&finished')!.as_bool()
}

fn test_native_stream_reader_locks_release_and_reacquire_live_native_stream() {
	mut host, mut vm, mut native := readable_stream_fixture()!
	defer { host.close() }
	native.enqueue(streams.bytes_value([u8(1),2]))!
	assert stream_eval(mut vm, 'var r=stream.getReader(),bad=false;try{stream.getReader()}catch(e){bad=e instanceof TypeError}bad&&stream.locked&&(r.releaseLock(),!stream.locked)&&new ReadableStreamDefaultReader(stream) instanceof ReadableStreamDefaultReader&&stream.locked')!.as_bool()
}

fn test_native_stream_release_rejects_pending_reads_and_pending_closed_promise() {
	mut host, mut vm, _ := readable_stream_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var r=stream.getReader(),closed=r.closed,readError=false,closedError=false,afterError=false;r.read().catch(e=>readError=e instanceof TypeError);closed.catch(e=>closedError=e instanceof TypeError);r.releaseLock();var after=r.closed;after.catch(e=>afterError=e instanceof TypeError)')!
	assert stream_eval(mut vm, 'readError&&closedError&&afterError&&closed===after&&after===r.closed&&!stream.locked')!.as_bool()
	assert host.stream_reads.len == 0
}

fn test_native_stream_release_after_closed_replaces_fulfilled_closed_promise() {
	mut host, mut vm, mut native := readable_stream_fixture()!
	defer { host.close() }
	native.close()
	stream_eval(mut vm, 'var r=stream.getReader(),old=r.closed,fulfilled=false,rejected=false;old.then(()=>fulfilled=true);r.releaseLock();r.closed.catch(e=>rejected=e instanceof TypeError);var changed=old!==r.closed')!
	assert stream_eval(mut vm, 'fulfilled&&rejected&&changed')!.as_bool()
}

fn test_native_stream_closed_promise_and_stream_wrapper_identity_are_stable() {
	mut host, mut vm, native := readable_stream_fixture()!
	defer { host.close() }
	before := host.closures.len
	assert stream_eval(mut vm, 'var r=stream.getReader();r.closed===r.closed&&r.closed instanceof Promise&&Object.prototype.toString.call(stream)==="[object ReadableStream]"&&Object.prototype.toString.call(r)==="[object ReadableStreamDefaultReader]"&&r.read.length===0&&r.cancel.length===0&&r.releaseLock.length===0')!.as_bool()
	assert voidptr(host.wrap_readable_stream(native, none).as_object()) == voidptr(vm.global_object().get(mut vm, libjs.PropertyName.from_str('stream'))!.as_object())
	assert host.closures.len == before
}

fn test_native_stream_cancel_and_reader_cancel_follow_native_lock_and_closed_states() {
	mut host, mut vm, mut native := readable_stream_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var r=stream.getReader(),bad=false,canceled=false,done=false;stream.cancel().catch(e=>bad=e instanceof TypeError);r.cancel({reason:1}).then(()=>canceled=true);r.read().then(x=>done=x.done&&x.value===undefined)')!
	assert stream_eval(mut vm, 'bad&&canceled&&done&&stream.locked&&(r.releaseLock(),!stream.locked)')!.as_bool()
	assert native.is_closed() && native.is_disturbed()
}

fn test_native_stream_reader_errors_preserve_original_abort_values() {
	mut host, mut vm, mut native := readable_stream_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var marker={toString(){throw 1}},r=stream.getReader(),a=false,b=false;r.read().catch(e=>a=e===marker);r.closed.catch(e=>b=e===marker)')!
	marker := vm.global_object().get(mut vm, libjs.PropertyName.from_str('marker'))!
	persistent := platform.enter_persistent()
	native.error_value(host.stream_webidl_value(marker))
	platform.leave_persistent(persistent)
	vm.run_queued_promise_jobs()
	assert stream_eval(mut vm, 'a&&b')!.as_bool()
}

fn test_native_stream_webidl_receiver_and_reader_option_errors() {
	mut host, mut vm, _ := readable_stream_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var errors=0,p=Object.getPrototypeOf(stream),reads=0;for(var f of [()=>p.getReader.call({},{get mode(){reads++;return undefined}}),()=>stream.getReader({mode:"invalid"}),()=>stream.getReader(1),()=>new ReadableStreamDefaultReader({}),()=>ReadableStreamDefaultReader(stream),()=>p.getReader.call(new Proxy(stream,{}))])try{f()}catch(e){if(e instanceof TypeError)errors++}errors===6&&reads===0')!.as_bool()
	stream_eval(mut vm, 'var r=stream.getReader(),count=0,proto=Object.getPrototypeOf(r);proto.read.call({}).catch(e=>{if(e instanceof TypeError)count++});proto.cancel.call({}).catch(e=>{if(e instanceof TypeError)count++})')!
	assert stream_eval(mut vm, 'count===2')!.as_bool()
}

fn test_native_stream_pending_read_records_survive_arena_reset_and_close_drops_roots() {
	mut host, mut vm, mut native := readable_stream_fixture()!
	mut arena := platform.new_arena('native stream pending read records')
	entry := arena.enter()
	stream_eval(mut vm, 'var r=stream.getReader(),text="";r.read().then(x=>text=new TextDecoder().decode(x.value));var closed=r.closed')!
	arena.leave(entry)
	for _, request in host.stream_reads { assert !arena.contains(request) }
	arena.reset(); arena.release()
	native.enqueue(streams.bytes_value('kept'.bytes()))!
	vm.run_queued_promise_jobs()
	assert stream_eval(mut vm, 'text==="kept"')!.as_bool()
	stream_eval(mut vm, 'r.read()')!
	assert host.stream_reads.len == 1
	host.close()
	assert host.stream_reads.len == 0 && host.stream_promises.len == 0 && host.readable_streams.len == 0 && host.stream_readers.len == 0
}
