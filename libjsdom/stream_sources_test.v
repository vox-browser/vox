// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import os
import platform
import rand

fn test_readable_constructor_runs_start_synchronously_and_pulls_after_construction() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var events=[],controller,source={start(c){events.push("start");controller=c;if(this!==source)throw 1},pull(c){events.push("pull");if(this!==source||c!==controller)throw 2;c.enqueue({value:7});c.close()}};var s=new ReadableStream(source);events.push("constructed");var r=s.getReader(),value,done=false;r.read().then(x=>value=x.value);r.read().then(x=>done=x.done);events.join()')!.as_string().str() == 'start,constructed'
	assert stream_eval(mut vm, 'events.join()==="start,constructed,pull"&&value.value===7&&done&&s.locked&&controller.desiredSize===0')!.as_bool()
}

fn test_readable_constructor_and_controller_metadata_and_native_brands() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var c,s=new ReadableStream({start(x){c=x}}),bad=0;for(var f of [()=>ReadableStream(),()=>new ReadableStreamDefaultController(),()=>ReadableStreamDefaultController(),()=>ReadableStreamDefaultController.prototype.enqueue.call({}),()=>ReadableStreamDefaultController.prototype.close.call(new Proxy(c,{})),()=>ReadableByteStreamController.prototype.error.call(c)])try{f()}catch(e){if(e instanceof TypeError)bad++}bad===6&&s instanceof ReadableStream&&c instanceof ReadableStreamDefaultController&&c.constructor===ReadableStreamDefaultController&&s.constructor===ReadableStream&&ReadableStream.length===0&&c.enqueue.length===0&&c.close.length===0&&c.error.length===0&&Object.prototype.toString.call(c)==="[object ReadableStreamDefaultController]"&&!Object.getOwnPropertyDescriptor(ReadableStream,"prototype").writable&&Object.getOwnPropertyDescriptor(ReadableStream.prototype,"constructor").configurable')!.as_bool()
}

fn test_readable_controllers_are_rejected_by_history_storage_clone() {
	mut host, mut vm, _ := history_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var a,b;new ReadableStream({start(c){a=c}});new ReadableStream({type:"bytes",start(c){b=c}});var rejected=0;for(var c of [a,b])try{history.replaceState(c,"")}catch(e){if(e instanceof DOMException&&e.name==="DataCloneError")rejected++}rejected===2')!.as_bool()
}

fn test_readable_constructor_preserves_dictionary_and_new_target_getter_order() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var order=[],strategy={get highWaterMark(){order.push("hwm");return {valueOf(){order.push("number");return 2}}},get size(){order.push("size");return undefined}},source={get autoAllocateChunkSize(){order.push("auto");return undefined},get cancel(){order.push("cancel");return undefined},get pull(){order.push("pull");return undefined},get start(){order.push("start");return undefined},get type(){order.push("type");return undefined}},target=new Proxy(function(){},{get(t,k){if(k==="prototype")order.push("prototype");return Reflect.get(t,k)}});var s=Reflect.construct(ReadableStream,[source,strategy],target);order.join()==="hwm,number,size,prototype,auto,cancel,pull,start,type"&&Object.getPrototypeOf(s)===target.prototype')!.as_bool()
}

fn test_readable_constructor_rejects_webidl_types_and_native_strategy_values() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var types=0,ranges=0;for(var f of [()=>new ReadableStream(null),()=>new ReadableStream(1),()=>new ReadableStream({},1),()=>new ReadableStream({start:null}),()=>new ReadableStream({pull:1}),()=>new ReadableStream({cancel:{}}),()=>new ReadableStream({type:"invalid"}),()=>new ReadableStream({}, {size:null}),()=>new ReadableStream({type:"bytes",autoAllocateChunkSize:0}),()=>new ReadableStream({autoAllocateChunkSize:Infinity})])try{f()}catch(e){if(e instanceof TypeError)types++}for(var f of [()=>new ReadableStream({},{highWaterMark:NaN}),()=>new ReadableStream({},{highWaterMark:-1}),()=>new ReadableStream({type:"bytes"},{size(){return 1}})])try{f()}catch(e){if(e instanceof RangeError)ranges++}types===10&&ranges===3&&new ReadableStream(undefined,null) instanceof ReadableStream')!.as_bool()
}

fn test_readable_byte_auto_allocation_limit_rejects_read_after_successful_construction() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var c,bad=false,s=new ReadableStream({type:"bytes",autoAllocateChunkSize:2147483648,start(x){c=x}}),r=s.getReader();r.read().catch(e=>bad=e instanceof RangeError)')!
	assert stream_eval(mut vm, 'bad&&c.desiredSize===0&&s.locked')!.as_bool()
}

fn test_readable_invalid_size_shares_original_range_error_with_pending_closed_promise() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var c,thrown,rejected,same=false,s=new ReadableStream({start(x){c=x}},{size(){return NaN}}),r=s.getReader();r.closed.catch(e=>rejected=e);try{c.enqueue(1)}catch(e){thrown=e}r.read().catch(e=>same=e===thrown)')!
	assert stream_eval(mut vm, 'thrown instanceof RangeError&&rejected===thrown&&same')!.as_bool()
}

fn test_readable_start_throw_preserves_reason_and_escaped_controller_errors() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var marker=Symbol("start"),c,same=false;try{new ReadableStream({start(x){c=x;throw marker}})}catch(e){same=e===marker}var bad=false;try{c.enqueue(1)}catch(e){bad=e instanceof TypeError}same&&bad&&c.desiredSize===null')!.as_bool()
	assert host.stream_sources.len == 0
}

fn test_readable_start_assimilates_public_then_and_preserves_throwing_getter_reason() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var marker={},gets=0,p=Promise.resolve(),same=false,c;Object.defineProperty(p,"then",{get(){gets++;throw marker}});var s=new ReadableStream({start(x){c=x;return p},pull(){throw 123}});s.getReader().read().catch(e=>same=e===marker)')!
	assert stream_eval(mut vm, 'gets===1&&same&&c.desiredSize===null')!.as_bool()
}

fn test_readable_start_thenable_and_peer_promise_reactions_share_fifo() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var events=[];new ReadableStream({start(){events.push("start");return {then(resolve){events.push("then");resolve()}}},pull(c){events.push("pull");c.close()}});events.push("constructed");Promise.resolve().then(()=>events.push("peer"))')!
	assert stream_eval(mut vm, 'events.join()==="start,constructed,then,peer,pull"')!.as_bool()
}

fn test_readable_start_waits_for_pending_promise_before_pulling() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var release,pulls=0,value;var s=new ReadableStream({start(){return new Promise(r=>release=r)},pull(c){pulls++;c.enqueue(9);c.close()}});s.getReader().read().then(x=>value=x.value)')!
	assert stream_eval(mut vm, 'pulls===0&&value===undefined')!.as_bool()
	stream_eval(mut vm, 'release()')!
	assert stream_eval(mut vm, 'pulls===1&&value===9')!.as_bool()
	assert host.stream_adoptions.len == 0
}

fn test_readable_pending_pull_does_not_overlap_and_repulls_after_settlement() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var release,pulls=0,a,b,c;var s=new ReadableStream({start(x){c=x},pull(x){pulls++;if(pulls===1)return new Promise(r=>release=r);x.enqueue(2);x.close()}}),r=s.getReader();r.read().then(x=>a=x.value);r.read().then(x=>b=x.value)')!
	assert stream_eval(mut vm, 'pulls===1&&a===undefined&&b===undefined')!.as_bool()
	stream_eval(mut vm, 'c.enqueue(1);release()')!
	assert stream_eval(mut vm, 'pulls===2&&a===1&&b===2')!.as_bool()
}

fn test_readable_pull_rejection_preserves_symbol_and_closed_promise_reason() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var marker=Symbol("pull"),a=false,b=false;var s=new ReadableStream({pull(){return Promise.reject(marker)}}),r=s.getReader();r.read().catch(e=>a=e===marker);r.closed.catch(e=>b=e===marker)')!
	assert stream_eval(mut vm, 'a&&b')!.as_bool()
}

fn test_readable_cancel_preserves_callback_this_reason_and_assimilated_return() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var marker={},reason,receiver,release,done=false,source={cancel(x){reason=x;receiver=this;return new Promise(r=>release=r)}};var s=new ReadableStream(source);s.cancel(marker).then(()=>done=true)')!
	assert stream_eval(mut vm, 'reason===marker&&receiver===source&&!done')!.as_bool()
	stream_eval(mut vm, 'release(123)')!
	assert stream_eval(mut vm, 'done')!.as_bool()
}

fn test_readable_size_callback_uses_actual_chunk_undefined_this_and_single_to_number() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var c,marker={},calls=0,numbers=0,s=new ReadableStream({start(x){c=x}},{highWaterMark:5,size:function(x){"use strict";if(this!==undefined||x!==marker)throw 1;calls++;return {valueOf(){numbers++;return 2}}}});c.enqueue(marker);c.desiredSize===3&&calls===1&&numbers===1')!.as_bool()
	stream_eval(mut vm, 'var actual;s.getReader().read().then(x=>actual=x.value)')!
	assert stream_eval(mut vm, 'actual===marker')!.as_bool()
}

fn test_readable_size_throw_errors_stream_with_same_author_object() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var c,marker={},same=false,rejected=false,s=new ReadableStream({start(x){c=x}},{size(){throw marker}});try{c.enqueue(1)}catch(e){same=e===marker}s.getReader().read().catch(e=>rejected=e===marker)')!
	assert stream_eval(mut vm, 'same&&rejected&&c.desiredSize===null')!.as_bool()
}

fn test_readable_default_controller_retains_actual_chunks_and_error_values() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var c,values=[],s=new ReadableStream({start(x){c=x}}),r=s.getReader(),symbol=Symbol("chunk"),object={};r.read().then(x=>values.push(x.value));c.enqueue(symbol);c.enqueue(object);c.enqueue(123n);r.read().then(x=>values.push(x.value));r.read().then(x=>values.push(x.value));var same=false,marker=Symbol("error");r.closed.catch(e=>same=e===marker);c.error(marker)')!
	assert stream_eval(mut vm, 'values.length===3&&values[0]===symbol&&values[1]===object&&values[2]===123n&&same')!.as_bool()
}

fn test_readable_byte_controller_transfers_only_view_window_and_closes() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var c,s=new ReadableStream({type:"bytes",start(x){c=x}}),r=s.getReader(),view=new Uint8Array([0,11,12,0]),text="",done=false;r.read().then(x=>text=x.value.join());c.enqueue(view.subarray(1,3));c.close();r.read().then(x=>done=x.done);var detached=view.buffer.byteLength===0')!
	assert stream_eval(mut vm, 'detached&&text==="11,12"&&done&&c instanceof ReadableByteStreamController&&c.enqueue.length===1&&c.desiredSize===0')!.as_bool()
}

fn test_readable_byte_controller_accepts_dataview_and_checks_state_before_transfer() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var c,s=new ReadableStream({type:"bytes",start(x){c=x}}),view=new Uint8Array([0,4,5]),result="";c.enqueue(new DataView(view.buffer,1,2));c.close();var live=new Uint8Array([8]),bad=0;for(var f of [()=>c.enqueue(live),()=>c.close(),()=>c.enqueue(new ArrayBuffer(1)),()=>c.enqueue(new Uint8Array(0))])try{f()}catch(e){if(e instanceof TypeError)bad++}s.getReader().read().then(x=>result=x.value.join())')!
	assert stream_eval(mut vm, 'result==="4,5"&&bad===4&&live.buffer.byteLength===1&&view.buffer.byteLength===0')!.as_bool()
}

fn test_authored_uint8_stream_is_consumed_by_native_response_body_read_loop() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	stream_eval(mut vm, 'var source=new ReadableStream({start(c){c.enqueue(new TextEncoder().encode("compiled stream 😀"));c.close()}}),response=new Response(source),text="";response.text().then(x=>text=x)')!
	stream_tasks_drain(mut vm)
	assert stream_eval(mut vm, 'response.body===source&&response.bodyUsed&&text==="compiled stream 😀"')!.as_bool()
	assert seen.errors.len == 0
}

fn test_authored_stream_callback_records_and_jobs_survive_arena_reset_and_detach_at_close() {
	mut host, mut vm := text_encoding_fixture()!
	mut arena := platform.new_arena('Readable source callback records')
	entry := arena.enter()
	stream_eval(mut vm, 'var release,s=new ReadableStream({start(){return new Promise(r=>release=r)},pull(c){c.close()}})')!
	arena.leave(entry)
	for _, record in host.stream_sources { assert !arena.contains(record) }
	for _, record in host.stream_adoptions { assert !arena.contains(record) }
	arena.reset(); arena.release()
	stream_eval(mut vm, 'release()')!
	assert stream_eval(mut vm, 's instanceof ReadableStream')!.as_bool()
	host.close()
	assert host.stream_sources.len == 0 && host.stream_adoptions.len == 0 && host.stream_source_jobs.len == 0
}

fn test_cached_authored_stream_callbacks_revisit_without_invoking_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-authored-stream-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := text_encoding_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		stream_eval(mut vm, 'function produce(c){c.enqueue(17);c.close()}function accept(x){result=x.value}var result;new ReadableStream({pull:produce}).getReader().read().then(accept)')!
		assert stream_eval(mut vm, 'result===17')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
	}
}
