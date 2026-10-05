module html

import dom
import domurl
import fileapi
import page
import storageapi
import url as liburl

fn source_blob_partition_document(address string, origin dom.Origin) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	mut document := create_navigation_document_for_page(dom.URL{address}, origin, none, unsafe { &dom.Page(owner) })!
	native := document.get_window() or { return error('missing actual Blob partition Window') }
	return document, unsafe { &WindowModel(native) }
}

fn test_source_blob_partition_keeps_opaque_identity_and_returns_a_copied_object() {
	opaque := dom.origin_create_opaque()
	mut document, window := source_blob_partition_document('https://blob-partition-opaque.test/page', opaque)!
	mut same, same_window := source_blob_partition_document('https://different-creation.test/page', opaque)!
	mut other, other_window := source_blob_partition_document('https://blob-partition-opaque.test/page', dom.origin_create_opaque())!
	defer { document.finalize(); same.finalize(); other.finalize() }
	settings := window.environment_settings_.settings
	value := fileapi.add_entry_to_blob_url_store(fileapi.BlobURLObject.from_blob(fileapi.Blob.create([u8(0), 255], 'text/plain')), settings)!
	record := liburl.parse(value)?
	defer { fileapi.remove_entry_from_blob_url_store(record) }
	entry := domurl.parse(value, none, none)?.blob_url_entry()?
	assert settings.origin().serialize() == 'null'
	assert other.origin().serialize() == 'null'
	assert fileapi.check_for_same_partition_blob_url_usage(entry, settings)
	assert fileapi.check_for_same_partition_blob_url_usage(entry, same_window.environment_settings_.settings)
	assert fileapi.check_for_same_partition_blob_url_usage(entry, settings.environment())
	assert !fileapi.check_for_same_partition_blob_url_usage(entry, other_window.environment_settings_.settings)
	assert storageapi.obtain_a_storage_key(storageapi.StorageEnvironment{ origin: opaque.liburl_origin()? }) == none
	access := fileapi.BlobURLObtainEnvironment(fileapi.BlobURLRequestEnvironment{ environment: settings })
	mut copied := fileapi.obtain_a_blob_object(entry, access)?
	assert copied is liburl.BlobURLBlob
	mut object := copied as liburl.BlobURLBlob
	assert object.type_ == 'text/plain' && object.data == [u8(0), 255]
	object.data[0] = 9
	assert (entry.object as liburl.BlobURLBlob).data == [u8(0), 255]
	other_access := fileapi.BlobURLObtainEnvironment(fileapi.BlobURLRequestEnvironment{ environment: other_window.environment_settings_.settings })
	assert fileapi.obtain_a_blob_object(entry, other_access) == none
	assert fileapi.obtain_a_blob_object(entry, fileapi.TopLevelNavigation{}) != none
	assert fileapi.obtain_a_blob_object(entry, fileapi.TopLevelSelfFetch{}) != none
}

fn test_source_blob_partition_uses_non_storage_file_origins() {
	first_origin := dom.origin_create_opaque_file()
	second_origin := dom.origin_create_opaque_file()
	mut first, first_window := source_blob_partition_document('file:///tmp/blob-partition-first.html', first_origin)!
	mut second, second_window := source_blob_partition_document('file:///tmp/blob-partition-second.html', second_origin)!
	defer { first.finalize(); second.finalize() }
	settings := first_window.environment_settings_.settings
	value := fileapi.add_entry_to_blob_url_store(fileapi.BlobURLObject.from_blob(fileapi.Blob.construct(none, none)), settings)!
	record := liburl.parse(value)?
	defer { fileapi.remove_entry_from_blob_url_store(record) }
	entry := domurl.parse(value, none, none)?.blob_url_entry()?
	assert entry.environment.origin.is_opaque_file_origin()
	assert fileapi.check_for_same_partition_blob_url_usage(entry, settings)
	assert !fileapi.check_for_same_partition_blob_url_usage(entry, second_window.environment_settings_.settings)
	first_storage := storageapi.obtain_a_storage_key(storageapi.StorageEnvironment{ origin: first_origin.liburl_origin()? })?
	second_storage := storageapi.obtain_a_storage_key(storageapi.StorageEnvironment{ origin: second_origin.liburl_origin()? })?
	assert first_storage.equals(second_storage)
}

fn test_source_blob_partition_selects_actual_settings_or_live_creation_url() {
	address := dom.URL{'https://blob-partition-tuple.test:8443/creator'}
	mut document, mut window := source_blob_partition_document(address.serialize(), address.origin())!
	replacement_address := dom.URL{'https://blob-partition-replacement.test:9443/page'}
	mut replacement, _ := source_blob_partition_document(replacement_address.serialize(), replacement_address.origin())!
	defer {
		window.set_associated_document(document)
		document.finalize()
		replacement.finalize()
	}
	settings := window.environment_settings_.settings
	value := fileapi.add_entry_to_blob_url_store(fileapi.BlobURLObject.from_blob(fileapi.Blob.construct(none, none)), settings)!
	record := liburl.parse(value)?
	defer { fileapi.remove_entry_from_blob_url_store(record) }
	entry := domurl.parse(value, none, none)?.blob_url_entry()?
	mut environment := Environment.create('actual-base-environment', address, none, none, none)
	assert fileapi.check_for_same_partition_blob_url_usage(entry, environment)
	environment.creation_url = dom.URL{'https://blob-partition-tuple.test:9443/creator'}
	assert !fileapi.check_for_same_partition_blob_url_usage(entry, environment)
	environment.creation_url = dom.URL{'https://different-blob-partition.test:8443/creator'}
	assert !fileapi.check_for_same_partition_blob_url_usage(entry, environment)
	mut settings_environment := settings.environment()
	settings_environment.creation_url = environment.creation_url
	assert fileapi.check_for_same_partition_blob_url_usage(entry, settings_environment)
	window.set_associated_document(replacement)
	assert !fileapi.check_for_same_partition_blob_url_usage(entry, settings)
	assert !fileapi.check_for_same_partition_blob_url_usage(entry, settings_environment)
	fresh := domurl.parse(value, none, none)?.blob_url_entry()?
	assert fileapi.check_for_same_partition_blob_url_usage(fresh, settings)
	assert !fresh.environment.origin.is_same_origin(entry.environment.origin)
	window.set_associated_document(document)
	assert fileapi.check_for_same_partition_blob_url_usage(entry, settings)
}

fn test_source_blob_url_revoke_uses_current_settings_and_source_fragment_serialization() {
	address := dom.URL{'https://blob-revoke-owner.test:8443/page'}
	mut document, window := source_blob_partition_document(address.serialize(), address.origin())!
	mut other, other_window := source_blob_partition_document('https://blob-revoke-owner.test:9443/page', dom.URL{'https://blob-revoke-owner.test:9443/page'}.origin())!
	defer { document.finalize(); other.finalize() }
	settings := window.environment_settings_.settings
	mut realm := unsafe { &ScriptingRealm(settings.realm()) }
	mut context := TemporaryExecutionContext.create(mut realm, .yes)
	defer { context.close() }
	value := create_object_url(fileapi.BlobURLObject.from_blob(fileapi.Blob.create([u8(1)], '')))!
	record := liburl.parse(value)?
	defer { fileapi.remove_entry_from_blob_url_store(record) }
	mut other_realm := unsafe { &ScriptingRealm(other_window.environment_settings_.settings.realm()) }
	mut other_context := TemporaryExecutionContext.create(mut other_realm, .yes)
	revoke_object_url(value)
	assert fileapi.resolve_a_blob_url(record) != none
	other_context.close()
	revoke_object_url('https://[invalid')
	revoke_object_url('https://blob-revoke-owner.test:8443/page')
	revoke_object_url('${value}#fragment')
	assert fileapi.resolve_a_blob_url(record) != none
	retained := domurl.parse(value, none, none)?
	revoke_object_url(value)
	assert fileapi.resolve_a_blob_url(record) == none
	assert retained.blob_url_entry() != none
	assert domurl.parse(value, none, none)?.blob_url_entry() == none
	revoke_object_url(value)
}
