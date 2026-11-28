// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import domurl
import fileapi
import html
import libjs
import platform
import url as liburl

fn test_object_urls_retain_actual_blob_bytes_type_and_creator_settings() {
	mut host, mut vm := text_encoding_fixture()!
	defer { html.run_blob_url_unloading_cleanup_steps(host.document); host.close() }
	assert blob_eval(mut vm, 'var b=new Blob(["GitHub 😀"],{type:"TEXT/PLAIN"}),u=URL.createObjectURL(b),v=URL.createObjectURL(b);u!==v&&u.startsWith("blob:https://libjs-encoding.test/")&&URL.createObjectURL.length===1&&URL.revokeObjectURL.length===1&&Object.getOwnPropertyDescriptor(URL,"createObjectURL").enumerable')!.as_bool()
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('u'))!.as_string().str()
	record := domurl.parse(value, none, none)?
	entry := fileapi.resolve_a_blob_url(record)?
	blob_value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('b'))!
	native := host.blobs[voidptr(blob_value.as_object())] or { panic('Missing Blob') }
	assert voidptr(entry.object.blob?) == voidptr(native)
	assert entry.environment.blob_url_settings_identity() == host.document.relevant_settings_object()
	snapshot := record.blob_url_entry()?.object
	assert (snapshot as liburl.BlobURLBlob).data == 'GitHub 😀'.bytes()
}

fn test_object_url_revoke_removes_only_matching_store_entry_and_preserves_old_snapshots() {
	mut host, mut vm := text_encoding_fixture()!
	defer { html.run_blob_url_unloading_cleanup_steps(host.document); host.close() }
	blob_eval(mut vm, 'var u=URL.createObjectURL(new Blob(["payload"])),v=URL.createObjectURL(new Blob(["other"]))')!
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('u'))!.as_string().str()
	record := domurl.parse(value, none, none)?
	assert record.blob_url_entry() != none
	assert blob_eval(mut vm, 'URL.revokeObjectURL(u)===undefined&&URL.revokeObjectURL(u)===undefined&&URL.revokeObjectURL("bad URL")===undefined&&URL.revokeObjectURL("https://example.com/")===undefined')!.as_bool()
	assert fileapi.resolve_a_blob_url(record) == none && domurl.parse(value, none, none)?.blob_url_entry() == none
	assert record.blob_url_entry() != none
	other := vm.global_object().get(mut vm, libjs.PropertyName.from_str('v'))!.as_string().str()
	assert fileapi.resolve_a_blob_url(domurl.parse(other, none, none)?) != none
}

fn test_object_url_conversions_require_real_blob_identity_and_preserve_errors() {
	mut host, mut vm := text_encoding_fixture()!
	defer { html.run_blob_url_unloading_cleanup_steps(host.document); host.close() }
	assert blob_eval(mut vm, 'var reads=0,count=0,b=new Blob();for(var f of [()=>URL.createObjectURL(),()=>URL.createObjectURL(null),()=>URL.createObjectURL({toString(){reads++;return "x"}}),()=>URL.createObjectURL(new Proxy(b,{})),()=>URL.revokeObjectURL(),()=>URL.revokeObjectURL(Symbol())])try{f()}catch(e){if(e instanceof TypeError)count++}count===6&&reads===0')!.as_bool()
	assert blob_eval(mut vm, 'var marker={},same=false;try{URL.revokeObjectURL({toString(){throw marker}})}catch(e){same=e===marker}same&&URL.revokeObjectURL(undefined)===undefined')!.as_bool()
}

fn test_object_url_lifetime_belongs_to_document_settings_after_host_close() {
	mut host, mut vm := text_encoding_fixture()!
	blob_eval(mut vm, 'var u=URL.createObjectURL(new Blob(["retained"]))')!
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('u'))!.as_string().str()
	record := domurl.parse(value, none, none)?
	host.close()
	assert fileapi.resolve_a_blob_url(record)?.object.blob?.raw_bytes() == 'retained'.bytes()
	html.run_blob_url_unloading_cleanup_steps(host.document)
	assert fileapi.resolve_a_blob_url(record) == none
}

fn test_object_urls_survive_temporary_arena_and_fixed_callback_count() {
	mut host, mut vm := text_encoding_fixture()!
	defer { html.run_blob_url_unloading_cleanup_steps(host.document); host.close() }
	before := host.closures.len
	mut arena := platform.new_arena('Blob URL native store entry')
	entry := arena.enter()
	blob_eval(mut vm, 'var b=new Blob(["owned"]),u=URL.createObjectURL(b);for(var i=0;i<10;i++)URL.revokeObjectURL(URL.createObjectURL(b))')!
	arena.leave(entry); arena.reset(); arena.release()
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('u'))!.as_string().str()
	record := domurl.parse(value, none, none)?
	assert fileapi.resolve_a_blob_url(record)?.object.blob?.raw_bytes() == 'owned'.bytes()
	assert host.closures.len == before
}

fn test_object_url_fetch_uses_original_origin_native_store_without_network_transport() {
	mut host, mut vm, mut document, seen := native_fetch_fixture()!
	defer { html.run_blob_url_unloading_cleanup_steps(document); host.close(); document.finalize() }
	native_fetch_eval(mut vm, 'var value="",type="",u=URL.createObjectURL(new Blob(["local body"],{type:"TEXT/PLAIN"}));fetch(u).then(r=>{type=r.headers.get("content-type");return r.text()}).then(s=>value=s)')!
	native_fetch_drain(mut vm)
	assert native_fetch_eval(mut vm, 'value==="local body"&&type==="text/plain"')!.as_bool()
	assert seen.urls.len == 0 && seen.errors.len == 0
}
