module browserjs

import dom
import domurl
import fetch
import fileapi
import html
import libjs
import page
import url as liburl

fn native_object_url_runtime(address string, origin dom.Origin) !(&Runtime, &dom.Document, &html.WindowModel, &URLHost) {
	mut runtime := Runtime.create()
	owner := page.Page.create(1)!
	document := html.create_navigation_document_for_page(dom.URL{ value: address }, origin, none,
		unsafe { &dom.Page(owner) })!
	window := unsafe {
		&html.WindowModel(document.get_window() or {
			return error('missing actual object-URL Window')
		})
	}
	mut readable := ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut blobs := BlobHost.create(document)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	mut queries := URLSearchParamsHost.create(document)!
	queries.install(mut runtime)!
	mut urls := URLHost.create(document)!
	urls.install(mut runtime)!
	mut files := FileHost.create(document)!
	files.install(mut runtime)!
	files.install_constructor()!
	return runtime, document, window, urls
}

fn native_object_url_network_is_unused(_ &fetch.Request) !&fetch.Response {
	return error('native object-URL caller must not use the network')
}

fn native_object_url_response(request &fetch.Request) &fetch.Response {
	return fetch.scheme_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: native_object_url_network_is_unused
	}).response() or { panic('missing native object-URL response') }
}

fn native_object_url_text(mut runtime Runtime, expression string) !string {
	return runtime.native_utf16_string(runtime.evaluate_host_value(expression)!)!.str()
}

fn test_native_url_object_methods_are_exposed_on_the_actual_constructor() {
	$if !darwin { return }
	address := dom.URL{
		value: 'https://native-object-url.example.test/page'
	}
	mut runtime, _, _, _ := native_object_url_runtime(address.serialize(), address.origin())!
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof URL.createObjectURL')! == 'function'
	assert runtime.evaluate_host('typeof URL.revokeObjectURL')! == 'function'
	assert runtime.evaluate_host(r'(()=>{const get=Object.getOwnPropertyDescriptor;return ["createObjectURL","revokeObjectURL"].every(name=>{const d=get(URL,name),f=d.value;return f.name===name&&f.length===1&&d.writable&&d.enumerable&&d.configurable&&Function.prototype.toString.call(f).includes("[native code]")&&webkitURL[name]===f})})()')! == 'true'
}

fn test_native_url_blob_and_file_store_actual_objects_and_retain_fetch_snapshots_after_revoke() {
	$if !darwin { return }
	address := dom.URL{
		value: 'https://native-object-url.example.test/page'
	}
	mut runtime, mut document, window, _ := native_object_url_runtime(address.serialize(),
		address.origin())!
	defer {
		document.run_unloading_cleanup_steps()
		runtime.close()
		document.finalize()
	}
	value := native_object_url_text(mut runtime,
		'globalThis.actualBlob=new Blob([new Uint8Array([0,255,65])],{type:"TEXT/PLAIN"});globalThis.blobAddress=URL.createObjectURL.call({},actualBlob);blobAddress')!
	assert value.starts_with('blob:https://native-object-url.example.test/')
	record := liburl.parse(value)?
	entry := fileapi.resolve_a_blob_url(record)?
	mut blob := runtime.native_blob(runtime.evaluate_host_value('actualBlob')!)!
	assert voidptr(entry.object.blob?) == voidptr(blob)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert entry.environment.blob_url_settings_identity() == voidptr(settings)
	retained := domurl.parse(value, none, none)?.blob_url_entry()?
	assert (retained.object as liburl.BlobURLBlob).data == [u8(0), 255, 65]
	mut request := fetch.Request.create()
	request.set_url(settings.parse_url(value)?)
	request.set_client(settings)
	blob.deserialization_steps_utf16(libjs.utf16_string('text/changed'), [u8(9)])
	fresh := domurl.parse(value, none, none)?.blob_url_entry()?
	assert (fresh.object as liburl.BlobURLBlob).data == [u8(9)]
	assert runtime.evaluate_host('URL.revokeObjectURL(blobAddress)===undefined')! == 'true'
	assert fileapi.resolve_a_blob_url(record) == none
	assert domurl.parse(value, none, none)?.blob_url_entry() == none
	response := native_object_url_response(request)
	assert !response.is_network_error() && response.status == 200
	assert response.body?.bytes() == [u8(0), 255, 65]
	assert response.header_list.get('Content-Type')? == 'text/plain'
	assert (retained.object as liburl.BlobURLBlob).data == [u8(0), 255, 65]
	file_value := native_object_url_text(mut runtime,
		'globalThis.actualFile=new File(["file bytes"],"data.txt",{type:"text/plain",lastModified:1});globalThis.fileAddress=URL.createObjectURL(actualFile);fileAddress')!
	file_record := liburl.parse(file_value)?
	file_entry := fileapi.resolve_a_blob_url(file_record)?
	file := runtime.native_file(runtime.evaluate_host_value('actualFile')!)!
	assert voidptr(file_entry.object.blob?) == voidptr(&file.Blob)
	assert file_entry.object.blob?.raw_bytes() == 'file bytes'.bytes()
	assert runtime.evaluate_host('URL.revokeObjectURL.call(null,fileAddress)===undefined')! == 'true'
	assert fileapi.resolve_a_blob_url(file_record) == none
	assert !runtime.libjs_vm().has_running_execution_context()
	assert settings.realm().script_execution_depth == 0
}

fn test_native_url_object_union_uses_real_brands_without_observing_author_properties() {
	$if !darwin { return }
	address := dom.URL{
		value: 'https://native-object-brand.example.test/page'
	}
	mut runtime, mut document, _, _ := native_object_url_runtime(address.serialize(),
		address.origin())!
	defer {
		document.run_unloading_cleanup_steps()
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'(()=>{let reads=0;const b=new Blob(["brand"]),fake=Object.create(Blob.prototype),tagged={[Symbol.toStringTag]:"Blob",get size(){reads++;throw 1},toString(){reads++;throw 2}},proxy=new Proxy(b,{get(){reads++;throw 3},getPrototypeOf(){reads++;throw 4}});const invalid=[undefined,null,1,"blob",Symbol(),{},fake,tagged,proxy];const rejected=invalid.every(value=>{try{URL.createObjectURL(value);return false}catch(reason){return reason instanceof TypeError&&reason.message==="No union types matched"}});Object.defineProperty(Blob,Symbol.hasInstance,{value(){reads++;throw 5}});Object.setPrototypeOf(b,null);const first=URL.createObjectURL(b),second=URL.createObjectURL(b);URL.revokeObjectURL(first);URL.revokeObjectURL(second);return rejected&&reads===0&&first!==second})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{return [()=>URL.createObjectURL(),()=>URL.revokeObjectURL()].every(call=>{try{call();return false}catch(reason){return reason instanceof TypeError}})})()')! == 'true'
}

fn test_native_url_revoke_converts_dom_string_and_preserves_original_exceptions() {
	$if !darwin { return }
	address := dom.URL{
		value: 'https://native-object-string.example.test/page'
	}
	mut runtime, _, _, host := native_object_url_runtime(address.serialize(), address.origin())!
	defer { runtime.close() }
	raw := runtime.evaluate_host_value('String.fromCharCode(0xd800,65,0xdc00)')!
	assert host.dom_string(raw)!.code_units() == [u16(0xd800), 65, 0xdc00]
	assert host.usv_string(raw)! == '\uFFFD' + 'A' + '\uFFFD'
	assert runtime.evaluate_host(r'(()=>{const marker={},hints=[];let caught;try{URL.revokeObjectURL({[Symbol.toPrimitive](hint){hints.push(hint);throw marker}})}catch(reason){caught=reason}let symbolic;try{URL.revokeObjectURL(Symbol())}catch(reason){symbolic=reason}return caught===marker&&hints.join()==="string"&&symbolic instanceof TypeError&&[undefined,null,1n,"https://[invalid","https://example.test/",String.fromCharCode(0xd800)].every(value=>URL.revokeObjectURL(value)===undefined)})()')! == 'true'
}

fn test_native_url_revoke_uses_actual_opaque_partitions_and_source_fragment_behavior() {
	$if !darwin { return }
	address := 'https://native-object-opaque.example.test/page'
	shared_origin := dom.origin_create_opaque()
	mut creator, mut document, _, _ := native_object_url_runtime(address, shared_origin)!
	mut other, mut other_document, _, _ := native_object_url_runtime(address,
		dom.origin_create_opaque())!
	mut same, mut same_document, _, _ := native_object_url_runtime(address, shared_origin)!
	defer {
		document.run_unloading_cleanup_steps()
		other_document.run_unloading_cleanup_steps()
		same_document.run_unloading_cleanup_steps()
		creator.close()
		other.close()
		same.close()
		document.finalize()
		other_document.finalize()
		same_document.finalize()
	}
	value := native_object_url_text(mut creator, 'URL.createObjectURL(new Blob(["opaque"]))')!
	assert value.starts_with('blob:null/')
	record := liburl.parse(value)?
	assert document.origin().serialize() == 'null' && other_document.origin().serialize() == 'null'
	assert other.evaluate_host('URL.revokeObjectURL("${value}")===undefined')! == 'true'
	assert fileapi.resolve_a_blob_url(record) != none
	assert creator.evaluate_host('URL.revokeObjectURL("${value}#fragment")===undefined')! == 'true'
	assert fileapi.resolve_a_blob_url(record) != none
	assert same.evaluate_host('URL.revokeObjectURL("${value}")===undefined')! == 'true'
	assert fileapi.resolve_a_blob_url(record) == none
	assert creator.evaluate_host('URL.revokeObjectURL("${value}")===undefined')! == 'true'
}

fn test_native_url_creation_reads_reassociated_settings_and_unload_uses_owner_identity() {
	$if !darwin { return }
	address := dom.URL{
		value: 'https://native-object-live.example.test/page'
	}
	replacement_address := dom.URL{
		value: 'https://native-object-replacement.example.test/page'
	}
	mut creator, mut document, mut window, _ := native_object_url_runtime(address.serialize(),
		address.origin())!
	mut other, mut other_document, _, _ := native_object_url_runtime(address.serialize(),
		address.origin())!
	mut replacement_runtime, mut replacement, _, _ := native_object_url_runtime(replacement_address.serialize(),
		replacement_address.origin())!
	defer {
		window.set_associated_document(document)
		document.run_unloading_cleanup_steps()
		other_document.run_unloading_cleanup_steps()
		replacement.run_unloading_cleanup_steps()
		creator.close()
		other.close()
		replacement_runtime.close()
		document.finalize()
		other_document.finalize()
		replacement.finalize()
	}
	value := native_object_url_text(mut creator, 'URL.createObjectURL(new Blob(["old"]))')!
	record := liburl.parse(value)?
	retained := domurl.parse(value, none, none)?.blob_url_entry()?
	other_value := native_object_url_text(mut other,
		'URL.createObjectURL(new Blob(["other owner"]))')!
	other_record := liburl.parse(other_value)?
	window.set_associated_document(replacement)
	new_value := native_object_url_text(mut creator, 'URL.createObjectURL(new Blob(["new"]))')!
	new_record := liburl.parse(new_value)?
	assert new_value.starts_with('blob:https://native-object-replacement.example.test/')
	entry := fileapi.resolve_a_blob_url(new_record)?
	assert entry.environment.blob_url_settings_identity() == document.relevant_settings_object()
	fresh := domurl.parse(value, none, none)?.blob_url_entry()?
	assert !fresh.environment.origin.is_same_origin(retained.environment.origin)
	assert fresh.environment.origin.is_same_origin(replacement.origin().liburl_origin()?)
	window.set_associated_document(document)
	document.run_unloading_cleanup_steps()
	assert fileapi.resolve_a_blob_url(record) == none
	assert fileapi.resolve_a_blob_url(new_record) == none
	assert fileapi.resolve_a_blob_url(other_record) != none
}
