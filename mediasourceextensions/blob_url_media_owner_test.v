module mediasourceextensions

import dom
import fetch
import fileapi
import html
import page
import url as liburl

fn source_blob_media_document(address string, origin dom.Origin) !(&dom.Document, &html.EnvironmentSettingsObject) {
	owner := page.Page.create(1)!
	mut document := html.create_navigation_document_for_page(dom.URL{value: address}, origin, none, unsafe { &dom.Page(owner) })!
	return document, unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
}

fn source_blob_media_element(document &dom.Document) !&html.HTMLMediaElement {
	video := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video')!
	return html.html_media_element_for_dom_element(video) or { return error('missing actual media element') }
}

fn source_blob_media_unused_fetch(_ &fetch.Request) !&fetch.Response {
	return error('MediaSource URL must not enter network transport')
}

fn test_source_media_url_load_attaches_the_actual_source_store_object() {
	opaque := dom.origin_create_opaque()
	mut document, settings := source_blob_media_document('https://blob-media-actual-owner.test/page', opaque)!
	defer { document.run_unloading_cleanup_steps(); document.finalize() }
	mut media := source_blob_media_element(document)!
	source := MediaSource.create()
	value := fileapi.add_entry_to_blob_url_store(source.blob_url_object('actual-media-caller'), settings)!
	url := settings.parse_url(value)?
	assert url.parsed()?.blob_url_entry()?.object is liburl.BlobURLMediaSource
	assert url.origin().is_same_origin(opaque)
	media.set_source(value)
	media.load()!
	assert media.current_src() == value
	assert source.ready_state() == .open
	assert source.media_element_assigned_to()? == media
	media.set_source(none)
	media.load()!
	assert source.ready_state() == .closed
	assert source.media_element_assigned_to() == none
	mut fragment_url := url
	fragment_url.set_fragment('retained-tag')
	media.load_url_resource(fragment_url, none)!
	assert source.ready_state() == .open
	assert source.media_element_assigned_to()? == media
	assert media.current_src() == '${value}#retained-tag'
	// Fetch receives the same genuine empty MediaSource tag, but its Blob
	// response arm must reject it even for top-level navigation.
	mut request := fetch.Request.create()
	request.set_url(url)
	request.destination = .document
	host := fetch.FetchHost{perform: source_blob_media_unused_fetch}
	response := fetch.scheme_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), host).response()?
	assert response.is_network_error()
}

@[heap]
struct SourceBlobMediaFetchObservation {
mut:
	calls int
	url dom.URL
}

fn source_blob_media_remote_hook(observation &SourceBlobMediaFetchObservation) html.MediaResourceFetchHook {
	return fn [observation] (url dom.URL, offset u64) !html.MediaResourceResponse {
		mut seen := unsafe { &SourceBlobMediaFetchObservation(observation) }
		seen.calls++
		seen.url = url
		assert offset == 0
		return html.MediaResourceResponse{mime_type: 'video/webm', duration: 1}
	}
}

fn test_source_media_authorization_uses_copied_origin_then_current_node_settings() {
	address := dom.URL{value: 'https://blob-media-snapshot.test/creator'}
	foreign := dom.URL{value: 'https://foreign-blob-media.test/page'}
	mut document, settings := source_blob_media_document(address.serialize(), address.origin())!
	defer { document.run_unloading_cleanup_steps(); document.finalize() }
	mut media := source_blob_media_element(document)!
	seen := &SourceBlobMediaFetchObservation{}
	media.set_fetch_hook(source_blob_media_remote_hook(seen))
	source := MediaSource.create()
	value := fileapi.add_entry_to_blob_url_store(source.blob_url_object('snapshot-origin-source'), settings)!
	old := settings.parse_url(value)?
	document.set_origin(foreign.origin())
	media.load_url_resource(old, none)!
	assert seen.calls == 1 && seen.url == old
	assert source.ready_state() == .closed
	assert source.media_element_assigned_to() == none
	// A fresh parse copies the live creator's new origin. The earlier URL's
	// authorization still uses its own old origin, despite the live store.
	fresh := settings.parse_url(value)?
	assert fresh.origin().is_same_origin(foreign.origin())
	assert old.origin().is_same_origin(address.origin())
	media.load_url_resource(fresh, none)!
	assert seen.calls == 1
	assert source.ready_state() == .open
	assert source.media_element_assigned_to()? == media
}

fn test_source_media_self_fetch_uses_settings_creation_url_and_actual_navigable_parent() {
	address := dom.URL{value: 'https://blob-media-self.test/creator'}
	foreign := dom.URL{value: 'https://foreign-media-self.test/page'}
	mut creator, settings := source_blob_media_document(address.serialize(), address.origin())!
	mut document, foreign_settings := source_blob_media_document(foreign.serialize(), foreign.origin())!
	defer { creator.run_unloading_cleanup_steps(); creator.finalize(); document.finalize() }
	source := MediaSource.create()
	value := fileapi.add_entry_to_blob_url_store(source.blob_url_object('self-fetch-source'), settings)!
	url := settings.parse_url(value)?
	mut media := source_blob_media_element(document)!
	seen := &SourceBlobMediaFetchObservation{}
	media.set_fetch_hook(source_blob_media_remote_hook(seen))
	// Changing Document URL alone must not select Source's self-fetch bypass.
	document.set_url(url)
	assert foreign_settings.environment().creation_url != url
	media.load_url_resource(url, none)!
	assert seen.calls == 1 && source.ready_state() == .closed
	mut environment := foreign_settings.environment()
	environment.creation_url = url
	mut native := document.navigable()?
	native.parent_ = creator.navigable()?
	media.load_url_resource(url, none)!
	assert seen.calls == 2 && source.ready_state() == .closed
	native.parent_ = none
	// The settings creation URL now matches and its real navigable is root.
	// Its foreign origin still differs; only Source's bypass allows attachment.
	media.load_url_resource(url, none)!
	assert seen.calls == 2
	assert source.ready_state() == .open
	assert source.media_element_assigned_to()? == media
}

fn test_source_blob_media_tag_falls_through_to_the_remote_fetch_path() {
	address := dom.URL{value: 'https://blob-media-blob.test/page'}
	mut document, settings := source_blob_media_document(address.serialize(), address.origin())!
	defer { document.run_unloading_cleanup_steps(); document.finalize() }
	mut media := source_blob_media_element(document)!
	seen := &SourceBlobMediaFetchObservation{}
	media.set_fetch_hook(source_blob_media_remote_hook(seen))
	value := fileapi.add_entry_to_blob_url_store(fileapi.BlobURLObject.from_blob(fileapi.Blob.create([u8(0)], 'video/webm')), settings)!
	url := settings.parse_url(value)?
	media.load_url_resource(url, none)!
	assert seen.calls == 1
	assert seen.url.parsed()?.blob_url_entry()?.object is liburl.BlobURLBlob
	assert media.src_object() == none
}
