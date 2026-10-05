module html

import dom
import fileapi
import libjs
import page
import url as liburl

fn test_source_settings_url_parser_installs_a_blob_entry_on_the_actual_dom_record() {
	owner := page.Page.create(1)!
	address := dom.URL{value: 'https://blob-dom-record-owner.test/page'}
	mut document := create_navigation_document_for_page(address, address.origin(), none, unsafe { &dom.Page(owner) })!
	defer { document.finalize() }
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	value := fileapi.add_entry_to_blob_url_store(fileapi.BlobURLObject.from_blob(fileapi.Blob.create([u8(1), 2], 'text/plain')), settings)!
	defer { document.run_unloading_cleanup_steps() }
	parsed := settings.parse_url(value)?
	assert parsed.parsed()?.blob_url_entry() != none
	assert (parsed.parsed()?.blob_url_entry()?.object as liburl.BlobURLBlob).data == [u8(1), 2]
}

fn test_source_dom_blob_urls_keep_independent_snapshots_through_reparse_and_revoke() {
	owner := page.Page.create(1)!
	address := dom.URL{value: 'https://blob-dom-record-snapshots.test/page'}
	opaque := dom.origin_create_opaque()
	mut document := create_navigation_document_for_page(address, opaque, none, unsafe { &dom.Page(owner) })!
	defer { document.finalize() }
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut blob := fileapi.Blob.create('first snapshot'.bytes(), 'text/first')
	value := fileapi.add_entry_to_blob_url_store(fileapi.BlobURLObject.from_blob(blob), settings)!
	defer { document.run_unloading_cleanup_steps() }
	mut first := settings.parse_url(value)?
	assert first.origin().is_same_origin(opaque)
	mut supplied := first.parsed()?
	supplied.paths[0] = 'changed-copy'
	assert first.serialize() == value
	assert first.parsed()?.paths[0] != 'changed-copy'
	blob.deserialization_steps_utf16(libjs.utf16_string('text/second'), 'second snapshot'.bytes())
	document.set_origin(address.origin())
	second := settings.encoding_parse_url(value)?
	assert second.serialize() == first.serialize()
	assert second.origin().is_same_origin(address.origin())
	assert first.origin().is_same_origin(opaque)
	assert (first.parsed()?.blob_url_entry()?.object as liburl.BlobURLBlob).data == 'first snapshot'.bytes()
	assert (second.parsed()?.blob_url_entry()?.object as liburl.BlobURLBlob).data == 'second snapshot'.bytes()
	// Raw compatibility strings must not borrow another instance's snapshot.
	assert dom.URL{value: value}.parsed()?.blob_url_entry() == none
	first.set_fragment('retained')
	assert first.serialize() == '${value}#retained'
	assert first.origin().is_same_origin(opaque)
	assert first.with_query('changed').origin().is_same_origin(opaque)
	fileapi.remove_entry_from_blob_url_store(liburl.parse(value)?)
	assert settings.parse_url(value)?.parsed()?.blob_url_entry() == none
	assert first.parsed()?.blob_url_entry() != none
	assert second.parsed()?.blob_url_entry() != none
	first.value = 'https://direct-value-edit.test/page'
	assert first.parsed()?.blob_url_entry() == none
	assert first.origin().serialize() == 'https://direct-value-edit.test'
}
