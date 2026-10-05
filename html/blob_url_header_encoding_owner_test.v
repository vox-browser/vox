module html

import dom
import fetch
import fileapi
import http
import url as liburl
import libjs
import page

fn source_blob_header_unused_host(_ &fetch.Request) !&fetch.Response {
	return error('Blob URL header check must not enter the network')
}

fn test_source_blob_response_content_type_is_isomorphic_bytes_from_retained_utf16_type() {
	owner := page.Page.create(1)!
	address := dom.URL{value: 'https://blob-header-actual-owner.test/page'}
	mut document := create_navigation_document_for_page(address, address.origin(), none, unsafe { &dom.Page(owner) })!
	defer { document.run_unloading_cleanup_steps(); document.finalize() }
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	type_ := libjs.utf16_string_from_code_units([u16(0x41), 0xe9, 0xff])
	value := fileapi.add_entry_to_blob_url_store(fileapi.BlobURLObject.from_blob(fileapi.Blob.create_utf16([u8(0), 1, 2, 3], type_)), settings)!
	mut request := fetch.Request.create()
	request.set_url(settings.parse_url(value)?)
	request.destination = .document
	host := fetch.FetchHost{perform: source_blob_header_unused_host}
	response := fetch.scheme_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), host).response()?
	assert !response.is_network_error()
	assert response.header_list.get('Content-Type')?.bytes() == [u8(0x41), 0xe9, 0xff]
}

fn test_source_blob_range_content_type_uses_the_same_retained_isomorphic_header() {
	owner := page.Page.create(1)!
	address := dom.URL{value: 'https://blob-range-header-owner.test/page'}
	mut document := create_navigation_document_for_page(address, address.origin(), none, unsafe { &dom.Page(owner) })!
	defer { document.run_unloading_cleanup_steps(); document.finalize() }
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut blob := fileapi.Blob.create_utf16([u8(0), 1, 2, 3], libjs.utf16_string_from_code_units([u16(0xe9), 0xd83d, 0xde80, 0xd800, 0x42]))
	value := fileapi.add_entry_to_blob_url_store(fileapi.BlobURLObject.from_blob(blob), settings)!
	mut request := fetch.Request.create()
	request.set_url(settings.parse_url(value)?)
	request.destination = .document
	request.header_list.append(http.Header{name: 'Range', value: 'bytes=1-2'})
	// Mutating and revoking the live object must leave the request's earlier
	// bytes/type intact, including Source's surrogate-pair byte truncation.
	blob.deserialization_steps_utf16(libjs.utf16_string('text/later'), [u8(9)])
	fileapi.remove_entry_from_blob_url_store(liburl.parse(value)?)
	host := fetch.FetchHost{perform: source_blob_header_unused_host}
	response := fetch.scheme_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), host).response()?
	assert response.status == 206
	assert response.body?.bytes() == [u8(1), 2]
	assert response.header_list.get('Content-Type')?.bytes() == [u8(0xe9), 0x80, 0, 0x42]
	assert response.header_list.get('Content-Range')? == 'bytes 1-2/4'
}
