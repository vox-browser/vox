module mediasourceextensions

import dom
import domurl
import fileapi
import html
import page
import url as liburl

fn test_source_blob_url_parser_snapshots_a_live_media_source_as_an_empty_tag() {
	owner := page.Page.create(1)!
	address := dom.URL{value: 'https://media-source-blob-owner.test/page'}
	mut document := html.create_navigation_document_for_page(address, address.origin(), none, unsafe { &dom.Page(owner) })!
	defer { document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut realm := unsafe { &html.ScriptingRealm(settings.realm()) }
	mut context := html.TemporaryExecutionContext.create(mut realm, .yes)
	defer { context.close() }
	source := MediaSource.create()
	value := html.create_object_url(source.blob_url_object('actual-source'))!
	record := liburl.parse(value)?
	defer { fileapi.remove_entry_from_blob_url_store(record) }
	entry := fileapi.resolve_a_blob_url(record)?
	assert entry.object.kind == .media_source
	assert entry.object.media_source_handle == voidptr(source)
	assert entry.environment.blob_url_settings_identity() == voidptr(settings)
	parsed := domurl.parse('${value}#fragment', none, none)?
	snapshot := parsed.blob_url_entry()?
	assert snapshot.object is liburl.BlobURLMediaSource
	assert snapshot.environment.origin.is_same_origin(settings.origin().liburl_origin()?)
	document.run_unloading_cleanup_steps()
	assert fileapi.resolve_a_blob_url(record) == none
	assert parsed.blob_url_entry()?.object is liburl.BlobURLMediaSource
}
