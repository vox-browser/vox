module html

import dom
import page
import storageapi

fn source_storage_key_document(address string, origin dom.Origin) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	mut document := create_navigation_document_for_page(dom.URL{address}, origin, none, unsafe { &dom.Page(owner) })!
	native := document.get_window() or { return error('missing actual storage-key Window') }
	window := unsafe { &WindowModel(native) }
	return document, window
}

fn test_source_storage_key_reads_actual_settings_origin_after_window_reassociation() {
	opaque := dom.origin_create_opaque()
	mut original, mut window := source_storage_key_document('https://opaque-storage-key-owner.test/page', opaque)!
	address := dom.URL{'https://replacement-storage-key-owner.test:8443/page'}
	mut replacement, _ := source_storage_key_document(address.serialize(), address.origin())!
	defer {
		window.set_associated_document(original)
		original.finalize()
		replacement.finalize()
	}
	settings := window.environment_settings_.settings
	first := storageapi.obtain_a_storage_key_for_origin(settings.origin().liburl_origin()?)
	assert first.origin.is_same_origin(opaque.liburl_origin()?)
	assert first.equals(storageapi.obtain_a_storage_key_for_origin(original.origin().liburl_origin()?))
	assert storageapi.obtain_a_storage_key(storageapi.StorageEnvironment{ origin: first.origin }) == none
	window.set_associated_document(replacement)
	current := storageapi.obtain_a_storage_key_for_origin(settings.origin().liburl_origin()?)
	assert current.to_string() == 'https://replacement-storage-key-owner.test:8443'
	assert !current.equals(first)
	assert current.equals(storageapi.obtain_a_storage_key_for_origin(replacement.origin().liburl_origin()?))
	assert storageapi.obtain_a_storage_key(storageapi.StorageEnvironment{ origin: current.origin }) != none
	window.set_associated_document(original)
	assert storageapi.obtain_a_storage_key_for_origin(settings.origin().liburl_origin()?).equals(first)
}
