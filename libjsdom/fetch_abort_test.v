// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import os
import rand

fn test_request_signal_is_same_object_dependent_native_signal_and_null_is_independent() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	assert native_fetch_eval(mut vm, 'var c=new AbortController(),r=new Request("/data",{signal:c.signal}),inherited=new Request(r),missing=new Request(r,{signal:undefined}),independent=new Request(r,{signal:null}),reason={};var initial=r.signal===r.signal&&r.signal instanceof AbortSignal&&r.signal!==c.signal&&!r.signal.aborted;c.abort(reason);initial&&r.signal.aborted&&r.signal.reason===reason&&inherited.signal.aborted&&missing.signal.aborted&&!independent.signal.aborted&&Object.getOwnPropertyDescriptor(Request.prototype,"signal").enumerable')!.as_bool()
	assert seen.errors.len == 0
}

fn test_fetch_already_aborted_signal_rejects_original_values_without_transport() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var marker={toString(){throw 1}},symbol=Symbol("abort"),large=123456789012345678901n,count=0;for(let reason of [marker,symbol,large,null,false,0,"stop"])fetch("/data",{signal:AbortSignal.abort(reason)}).catch(e=>{if(e===reason)count++})')!
	native_fetch_drain(mut vm)
	assert native_fetch_eval(mut vm, 'count===7')!.as_bool()
	assert seen.urls.len == 0 && seen.errors.len == 0 && host.fetch_operations.len == 0 && host.fetch_signal_operations.len == 0
}

fn test_fetch_abort_stops_pending_request_and_rejects_without_stringifying_reason() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var c=new AbortController(),reason={toString(){throw 1}},same=false;fetch("/data",{signal:c.signal}).catch(e=>same=e===reason);c.abort(reason)')!
	native_fetch_drain(mut vm)
	assert native_fetch_eval(mut vm, 'same')!.as_bool()
	assert seen.errors.len == 0 && host.fetch_operations.len == 0 && host.fetch_signal_operations.len == 0
	host.release_retired_fetch_aborts()
	assert host.retired_fetch_abort_closures.len == 0
}

fn test_fetch_abort_after_network_delivery_errors_unread_response_body_with_original_reason() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var c=new AbortController(),response,fulfilled=0;fetch("/data",{signal:c.signal}).then(r=>{response=r;fulfilled++})')!
	native_fetch_drain(mut vm)
	assert host.fetch_operations.len == 0 && host.fetch_signal_operations.len == 1
	assert native_fetch_eval(mut vm, 'fulfilled===1&&!response.bodyUsed')!.as_bool()
	native_fetch_eval(mut vm, 'var reason={},same=false;c.abort(reason);response.text().catch(e=>same=e===reason)')!
	native_fetch_drain(mut vm)
	assert native_fetch_eval(mut vm, 'same&&fulfilled===1')!.as_bool()
	assert host.fetch_signal_operations.len == 0 && seen.errors.len == 0
}

fn test_fetch_default_abort_reason_is_dom_exception_and_success_detaches_algorithms() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var c=new AbortController(),defaultReason=false;c.abort();fetch("/aborted",{signal:c.signal}).catch(e=>defaultReason=e instanceof DOMException&&e.name==="AbortError");var success=false;fetch("/data").then(r=>r.json()).then(x=>success=x.answer===42)')!
	native_fetch_drain(mut vm)
	assert native_fetch_eval(mut vm, 'defaultReason&&success')!.as_bool()
	assert host.fetch_operations.len == 0 && host.fetch_signal_operations.len == 0 && seen.errors.len == 0
}

fn test_fetch_signal_webidl_conversion_checks_brand_before_later_dictionary_getters() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { host.close(); document.finalize() }
	assert native_fetch_eval(mut vm, 'var reads=0,errors=0,c=new AbortController();for(var signal of [{},new Proxy(c.signal,{}),1])try{new Request("/data",{signal,get window(){reads++;return null}})}catch(e){if(e instanceof TypeError)errors++}errors===3&&reads===0')!.as_bool()
	native_fetch_eval(mut vm, 'var marker={},same=false;fetch("/data",{get signal(){throw marker}}).catch(e=>same=e===marker)')!
	native_fetch_drain(mut vm)
	assert native_fetch_eval(mut vm, 'same')!.as_bool()
	assert seen.urls.len == 0 && seen.errors.len == 0
}

fn test_fetch_close_removes_signal_hooks_for_pending_and_unread_body_operations() {
	mut host, mut vm, mut document, _ := native_fetch_fixture()!
	defer { document.finalize() }
	native_fetch_eval(mut vm, 'var response,c=new AbortController();fetch("/data",{signal:c.signal}).then(r=>response=r)')!
	native_fetch_drain(mut vm)
	mut operations := []&DocumentFetchOperation{}
	for _, operation in host.fetch_signal_operations { operations << operation }
	assert operations.len == 1
	host.close()
	for operation in operations {
		assert operation.finished && operation.abort_algorithm == none && operation.abort_callback == unsafe { nil }
		assert operation.request.signal().abort_algorithms.len == 0
	}
	assert host.fetch_operations.len == 0 && host.fetch_signal_operations.len == 0 && host.retired_fetch_abort_closures.len == 0
}

fn test_cached_fetch_signal_rejection_revisits_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-fetch-signal-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, mut document, seen := native_fetch_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		native_fetch_eval(mut vm, 'function canceled(reason){return fetch("/data",{signal:AbortSignal.abort(reason)})}var reason={},same=false;canceled(reason).catch(e=>same=e===reason)')!
		native_fetch_drain(mut vm)
		assert native_fetch_eval(mut vm, 'same')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		assert seen.urls.len == 0 && seen.errors.len == 0
		vm.close_native_code()!
		host.close(); document.finalize()
	}
}
