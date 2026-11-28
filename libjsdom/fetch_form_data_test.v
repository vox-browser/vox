// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import os
import rand

fn test_fetch_form_data_serializes_native_entries_and_original_file_bytes() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	stream_eval(mut vm, 'var f=new FormData;f.append("a","one");f.append("a","two");f.append("file",new File([new Uint8Array([0,255,65])],"bytes.bin",{type:"APPLICATION/OCTET-STREAM"}));f.toString=function(){throw 1};var request=new Request("/post",{method:"POST",body:f}),copy=request.clone(),parsed;copy.formData().then(x=>parsed=x);fetch(request)')!
	stream_tasks_drain(mut vm)
	assert stream_eval(mut vm, 'parsed instanceof FormData&&parsed.getAll("a").join()==="one,two"&&parsed.get("file") instanceof File&&parsed.get("file").name==="bytes.bin"&&parsed.get("file").size===3&&request.headers.get("content-type").startsWith("multipart/form-data; boundary=")&&copy.bodyUsed')!.as_bool()
	stream_eval(mut vm, 'var bytes;parsed.get("file").bytes().then(x=>bytes=x)')!
	stream_tasks_drain(mut vm)
	assert stream_eval(mut vm, 'bytes.join()==="0,255,65"')!.as_bool()
	assert seen.methods == ['POST'] && seen.bodies.len == 1 && seen.bodies[0].contains('filename="bytes.bin"')
	assert seen.errors.len == 0
}

fn test_fetch_form_data_snapshot_happens_after_dictionary_and_prototype_getters() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	stream_eval(mut vm, 'var f=new FormData;f.append("a","before");var log="",target=new Proxy(function(){},{get(t,k){if(k==="prototype"){log+="p";f.set("a","after");return Response.prototype}return Reflect.get(t,k)}}),r=Reflect.construct(Response,[f,{get headers(){log+="h";f.append("b","during");return {}}}],target),data;r.formData().then(x=>data=x);f.delete("b");f.set("a","later")')!
	stream_tasks_drain(mut vm)
	assert stream_eval(mut vm, 'log==="hp"&&data.get("a")==="after"&&data.get("b")==="during"&&[...data].length===2')!.as_bool()
	assert seen.errors.len == 0
}

fn test_fetch_form_data_urlencoded_uses_byte_parser_without_urlsearchparams_prefix_stripping() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	stream_eval(mut vm, 'var data,r=new Response("?a=first&a=1&a=2+b&bad=%FF",{headers:{"Content-Type":"application/x-www-form-urlencoded;charset=UTF-8"}});r.formData().then(x=>data=x)')!
	stream_tasks_drain(mut vm)
	assert stream_eval(mut vm, 'data.get("?a")==="first"&&data.getAll("a").join()==="1,2 b"&&data.get("bad")==="�"&&r.bodyUsed&&Response.prototype.formData.length===0')!.as_bool()
	assert seen.errors.len == 0
}

fn test_fetch_form_data_rejects_invalid_mime_malformed_multipart_and_reused_body() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	stream_eval(mut vm, 'var bad=0;for(var r of [new Response("a=1"),new Response("a=1",{headers:{"Content-Type":"text/plain"}}),new Response("bad",{headers:{"Content-Type":"multipart/form-data"}}),new Response("bad",{headers:{"Content-Type":"multipart/form-data; boundary=foo"}})])r.formData().catch(e=>{if(e instanceof TypeError)bad++});var r=new Response("a=1",{headers:{"Content-Type":"application/x-www-form-urlencoded"}}),data;r.formData().then(x=>data=x);r.formData().catch(e=>{if(e instanceof TypeError)bad++});Response.prototype.formData.call({}).catch(e=>{if(e instanceof TypeError)bad++})')!
	stream_tasks_drain(mut vm)
	assert stream_eval(mut vm, 'bad===6&&data.get("a")==="1"&&r.bodyUsed')!.as_bool()
	assert seen.errors.len == 0
}

fn test_fetch_form_data_body_respects_explicit_headers_and_intrinsic_result_wrappers() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	stream_eval(mut vm, 'var f=new FormData;f.append("a",1);var r=new Response(f,{headers:{"Content-Type":"custom/type"}}),data,text="",F=FormData,B=File;globalThis.FormData=function(){throw 1};globalThis.File=function(){throw 2};new Response("a=1",{headers:{"Content-Type":"application/x-www-form-urlencoded"}}).formData().then(x=>data=x);r.text().then(x=>text=x);globalThis.FormData=F;globalThis.File=B')!
	stream_tasks_drain(mut vm)
	assert stream_eval(mut vm, 'r.headers.get("content-type")==="custom/type"&&text.includes("name=\"a\"")&&data instanceof FormData&&data.get("a")==="1"')!.as_bool()
	assert seen.errors.len == 0
}

fn test_cached_fetch_form_data_round_trip_revisits_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-fetch-form-data-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, mut document, seen := native_fetch_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		stream_eval(mut vm, 'function roundtrip(f){return new Response(f).formData()}function accept(f){value=f.get("a")}var value,f=new FormData;f.append("a","compiled 😀");roundtrip(f).then(accept)')!
		stream_tasks_drain(mut vm)
		assert stream_eval(mut vm, 'value==="compiled 😀"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		assert seen.errors.len == 0
		vm.close_native_code()!
		host.close(); document.finalize()
	}
}
