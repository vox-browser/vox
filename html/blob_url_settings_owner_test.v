module html

import dom
import domurl
import fileapi
import libjs
import page
import url as liburl

fn source_blob_url_owner_document(address string, origin dom.Origin) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	mut document := create_navigation_document_for_page(dom.URL{value: address}, origin, none, unsafe { &dom.Page(owner) })!
	native := document.get_window() or { return error('missing actual Blob URL Window') }
	return document, unsafe { &WindowModel(native) }
}

fn test_source_blob_url_parser_copies_the_live_store_entry() {
	address := dom.URL{value: 'https://blob-url-owner.test/page'}
	mut document, window := source_blob_url_owner_document(address.serialize(), address.origin())!
	defer { document.finalize() }
	settings := window.environment_settings_.settings
	mut realm := unsafe { &ScriptingRealm(settings.realm()) }
	mut context := TemporaryExecutionContext.create(mut realm, .yes)
	defer { context.close() }
	mut blob := fileapi.Blob.create('actual Blob payload'.bytes(), 'text/plain')
	value := create_object_url(fileapi.BlobURLObject.from_blob(blob))!
	record := liburl.parse(value)?
	defer { fileapi.remove_entry_from_blob_url_store(record) }
	assert value.starts_with('blob:https://blob-url-owner.test/')
	live := fileapi.resolve_a_blob_url(record)?
	assert voidptr(live.object.blob?) == voidptr(blob)
	assert live.environment.blob_url_settings_identity() == voidptr(settings)
	parsed := domurl.parse('${value}#fragment', none, none)?
	assert parsed.blob_url_entry() != none
	mut snapshot := parsed.blob_url_entry()?
	assert snapshot.environment.origin.is_same_origin(settings.origin().liburl_origin()?)
	assert snapshot.object is liburl.BlobURLBlob
	mut object := snapshot.object as liburl.BlobURLBlob
	assert object.type_ == 'text/plain'
	assert object.data == 'actual Blob payload'.bytes()
	object.data[0] = `X`
	assert blob.raw_bytes() == 'actual Blob payload'.bytes()
	assert (parsed.blob_url_entry()?.object as liburl.BlobURLBlob).data == 'actual Blob payload'.bytes()
	// Live records may be populated through Source deserialization after
	// insertion. Fresh parses copy current data; earlier URLs retain theirs.
	raw_type := libjs.utf16_string_from_code_units([u16(0xD800), 0, 0xDC00, 0xD83D, 0xDE00])
	blob.deserialization_steps_utf16(raw_type, [u8(0), 1, 255])
	later := domurl.parse_from_byte_string(value, none, none)?
	later_object := later.blob_url_entry()?.object as liburl.BlobURLBlob
	assert later_object.data == [u8(0), 1, 255]
	assert later_object.type_.bytes() == [u8(0xED), 0xA0, 0x80, 0, 0xED, 0xB0, 0x80, 0xF0, 0x9F, 0x98, 0x80]
	assert (parsed.blob_url_entry()?.object as liburl.BlobURLBlob).type_ == 'text/plain'
	fileapi.remove_entry_from_blob_url_store(record.with_fragment('fragment'))
	assert fileapi.resolve_a_blob_url(record) != none
	fileapi.remove_entry_from_blob_url_store(record)
	assert fileapi.resolve_a_blob_url(record) == none
	assert domurl.parse(value, none, none)?.blob_url_entry() == none
	assert (parsed.blob_url_entry()?.object as liburl.BlobURLBlob).data == 'actual Blob payload'.bytes()
	// The public API URL parser uses the basic parser in pinned Source.
	assert domurl.DOMURL.construct_impl(value, none)!.origin() == 'https://blob-url-owner.test'
	assert domurl.parse('https://non-blob-owner.test/', none, none)?.blob_url_entry() == none
	assert domurl.parse('https://[invalid', none, none) == none
}

fn test_source_blob_url_store_retains_settings_through_document_reassociation() {
	opaque := dom.origin_create_opaque()
	mut original, mut window := source_blob_url_owner_document('https://blob-owner-opaque.test/page', opaque)!
	address := dom.URL{value: 'https://blob-owner-replacement.test:8443/page'}
	mut replacement, _ := source_blob_url_owner_document(address.serialize(), address.origin())!
	defer {
		window.set_associated_document(original)
		original.finalize()
		replacement.finalize()
	}
	settings := window.environment_settings_.settings
	mut realm := unsafe { &ScriptingRealm(settings.realm()) }
	mut context := TemporaryExecutionContext.create(mut realm, .yes)
	defer { context.close() }
	value := create_object_url(fileapi.BlobURLObject.from_blob(fileapi.Blob.construct(none, none)))!
	assert value.starts_with('blob:ladybird/')
	record := liburl.parse(value)?
	defer { fileapi.remove_entry_from_blob_url_store(record) }
	before := domurl.parse(value, none, none)?
	assert before.origin().is_same_origin(opaque.liburl_origin()?)
	window.set_associated_document(replacement)
	after := domurl.parse(value, none, none)?
	assert after.origin().is_same_origin(replacement.origin().liburl_origin()?)
	assert after.origin().serialize() == 'https://blob-owner-replacement.test:8443'
	assert before.origin().is_same_origin(opaque.liburl_origin()?)
	assert fileapi.resolve_a_blob_url(record)?.environment.blob_url_settings_identity() == voidptr(settings)
	new_value := create_object_url(fileapi.BlobURLObject.from_blob(fileapi.Blob.construct(none, none)))!
	assert new_value.starts_with('blob:https://blob-owner-replacement.test:8443/')
	fileapi.remove_entry_from_blob_url_store(liburl.parse(new_value)?)
	window.set_associated_document(original)
	assert domurl.parse(value, none, none)?.origin().is_same_origin(opaque.liburl_origin()?)
}

fn test_source_blob_url_unload_uses_settings_identity_and_current_context() {
	address := dom.URL{value: 'https://blob-url-cleanup-owner.test/page'}
	mut first, first_window := source_blob_url_owner_document(address.serialize(), address.origin())!
	mut second, second_window := source_blob_url_owner_document(address.serialize(), address.origin())!
	defer { first.finalize(); second.finalize() }
	first_settings := first_window.environment_settings_.settings
	second_settings := second_window.environment_settings_.settings
	mut second_environment := second_settings.environment()
	second_environment.id = first_settings.environment().id
	mut first_realm := unsafe { &ScriptingRealm(first_settings.realm()) }
	mut first_context := TemporaryExecutionContext.create(mut first_realm, .yes)
	defer { first_context.close() }
	blob := fileapi.Blob.create([u8(7)], '')
	first_url := liburl.parse(create_object_url(fileapi.BlobURLObject.from_blob(blob))!)?
	mut second_realm := unsafe { &ScriptingRealm(second_settings.realm()) }
	mut second_context := TemporaryExecutionContext.create(mut second_realm, .yes)
	second_url := liburl.parse(create_object_url(fileapi.BlobURLObject.from_blob(blob))!)?
	assert fileapi.resolve_a_blob_url(second_url)?.environment.blob_url_settings_identity() == voidptr(second_settings)
	second_context.close()
	first_again := liburl.parse(create_object_url(fileapi.BlobURLObject.from_blob(blob))!)?
	assert fileapi.resolve_a_blob_url(first_again)?.environment.blob_url_settings_identity() == voidptr(first_settings)
	retained := domurl.parse(first_url.serialize(false), none, none)?
	first.run_unloading_cleanup_steps()
	assert fileapi.resolve_a_blob_url(first_url) == none
	assert fileapi.resolve_a_blob_url(first_again) == none
	assert fileapi.resolve_a_blob_url(second_url) != none
	assert retained.blob_url_entry() != none
	assert (retained.blob_url_entry()?.object as liburl.BlobURLBlob).data == [u8(7)]
	second.run_unloading_cleanup_steps()
	assert fileapi.resolve_a_blob_url(second_url) == none
}
