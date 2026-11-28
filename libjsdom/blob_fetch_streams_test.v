// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs
import os
import rand
import platform

fn stream_tasks_drain(mut vm libjs.VM) {
	for _ in 0 .. 256 {
		html.perform_a_microtask_checkpoint()
		vm.run_queued_promise_jobs()
		mut queue := html.main_thread_event_loop().task_queue()
		task := queue.take_first_runnable() or { return }
		task.execute()
	}
	assert false, 'Native stream tasks did not settle'
}

fn test_blob_stream_delivers_native_bytes_after_file_reading_and_closes_reader() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var blob=new Blob(["GitHub 😀"]),a=blob.stream(),b=blob.stream(),r=a.getReader(),text="",closed=false,done=false;r.read().then(x=>text=new TextDecoder().decode(x.value));r.closed.then(()=>closed=true);a!==b&&a.locked&&!b.locked&&text===""&&!closed&&Blob.prototype.stream.length===0')!.as_bool()
	assert host.blob_stream_tasks.len == 2
	stream_tasks_drain(mut vm)
	stream_eval(mut vm, 'r.read().then(x=>done=x.done&&x.value===undefined)')!
	assert stream_eval(mut vm, 'text==="GitHub 😀"&&closed&&done')!.as_bool()
}

fn test_blob_stream_errors_check_receiver_and_empty_stream_finishes() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var bad=false;try{Blob.prototype.stream.call({})}catch(e){bad=e instanceof TypeError}bad')!.as_bool()
	stream_eval(mut vm, 'var text="",finished=false;async function readEmpty(){var r=new Blob().stream().getReader();for(;;){var x=await r.read();if(x.done)break;text+=new TextDecoder().decode(x.value)}finished=true}readEmpty()')!
	stream_tasks_drain(mut vm)
	assert stream_eval(mut vm, 'finished&&text===""')!.as_bool()
}

fn test_fetch_body_getters_are_native_nullable_and_retain_stream_identity() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	assert stream_eval(mut vm, 'var r=new Response("abc"),q=new Request("/post",{method:"POST",body:"def"});new Response().body===null&&new Request("/get").body===null&&r.body===r.body&&q.body===q.body&&Object.prototype.toString.call(r.body)==="[object ReadableStream]"&&!r.bodyUsed&&!q.bodyUsed&&Object.getOwnPropertyDescriptor(Response.prototype,"body").enumerable')!.as_bool()
	assert stream_eval(mut vm, 'var bad=false;try{Object.getOwnPropertyDescriptor(Response.prototype,"body").get.call({})}catch(e){bad=e instanceof TypeError}bad')!.as_bool()
	assert seen.errors.len == 0
}

fn test_fetch_body_reader_updates_body_used_and_prevents_second_consumer() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	stream_eval(mut vm, 'var response=new Response("native body"),reader=response.body.getReader(),text="",bad=false,done=false;response.text().catch(e=>bad=e instanceof TypeError);reader.read().then(x=>text=new TextDecoder().decode(x.value));reader.read().then(x=>done=x.done)')!
	stream_tasks_drain(mut vm)
	assert stream_eval(mut vm, 'response.bodyUsed&&response.body.locked&&text==="native body"&&bad&&done')!.as_bool()
	assert seen.errors.len == 0
}

fn test_fetch_response_clone_preserves_native_tee_branches_and_prior_stream_lock() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	stream_eval(mut vm, 'var response=new Response("branched"),old=response.body,copy=response.clone(),a="",b="";var changed=old!==response.body&&old.locked;response.body.getReader().read().then(x=>a=new TextDecoder().decode(x.value));copy.body.getReader().read().then(x=>b=new TextDecoder().decode(x.value))')!
	stream_tasks_drain(mut vm)
	assert stream_eval(mut vm, 'changed&&a==="branched"&&b==="branched"&&response.bodyUsed&&copy.bodyUsed')!.as_bool()
	assert seen.errors.len == 0
}

fn test_blob_stream_can_supply_response_body_and_request_stream_guards() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	stream_eval(mut vm, 'var stream=new Blob(["streamed"]).stream(),r=new Response(stream),text="";r.text().then(x=>text=x);var errors=0;for(var options of [{method:"POST",body:new Blob(["x"]).stream()},{method:"POST",body:new Blob(["x"]).stream(),duplex:"half",keepalive:true}])try{new Request("/post",options)}catch(e){if(e instanceof TypeError)errors++}')!
	stream_tasks_drain(mut vm)
	assert stream_eval(mut vm, 'r.body===stream&&r.bodyUsed&&text==="streamed"&&errors===2')!.as_bool()
	assert seen.errors.len == 0
}

fn test_fetch_stream_body_lock_is_validated_after_later_argument_getters() {
	mut host, mut vm, mut document, _ := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	assert stream_eval(mut vm, 'var s=new Blob(["x"]).stream(),bad=false,reads=0;try{new Response(s,{get headers(){reads++;s.getReader();return {}}})}catch(e){bad=e instanceof TypeError}bad&&reads===1&&s.locked')!.as_bool()
}

fn test_fetch_body_reader_preserves_abort_reason_after_headers_and_network_delivery() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	stream_eval(mut vm, 'var c=new AbortController(),response;fetch("/data",{signal:c.signal}).then(r=>response=r)')!
	stream_tasks_drain(mut vm)
	stream_eval(mut vm, 'var marker={},r=response.body.getReader(),same=false;c.abort(marker);r.read().catch(e=>same=e===marker)')!
	stream_tasks_drain(mut vm)
	assert stream_eval(mut vm, 'same&&response.bodyUsed')!.as_bool()
	assert seen.errors.len == 0 && host.fetch_signal_operations.len == 0
}

fn test_blob_stream_task_and_reader_owners_survive_arena_reset_and_close_discards_delivery() {
	mut host, mut vm := text_encoding_fixture()!
	mut arena := platform.new_arena('Blob stream native task and reader owners')
	entry := arena.enter()
	stream_eval(mut vm, 'var s=new Blob(["kept"]).stream(),r=s.getReader(),settled=false;r.read().then(()=>settled=true)')!
	arena.leave(entry)
	for _, binding in host.blob_stream_tasks { assert !arena.contains(binding) && !arena.contains(binding.task) }
	arena.reset(); arena.release()
	mut tasks := []&html.Task{}
	for _, binding in host.blob_stream_tasks { tasks << binding.task }
	host.close()
	assert host.blob_stream_tasks.len == 0 && host.stream_reads.len == 0
	mut queue := html.main_thread_event_loop().task_queue()
	for task in tasks {
		matches := fn [task] (candidate &html.Task) bool { return voidptr(candidate) == voidptr(task) }
		assert queue.take_first_runnable_matching(matches) == none
		platform.release_closure(voidptr(matches))
	}
	assert !vm.global_object().get(mut vm, libjs.PropertyName.from_str('settled'))!.as_bool()
}

fn test_cached_blob_and_fetch_body_readers_revisit_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-native-body-stream-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, mut document, seen := native_fetch_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		stream_eval(mut vm, 'function firstText(stream){return stream.getReader().read().then(x=>new TextDecoder().decode(x.value))}var a="",b="";firstText(new Blob(["Blob 😀"]).stream()).then(s=>a=s);firstText(new Response("Fetch 😀").body).then(s=>b=s)')!
		stream_tasks_drain(mut vm)
		assert stream_eval(mut vm, 'a==="Blob 😀"&&b==="Fetch 😀"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		assert seen.errors.len == 0
		vm.close_native_code()!
		host.close(); document.finalize()
	}
}
