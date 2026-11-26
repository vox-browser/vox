// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import os
import rand

fn test_fetch_blob_bodies_preserve_bytes_content_type_and_request_copy() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var b=new Blob(["Aé😀"],{type:"TEXT/PLAIN"}),r=new Request("/post",{method:"POST",body:b}),copy=r.clone(),text="";copy.text().then(s=>text=s);fetch(r)')!
	native_fetch_drain(mut vm)
	assert seen.methods == ['POST'] && seen.bodies == ['Aé😀']
	assert native_fetch_eval(mut vm, 'text==="Aé😀"&&r.headers.get("content-type")==="text/plain"&&copy.bodyUsed&&b.size===7')!.as_bool()
	assert seen.errors.len == 0
}

fn test_fetch_dataview_body_snapshots_follow_dictionary_and_new_target_getters() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var a=new Uint8Array([88,65,66,89]),log="",text="",N=new Proxy(function(){},{get(t,k,r){if(k==="prototype"){log+="p";a[1]=68;return Request.prototype}return Reflect.get(t,k,r)}}),r=Reflect.construct(Request,["/post",{get body(){log+="b";return new DataView(a.buffer,1,2)},get headers(){log+="h";a[1]=67;return {}},method:"POST"}],N);r.text().then(s=>text=s);a.fill(0)')!
	native_fetch_drain(mut vm)
	assert native_fetch_eval(mut vm, 'log==="bhp"&&text==="DB"&&!r.headers.has("content-type")')!.as_bool()
	assert seen.errors.len == 0
}

fn test_response_buffer_source_snapshot_follows_options_and_prototype_conversion() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var a=new Uint8Array([65,66]),log="",text="",N=new Proxy(function(){},{get(t,k,r){if(k==="prototype"){log+="p";a[0]=68;return Response.prototype}return Reflect.get(t,k,r)}}),r=Reflect.construct(Response,[a,{get headers(){log+="h";a[0]=67;return {}},get status(){log+="s";return 201},get statusText(){log+="t";return "Created"}}],N);r.text().then(s=>text=s);a.fill(0)')!
	native_fetch_drain(mut vm)
	assert native_fetch_eval(mut vm, 'log==="hstp"&&text==="DB"&&r.status===201')!.as_bool()
	assert seen.errors.len == 0
}

fn test_fetch_urlsearchparams_bodies_use_native_serialization_after_later_getters() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var p=new URLSearchParams([["a","1"],["a","2 b"]]),text="";p.toString=function(){throw 1};var r=new Request("/post",{body:p,get headers(){p.append("x","é");return {}},method:"POST"});r.clone().text().then(s=>text=s);fetch(r)')!
	native_fetch_drain(mut vm)
	assert seen.bodies == ['a=1&a=2+b&x=%C3%A9']
	assert native_fetch_eval(mut vm, 'text==="a=1&a=2+b&x=%C3%A9"&&r.headers.get("content-type")==="application/x-www-form-urlencoded;charset=UTF-8"')!.as_bool()
	assert seen.errors.len == 0
}

fn test_fetch_binary_body_webidl_restrictions_detachment_and_abrupt_conversion() {
	mut host, mut vm, mut document, _ := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	assert native_fetch_eval(mut vm, 'var reads=0,errors=0;for(var body of [new SharedArrayBuffer(2),new Uint8Array(new SharedArrayBuffer(2)),new DataView(new ArrayBuffer(2,{maxByteLength:4}))])try{new Request("/post",{body,get headers(){reads++;return {}},method:"POST"})}catch(e){if(e instanceof TypeError)errors++}errors===3&&reads===0')!.as_bool()
	native_fetch_eval(mut vm, 'var a=new Uint8Array([65]),text="not empty";new Response(a,{get headers(){a.buffer.transfer();return {}}}).text().then(s=>text=s)')!
	native_fetch_drain(mut vm)
	assert native_fetch_eval(mut vm, 'text===""')!.as_bool()
	assert native_fetch_eval(mut vm, 'var marker={},same=false,reads=0;try{new Response({toString(){throw marker}},{get headers(){reads++;return {}}})}catch(e){same=e===marker}same&&reads===0')!.as_bool()
}

fn test_fetch_bytes_returns_intrinsic_uint8_arrays_and_obeys_body_used() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var response=new Response(new Uint8Array([0,255,1])),a,second=false;response.bytes().then(x=>a=x);response.bytes().catch(e=>second=e instanceof TypeError);var r=new Request("/post",{method:"POST",body:new Uint8Array([3,4])}),b;r.bytes().then(x=>b=x)')!
	native_fetch_drain(mut vm)
	assert native_fetch_eval(mut vm, 'a instanceof Uint8Array&&a.join()==="0,255,1"&&b instanceof Uint8Array&&b.join()==="3,4"&&response.bodyUsed&&r.bodyUsed&&second&&Response.prototype.bytes.length===0')!.as_bool()
	assert seen.errors.len == 0
}

fn test_fetch_blob_returns_native_blob_with_mime_type_and_async_text_read() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var b,text="",r=new Response(new Uint8Array([65,195,169]),{headers:{"Content-Type":"TEXT/PLAIN"}});r.blob().then(x=>{b=x;return x.text()}).then(s=>text=s)')!
	native_fetch_drain(mut vm)
	assert native_fetch_eval(mut vm, 'b instanceof Blob&&b.size===3&&b.type==="text/plain"&&text==="Aé"&&r.bodyUsed&&Response.prototype.blob.length===0')!.as_bool()
	assert seen.errors.len == 0 && host.blob_reads.len == 0
}

fn test_fetch_binary_outputs_ignore_replaced_public_constructors() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var B=Blob,U=Uint8Array,b,a;globalThis.Blob=function(){throw 1};globalThis.Uint8Array=function(){throw 2};new Response("blob").blob().then(x=>b=x);new Response("bytes").bytes().then(x=>a=x);globalThis.Blob=B;globalThis.Uint8Array=U')!
	native_fetch_drain(mut vm)
	assert native_fetch_eval(mut vm, 'b instanceof B&&b.size===4&&a instanceof U&&a.join()==="98,121,116,101,115"')!.as_bool()
	assert seen.errors.len == 0
}

fn test_cached_fetch_binary_and_blob_reads_revisit_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-fetch-binary-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, mut document, seen := native_fetch_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		native_fetch_eval(mut vm, 'function responseBlob(s){return new Response(new Blob([s])).blob()}var result="";responseBlob("GitHub 😀").then(b=>b.text()).then(s=>result=s)')!
		native_fetch_drain(mut vm)
		assert native_fetch_eval(mut vm, 'result==="GitHub 😀"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		assert seen.errors.len == 0
		vm.close_native_code()!
		host.close(); document.finalize()
	}
}
