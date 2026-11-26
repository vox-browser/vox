// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs
import os
import rand
import platform

fn blob_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-blob.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 200000}) or { return error(exception_message(err)) }
}

fn blob_drain(mut host Host, mut vm libjs.VM) {
	for _ in 0 .. 128 {
		if host.blob_reads.len == 0 { vm.run_queued_promise_jobs(); return }
		mut queue := html.main_thread_event_loop().task_queue()
		select := fn (task &html.Task) bool { return task.source == .file_reading }
		task := queue.take_first_runnable_matching(select) or { assert false; return }
		task.execute()
	}
	assert false, 'Blob file-reading tasks did not settle'
}

fn test_blob_constructor_uses_utf8_usv_buffers_blobs_and_type_normalization() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert blob_eval(mut vm, 'var empty=new Blob(),b=new Blob(["Aé😀\\ud800\\x00",new Uint8Array([1,2]),new Blob(["Z"])],{type:"TEXT/PLAIN"});empty.size===0&&empty.type===""&&b.size===14&&b.type==="text/plain"&&new Blob(["a\\r\\nb\\rc\\n"],{endings:"native"}).size===6&&new Blob([],{type:"NonParsable"}).type==="nonparsable"&&new Blob([],{type:"x\\u007fy"}).type===""')!.as_bool()
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('b'))!
	native := host.blobs[voidptr(value.as_object())] or { panic('Missing native Blob') }
	assert native.raw_bytes() == [u8(65), 195, 169, 240, 159, 152, 128, 239, 191, 189, 0, 1, 2, 90]
}

fn test_blob_part_conversion_precedes_options_and_byte_copy_follows_prototype_getter() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert blob_eval(mut vm, 'var log="",a=new Uint8Array([1]),source={*[Symbol.iterator](){log+="i";yield a;yield {toString(){log+="s";return "X"}};log+="d"}},N=new Proxy(function(){},{get(t,k,r){if(k==="prototype"){log+="p";a[0]=4;return Blob.prototype}return Reflect.get(t,k,r)}}),b=Reflect.construct(Blob,[source,{get endings(){log+="e";a[0]=2;return "transparent"},get type(){log+="t";a[0]=3;return "TEXT/X"}}],N);log==="isdetp"&&b.type==="text/x"&&b.size===2')!.as_bool()
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('b'))!
	assert (host.blobs[voidptr(value.as_object())] or { panic('Missing Blob') }).raw_bytes() == [u8(4), 88]
}

fn test_blob_buffer_sources_copy_only_view_bytes_and_detached_sources_are_empty() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert blob_eval(mut vm, 'var a=new Uint8Array([88,65,66,89]),b=new Blob([new DataView(a.buffer,1,2),a.subarray(1,3)]);a.fill(0);var c=new Uint8Array([1]);new Blob([c],{get type(){c.buffer.transfer();return ""}}).size===0&&b.size===4')!.as_bool()
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('b'))!
	assert (host.blobs[voidptr(value.as_object())] or { panic('Missing Blob') }).raw_bytes() == [u8(65), 66, 65, 66]
}

fn test_blob_sequence_rejects_primitives_and_closes_iterator_on_part_conversion_error() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert blob_eval(mut vm, 'var count=0;for(var f of [()=>Blob(),()=>new Blob(null),()=>new Blob("parts"),()=>new Blob({length:1,0:"x"}),()=>new Blob([],{endings:"bad"}),()=>new Blob([],1),()=>new Blob([new SharedArrayBuffer(2)]),()=>new Blob([new Uint8Array(new ArrayBuffer(2,{maxByteLength:4}))])])try{f()}catch(e){if(e instanceof TypeError)count++}count===8')!.as_bool()
	assert blob_eval(mut vm, 'var marker={},same=false,closed=0,source={*[Symbol.iterator](){try{yield {toString(){throw marker}}}finally{closed++}}};try{new Blob(source)}catch(e){same=e===marker}same&&closed===1')!.as_bool()
}

fn test_blob_slice_clamps_rounds_negative_positions_and_ignores_species() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert blob_eval(mut vm, 'class B extends Blob{}var b=new B(["abcdef"],{type:"text/x"});Object.defineProperty(b,"constructor",{get(){throw 1}});var s=b.slice(1.5,3.5,"TEXT/Y");b instanceof B&&s instanceof Blob&&!(s instanceof B)&&s.size===2&&s.type==="text/y"&&b.slice(-2).size===2&&b.slice(4,1).size===0&&b.slice(-Infinity,Infinity).size===6&&b.slice(NaN,2.5).size===2&&b.slice().type===""')!.as_bool()
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('s'))!
	assert (host.blobs[voidptr(value.as_object())] or { panic('Missing Blob') }).raw_bytes() == 'cd'.bytes()
}

fn test_blob_metadata_receiver_checks_and_abrupt_slice_conversion_order() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert blob_eval(mut vm, 'var b=new Blob(),p=Blob.prototype,g=Object.getOwnPropertyDescriptor(p,"size");Blob.length===0&&p.slice.length===0&&p.text.length===0&&p.arrayBuffer.length===0&&p.bytes.length===0&&Object.keys(b).length===0&&Object.prototype.toString.call(b)==="[object Blob]"&&g.enumerable&&g.configurable&&!g.set&&!Object.getOwnPropertyDescriptor(Blob,"prototype").writable')!.as_bool()
	assert blob_eval(mut vm, 'var reads=0,errors=0,source={valueOf(){reads++;return 0}};for(var f of [()=>Blob.prototype.slice.call({},source),()=>Object.getOwnPropertyDescriptor(Blob.prototype,"size").get.call(new Proxy(b,{})),()=>b.slice(1n)])try{f()}catch(e){if(e instanceof TypeError)errors++}errors===3&&reads===0')!.as_bool()
	assert blob_eval(mut vm, 'var log="",marker={},same=false;try{b.slice({valueOf(){log+="s";return 0}},{valueOf(){log+="e";throw marker}},{toString(){log+="t";return ""}})}catch(e){same=e===marker}same&&log==="se"')!.as_bool()
}

fn test_blob_read_promises_stay_pending_until_file_reading_and_return_fresh_storage() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert blob_eval(mut vm, 'var b=new Blob(["hello 😀"]),text="",bytes1,bytes2,buffer1,buffer2,settled=0;b.text().then(x=>{text=x;settled++});b.bytes().then(x=>{bytes1=x;settled++});b.bytes().then(x=>{bytes2=x;settled++});b.arrayBuffer().then(x=>{buffer1=x;settled++});b.arrayBuffer().then(x=>{buffer2=x;settled++});settled===0')!.as_bool()
	assert host.blob_reads.len == 5
	blob_drain(mut host, mut vm)
	assert blob_eval(mut vm, 'text==="hello 😀"&&settled===5&&bytes1 instanceof Uint8Array&&bytes2 instanceof Uint8Array&&bytes1!==bytes2&&bytes1.buffer!==bytes2.buffer&&buffer1 instanceof ArrayBuffer&&buffer1!==buffer2&&new TextDecoder().decode(bytes1)===text&&new TextDecoder().decode(buffer1)===text')!.as_bool()
	assert host.blob_reads.len == 0 && vm.take_promise_job_errors().len == 0
}

fn test_blob_text_replaces_malformed_utf8_and_handles_utf8_bom() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	blob_eval(mut vm, 'var text="";new Blob([new Uint8Array([239,187,191,65,255])]).text().then(x=>text=x)')!
	blob_drain(mut host, mut vm)
	assert blob_eval(mut vm, 'text==="A�"')!.as_bool()
}

fn test_blob_promise_receiver_failures_reject_and_history_rejects_before_getters() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert blob_eval(mut vm, 'var count=0,p=Blob.prototype.text.call({}),reads=0,b=new Blob();p.catch(e=>{if(e instanceof TypeError)count++});Blob.prototype.arrayBuffer.call({}).catch(e=>{if(e instanceof TypeError)count++});Blob.prototype.bytes.call({}).catch(e=>{if(e instanceof TypeError)count++});var bad=false;Object.defineProperty(b,"visible",{enumerable:true,get(){reads++;throw 1}});try{history.replaceState(b,"")}catch(e){bad=e.name==="DataCloneError"}p instanceof Promise&&bad&&reads===0')!.as_bool()
	assert blob_eval(mut vm, 'count===3')!.as_bool()
}

fn test_blob_native_records_and_pending_reads_survive_arena_reset_without_new_callbacks() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	before := host.closures.len
	mut arena := platform.new_arena('Blob native records and file-reading task')
	entry := arena.enter()
	blob_eval(mut vm, 'var b=new Blob(["kept"]),slice=b.slice(1),text="";b.text().then(x=>text=x);for(var i=0;i<20;i++)new Blob(["item"+i])')!
	arena.leave(entry)
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('b'))!
	native := host.blobs[voidptr(value.as_object())] or { panic('Missing Blob') }
	assert !arena.contains(value.as_object()) && !arena.contains(native)
	for _, record in host.blob_reads { assert !arena.contains(record) && !arena.contains(record.task?) }
	arena.reset(); arena.release()
	blob_drain(mut host, mut vm)
	assert blob_eval(mut vm, 'text==="kept"&&slice.size===3')!.as_bool()
	assert host.closures.len == before
}

fn test_blob_host_close_discards_owned_tasks_and_releases_native_maps() {
	mut host, mut vm := text_encoding_fixture()!
	blob_eval(mut vm, 'var settled=false;new Blob(["discard"]).text().then(()=>settled=true)')!
	mut pending := []&BlobReadBinding{}
	for _, record in host.blob_reads { pending << record }
	assert pending.len == 1
	host.close()
	for record in pending { assert record.task == none && record.blob == none && record.capability == none }
	assert host.blob_reads.len == 0 && host.blobs.len == 0 && host.blob_wrappers.len == 0
}

fn test_cached_blob_construction_and_reads_revisit_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-native-blob-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := text_encoding_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		blob_eval(mut vm, 'function makeBlob(s){return new Blob([s],{type:"TEXT/PLAIN"})}var result="";makeBlob("GitHub 😀").text().then(x=>result=x)')!
		blob_drain(mut host, mut vm)
		assert blob_eval(mut vm, 'result==="GitHub 😀"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
	}
}
