// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import fetch
import html
import http
import libjs
import os
import rand
import streams

@[heap]
struct FetchObservations {
mut:
	urls []string
	methods []string
	bodies []string
	errors []string
}

fn native_fetch_fixture() !(&Host, &libjs.VM, &dom.Document, &FetchObservations) {
	address := dom.URL{value: 'https://native-fetch.test/base/page'}
	mut document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	seen := &FetchObservations{}
	mut host := Host.create(vm, vm.realm(), document, Hooks{exception: fn [seen] (message string) {
		mut record := unsafe { &FetchObservations(seen) }; record.errors << message
	}})!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	host.install_fetch(fetch.RequestClient(settings), &fetch.FetchHost{perform: fn [seen] (request &fetch.Request) !&fetch.Response {
		mut record := unsafe { &FetchObservations(seen) }
		record.urls << request.current_url().serialize()
		record.methods << request.method
		record.bodies << if body := request.body.body_object { body.bytes().bytestr() } else { request.body.bytes.bytestr() }
		if request.current_url().serialize().contains('/fail') { return error('offline network failure') }
		mut response := fetch.Response.create()
		response.url_list = request.url_list.clone()
		response.header_list.append(http.Header{name: 'Content-Type', value: 'application/json'})
		response.set_body_bytes('{"answer":42}'.bytes())
		return response
	}})!
	return host, vm, document, seen
}

fn native_fetch_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-fetch.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn native_fetch_drain(mut vm libjs.VM) {
	mut queue := html.main_thread_event_loop().task_queue()
	for _ in 0 .. 256 {
		task := queue.take_first_runnable() or { vm.run_queued_promise_jobs(); return }
		task.execute()
	}
	assert false, 'Native Fetch tasks did not settle'
}

fn test_native_fetch_uses_owning_client_transport_headers_and_json_promises() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var answer=0,status=0,identity=false;fetch("./data").then(function(r){status=r.status;identity=r instanceof Response&&r.headers===r.headers&&r.headers instanceof Headers;return r.json()}).then(function(value){answer=value.answer})')!
	native_fetch_drain(mut vm)
	assert seen.urls == ['https://native-fetch.test/base/data'] && seen.methods == ['GET']
	assert native_fetch_eval(mut vm, 'answer===42&&status===200&&identity')!.as_bool()
	assert seen.errors.len == 0 && vm.take_promise_job_errors().len == 0 && host.fetch_operations.len == 0
}

fn test_native_request_and_response_constructors_clone_and_consume_actual_bodies() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	assert native_fetch_eval(mut vm, 'var r=new Request("./post",{method:"post",headers:{"X-Test":"42"},body:"hello"});r.method==="POST"&&r.url==="https://native-fetch.test/base/post"&&r.headers.get("x-test")==="42"&&r.headers===r.headers&&!r.bodyUsed')!.as_bool()
	native_fetch_eval(mut vm, 'var text="",copy=r.clone();copy.text().then(function(v){text=v});fetch(r)')!
	native_fetch_drain(mut vm)
	assert seen.methods == ['POST'] && seen.bodies == ['hello']
	assert native_fetch_eval(mut vm, 'text==="hello"&&copy.bodyUsed')!.as_bool()
	native_fetch_eval(mut vm, 'var decoded="",s=new Response("hello\\ud800",{status:201,headers:{"x-answer":"42"}}),t=s.clone();s.text().then(function(v){decoded=v});var consumed=false;s.text().catch(function(e){consumed=e instanceof TypeError})')!
	assert native_fetch_eval(mut vm, 's.status===201&&s.ok&&s.headers.get("x-answer")==="42"&&decoded==="hello\\ufffd"&&s.bodyUsed&&!t.bodyUsed&&consumed')!.as_bool()
	assert seen.errors.len == 0
}

fn test_native_fetch_conversion_and_network_failures_reject_with_original_values() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var token={},original=false,network=false,missing=false,bad={toString:function(){throw token}};fetch(bad).catch(function(e){original=e===token});fetch().catch(function(e){missing=e instanceof TypeError});fetch("/fail").catch(function(e){network=e instanceof TypeError})')!
	native_fetch_drain(mut vm)
	assert native_fetch_eval(mut vm, 'original&&network&&missing')!.as_bool()
	assert seen.errors.len == 0
}

fn test_native_response_json_captures_intrinsic_parser_and_reports_syntax_failures() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var saved=JSON.parse,answer=0,syntax=false;JSON.parse=function(){throw 7};new Response("{\\"answer\\":42}").json().then(function(v){answer=v.answer});new Response("bad").json().catch(function(e){syntax=e instanceof SyntaxError});JSON.parse=saved')!
	assert native_fetch_eval(mut vm, 'answer===42&&syntax')!.as_bool()
	assert seen.errors.len == 0
}

fn test_native_response_reads_pending_stream_until_close_and_stops_callbacks_after_host_close() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	mut body := fetch.Body.streaming()
	mut native := fetch.Response.create()
	native.body = body
	mut global := vm.global_object()
	global.define_direct_property(libjs.PropertyName.from_str('response'), host.wrap_response(fetch.ResponseObject.from_response(native, .immutable), none), libjs.attribute_configurable)
	native_fetch_eval(mut vm, 'var text="";response.text().then(function(v){text=v})')!
	mut stream := body.stream()
	stream.enqueue(streams.bytes_value('hello'.bytes()))!
	assert native_fetch_eval(mut vm, 'text===""&&response.bodyUsed')!.as_bool()
	stream.close()
	assert native_fetch_eval(mut vm, 'text==="hello"')!.as_bool()
	assert seen.errors.len == 0
	mut pending := fetch.Body.streaming()
	mut second := fetch.Response.create()
	second.body = pending
	global.define_direct_property(libjs.PropertyName.from_str('second'), host.wrap_response(fetch.ResponseObject.from_response(second, .immutable), none), libjs.attribute_configurable)
	native_fetch_eval(mut vm, 'second.text().then(function(){text="late"})')!
	host.close()
	mut pending_stream := pending.stream()
	pending_stream.close()
	assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('text'))!.as_string().str() == 'hello'
}

fn test_native_fetch_buffer_bodies_copy_input_and_arraybuffer_results_use_native_storage() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var b=new ArrayBuffer(2),view=new DataView(b);view.setUint8(0,65);view.setUint8(1,66);var r=new Request("./buffer",{method:"POST",body:b}),text="",byte=0;view.setUint8(0,67);r.text().then(function(v){text=v});new Response("AB").arrayBuffer().then(function(v){byte=new DataView(v).getUint8(1)})')!
	assert native_fetch_eval(mut vm, 'text==="AB"&&byte===66&&r.bodyUsed')!.as_bool()
	assert seen.errors.len == 0
}

fn test_native_fetch_dictionary_order_status_validation_and_body_receiver_errors() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	assert native_fetch_eval(mut vm, 'var order="",caught=false;try{new Request("./x",{get body(){order+="b";return null},get cache(){order+="c";return "invalid"},get credentials(){order+="bad";return "include"}})}catch(e){caught=e instanceof TypeError};caught&&order==="bc"')!.as_bool()
	assert native_fetch_eval(mut vm, 'var range=false,body=false;try{new Response("x",{status:199})}catch(e){range=e instanceof RangeError};try{new Response("x",{status:204})}catch(e){body=e instanceof TypeError};range&&body&&new Response(null,{status:204}).ok')!.as_bool()
	native_fetch_eval(mut vm, 'var rejected=false;Response.prototype.text.call({}).catch(function(e){rejected=e instanceof TypeError})')!
	assert native_fetch_eval(mut vm, 'rejected')!.as_bool()
	assert seen.errors.len == 0
}

fn test_native_fetch_callbacks_reuse_compiled_entries_in_a_fresh_vm_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-native-fetch-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, mut document, seen := native_fetch_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		native_fetch_eval(mut vm, 'var answer=0;fetch("./data").then(function(r){return r.json()}).then(function(v){answer=v.answer})')!
		native_fetch_drain(mut vm)
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('answer'))!.number == 42
		assert seen.errors.len == 0 && vm.take_promise_job_errors().len == 0
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 3 && stats.compiler_invocations == 0 && activity.entries >= 3 }
		vm.close_native_code()!
		host.close()
		document.finalize()
	}
}
