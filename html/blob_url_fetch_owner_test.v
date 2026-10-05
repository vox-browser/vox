module html

import dom
import fetch
import fileapi
import http
import libjs
import page
import url as liburl

fn source_blob_fetch_unused_host(_ &fetch.Request) !&fetch.Response {
	return error('Blob URL fetch must not enter the network host')
}

fn source_blob_fetch_document(address string, origin dom.Origin) !(&dom.Document, &EnvironmentSettingsObject) {
	owner := page.Page.create(1)!
	mut document := create_navigation_document_for_page(dom.URL{ value: address }, origin, none,
		unsafe { &dom.Page(owner) })!
	return document, unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
}

fn source_blob_fetch_response(request &fetch.Request) &fetch.Response {
	host := fetch.FetchHost{
		perform: source_blob_fetch_unused_host
	}
	return fetch.scheme_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()),
		host).response() or { panic('missing Blob response') }
}

fn test_source_blob_scheme_fetch_reads_the_actual_request_url_snapshot() {
	address := dom.URL{
		value: 'https://blob-fetch-snapshot-owner.test/page'
	}
	mut document, settings := source_blob_fetch_document(address.serialize(), address.origin())!
	defer {
		document.finalize()
		document.run_unloading_cleanup_steps()
	}
	mut blob := fileapi.Blob.create('request snapshot'.bytes(), 'text/plain')
	value := fileapi.add_entry_to_blob_url_store(fileapi.BlobURLObject.from_blob(blob), settings)!
	mut request := fetch.Request.create()
	request.set_url(settings.parse_url(value)?)
	request.destination = .document
	mut clone := request.clone()
	blob.deserialization_steps_utf16(libjs.utf16_string('text/later'),
		'changed live object'.bytes())
	mut later := fetch.Request.create()
	later.set_url(settings.parse_url(value)?)
	later.destination = .document
	fileapi.remove_entry_from_blob_url_store(liburl.parse(value)?)
	response := source_blob_fetch_response(request)
	assert !response.is_network_error()
	assert response.status == 200
	assert response.body?.bytes() == 'request snapshot'.bytes()
	assert response.header_list.get('Content-Length')? == '16'
	assert response.header_list.get('Content-Type')? == 'text/plain'
	assert source_blob_fetch_response(later).body?.bytes() == 'changed live object'.bytes()
	clone.header_list.append(http.Header{ name: 'Range', value: 'bytes=2-5' })
	ranged := source_blob_fetch_response(clone)
	assert ranged.status == 206 && ranged.range_requested
	assert ranged.body?.bytes() == 'ques'.bytes()
	assert ranged.header_list.get('Content-Range')? == 'bytes 2-5/16'
	assert ranged.header_list.get('Content-Type')? == 'text/plain'
	clone.method = 'POST'
	assert source_blob_fetch_response(clone).is_network_error()
	mut reparsed := fetch.Request.create()
	reparsed.set_url(settings.parse_url(value)?)
	reparsed.destination = .document
	assert source_blob_fetch_response(reparsed).is_network_error()
	mut raw := fetch.Request.create()
	raw.set_url(dom.URL{ value: value })
	raw.destination = .document
	assert source_blob_fetch_response(raw).is_network_error()
}

fn test_source_blob_fetch_opaque_partition_reads_actual_current_settings() {
	opaque := dom.origin_create_opaque()
	mut creator, settings := source_blob_fetch_document('https://blob-fetch-opaque.test/creator',
		opaque)!
	mut same, same_settings := source_blob_fetch_document('https://different-creation.test/page',
		opaque)!
	mut other, other_settings := source_blob_fetch_document('https://blob-fetch-opaque.test/creator',
		dom.origin_create_opaque())!
	defer {
		creator.finalize()
		same.finalize()
		other.finalize()
		creator.run_unloading_cleanup_steps()
	}
	value := fileapi.add_entry_to_blob_url_store(fileapi.BlobURLObject.from_blob(fileapi.Blob.create([
		u8(0),
		255,
	], '')), settings)!
	mut request := fetch.Request.create()
	request.set_url(settings.parse_url(value)?)
	request.set_client(same_settings)
	assert !source_blob_fetch_response(request).is_network_error()
	request.set_client(other_settings)
	assert source_blob_fetch_response(request).is_network_error()
	// Both serialize to null. The retained client owner, rather than the
	// Request's set_client-time projection, supplies the current typed origin.
	other.set_origin(opaque)
	assert !source_blob_fetch_response(request).is_network_error()
	other.set_origin(dom.origin_create_opaque())
	assert source_blob_fetch_response(request).is_network_error()
	request.destination = .document
	assert !source_blob_fetch_response(request).is_network_error()
	request.destination = none
	request.client = none
	assert source_blob_fetch_response(request).is_network_error()
}

fn test_source_blob_fetch_reserved_environment_priority_and_live_settings_selection() {
	address := dom.URL{
		value: 'https://blob-fetch-reserved.test/creator'
	}
	foreign := dom.URL{
		value: 'https://foreign-blob-fetch.test/page'
	}
	mut creator, settings := source_blob_fetch_document(address.serialize(), address.origin())!
	mut other, other_settings := source_blob_fetch_document(foreign.serialize(), foreign.origin())!
	defer {
		creator.finalize()
		other.finalize()
		creator.run_unloading_cleanup_steps()
	}
	value := fileapi.add_entry_to_blob_url_store(fileapi.BlobURLObject.from_blob(fileapi.Blob.create([
		u8(1),
	], '')), settings)!
	mut request := fetch.Request.create()
	request.set_url(settings.parse_url(value)?)
	request.set_client(other_settings)
	mut environment := &Environment{
		creation_url: address
	}
	request.set_reserved_client(environment)
	assert !source_blob_fetch_response(request).is_network_error()
	environment.creation_url = foreign
	assert source_blob_fetch_response(request).is_network_error()
	request.set_client(settings)
	// Reserved client still wins over an otherwise matching actual client.
	assert source_blob_fetch_response(request).is_network_error()
	mut settings_environment := settings.environment()
	settings_environment.creation_url = foreign
	request.set_reserved_client(settings_environment)
	assert !source_blob_fetch_response(request).is_network_error()
	creator.set_origin(foreign.origin())
	assert source_blob_fetch_response(request).is_network_error()
}

fn test_source_blob_fetch_self_fetch_uses_chosen_creation_url_and_actual_logical_navigable() {
	address := dom.URL{
		value: 'https://blob-fetch-self.test/creator'
	}
	foreign := dom.URL{
		value: 'https://foreign-self-fetch.test/page'
	}
	mut creator, settings := source_blob_fetch_document(address.serialize(), address.origin())!
	mut other, other_settings := source_blob_fetch_document(foreign.serialize(), foreign.origin())!
	mut reservation, reserved_settings := source_blob_fetch_document('https://foreign-self-fetch.test/reserved', foreign.origin())!
	defer {
		reservation.finalize()
		creator.finalize()
		other.finalize()
		creator.run_unloading_cleanup_steps()
	}
	value := fileapi.add_entry_to_blob_url_store(fileapi.BlobURLObject.from_blob(fileapi.Blob.create([
		u8(7),
	], '')), settings)!
	url := settings.parse_url(value)?
	mut request := fetch.Request.create()
	request.set_url(url)
	request.set_client(other_settings)
	mut reserved := reserved_settings.environment()
	reserved.creation_url = url
	request.set_reserved_client(reserved)
	assert other_settings.fetch_request_client_creation_url() != url
	assert request.client_creation_url? != url
	// The actual client Window is top-level; chosen reserved creation URL
	// supplies the match even though the client's cached creation URL differs.
	assert !source_blob_fetch_response(request).is_network_error()
	reserved.creation_url = foreign
	assert source_blob_fetch_response(request).is_network_error()
	reserved.creation_url = url
	mut reserved_native := reservation.navigable()?
	reserved_native.parent_ = creator.navigable()?
	assert !source_blob_fetch_response(request).is_network_error()
	mut native := other.navigable()?
	native.parent_ = creator.navigable()?
	assert !other_settings.fetch_request_client_is_top_level_window()
	assert source_blob_fetch_response(request).is_network_error()
	native.parent_ = none
	assert !source_blob_fetch_response(request).is_network_error()
	other.set_navigable(none)
	assert source_blob_fetch_response(request).is_network_error()
}

fn test_source_blob_fetch_restores_source_wtf8_type_before_response_headers() {
	address := dom.URL{
		value: 'https://blob-fetch-type.test/page'
	}
	mut document, settings := source_blob_fetch_document(address.serialize(), address.origin())!
	defer {
		document.finalize()
		document.run_unloading_cleanup_steps()
	}
	type_ := libjs.utf16_string_from_code_units([u16(0x41), 0xd800, 0x42])
	value := fileapi.add_entry_to_blob_url_store(fileapi.BlobURLObject.from_blob(fileapi.Blob.create_utf16([
		u8(8),
	], type_)), settings)!
	mut request := fetch.Request.create()
	request.set_url(settings.parse_url(value)?)
	request.destination = .document
	response := source_blob_fetch_response(request)
	assert !response.is_network_error()
	assert response.header_list.get('Content-Type')?.bytes() == [u8(0x41), 0xed, 0xa0, 0x80, 0x42]
}
