module main

import browserjs
import dom
import fetch
import fileapi
import html
import url as liburl

fn native_page_object_url_network_is_unused(_ &fetch.Request) !&fetch.Response {
	return error('page object-URL request must not enter the network')
}

fn test_native_page_blob_and_file_urls_reach_actual_store_fetch_and_revoke_owners() {
	$if !darwin { return }
	document := parse_browser_navigation_document('<div id="result">pending</div>', dom.URL{
		value: 'https://native-object-page.example.test/page.html'
	}, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		html.run_blob_url_unloading_cleanup_steps(document)
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://native-object-page.example.test/page.html', [
		'globalThis.actualBlob=new Blob([new Uint8Array([65,0,255])],{type:"text/plain"});globalThis.blobAddress=URL.createObjectURL(actualBlob);const view=new URL(blobAddress);result.textContent=view.protocol+" "+view.origin+" "+actualBlob.size;',
		'addEventListener("load",()=>{globalThis.actualFile=new File(["File"],"file.txt",{type:"text/plain"});globalThis.fileAddress=URL.createObjectURL(actualFile);result.textContent+=" ready "+actualFile.name;});',
	], runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'blob: https://native-object-page.example.test 3 ready file.txt'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	value := runtime.native_utf16_string(runtime.evaluate_host_value('blobAddress')!)!.str()
	file_value := runtime.native_utf16_string(runtime.evaluate_host_value('fileAddress')!)!.str()
	record := liburl.parse(value)?
	file_record := liburl.parse(file_value)?
	entry := fileapi.resolve_a_blob_url(record)?
	assert entry.environment.blob_url_settings_identity() == voidptr(settings)
	assert voidptr(entry.object.blob?) == voidptr(runtime.native_blob(runtime.evaluate_host_value('actualBlob')!)!)
	file := runtime.native_file(runtime.evaluate_host_value('actualFile')!)!
	assert voidptr(fileapi.resolve_a_blob_url(file_record)?.object.blob?) == voidptr(&file.Blob)
	mut request := fetch.Request.create()
	request.set_url(settings.parse_url(value)?)
	request.set_client(settings)
	assert runtime.evaluate_host('URL.revokeObjectURL(blobAddress);URL.revokeObjectURL(fileAddress);true')! == 'true'
	assert fileapi.resolve_a_blob_url(record) == none
	assert fileapi.resolve_a_blob_url(file_record) == none
	response := fetch.scheme_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: native_page_object_url_network_is_unused
	}).response()?
	assert !response.is_network_error() && response.status == 200
	assert response.body?.bytes() == [u8(65), 0, 255]
	assert response.header_list.get('Content-Type')? == 'text/plain'
	assert !runtime.libjs_vm().has_running_execution_context()
	assert settings.realm().script_execution_depth == 0
}
