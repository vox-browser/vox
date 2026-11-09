module main

import browserjs
import dom
import html
import platform
import url as liburl

fn blob_entry_startup(source string, is_shared bool, module_ bool) browserjs.WorkerStartup {
	origin_url := dom.URL{ value: 'https://blob-workers.test/owner' }
	mut parsed := liburl.parse('blob:https://blob-workers.test/entry-id#worker') or { panic('URL') }
	parsed.set_blob_url_entry(liburl.BlobURLEntry{
		object:      liburl.BlobURLBlob{ type_: 'text/javascript', data: source.bytes() }
		environment: liburl.BlobURLEnvironment{ origin: origin_url.origin().liburl_origin() or { panic('origin') } }
	})
	return browserjs.WorkerStartup{
		url:       dom.url_from_record(parsed)
		options:   html.WorkerOptions{ type_: if module_ { .module_ } else { .classic }, name: 'blob worker' }
		is_shared: is_shared
		outside:   html.SerializedEnvironmentSettingsObject{
			creation_url: origin_url
			api_base_url: origin_url
			origin:       origin_url.origin()
			global:       html.SerializedWindow{ associated_document: html.SerializedDocument{ url: origin_url, relevant_settings_object_is_secure_context: true } }
		}
	}
}

fn test_worker_blob_entry_round_trip_owns_its_bytes_type_and_creator_origin() {
	for is_shared in [false, true] {
		mut caller := platform.begin_thread_scratch('Blob startup sender')
		encoded := browserjs.encode_worker_startup(blob_entry_startup('postMessage(42)', is_shared, false))!
		caller.finish()
		assert encoded[..4].bytestr() == if is_shared { 'VXS4' } else { 'VXS3' }
		mut receiver := platform.begin_thread_scratch('Blob startup receiver')
		actual := browserjs.decode_worker_startup(encoded)!
		receiver.finish()
		entry := actual.url.parsed()?.blob_url_entry()?
		assert actual.is_shared == is_shared
		assert actual.url.serialize() == 'blob:https://blob-workers.test/entry-id#worker'
		assert entry.environment.origin.serialize() == 'https://blob-workers.test'
		assert entry.object is liburl.BlobURLBlob
		assert entry.object.type_ == 'text/javascript' && entry.object.data == 'postMessage(42)'.bytes()
	}
}

fn test_worker_blob_entry_rejects_truncation_trailing_data_and_invalid_snapshot_metadata() {
	original := blob_entry_startup('postMessage(42)', false, false)
	bytes := browserjs.encode_worker_startup(original)!
	for end in 0 .. bytes.len {
		if _ := browserjs.decode_worker_startup(bytes[..end]) {
			assert false, '${end}'
		}
	}
	mut trailing := bytes.clone()
	trailing << 0
	if _ := browserjs.decode_worker_startup(trailing) {
		assert false
	}
	// Preserve the address length while invalidating the Blob scheme.
	mut wrong_scheme := bytes.clone()
	wrong_scheme[26] = `x`
	if _ := browserjs.decode_worker_startup(wrong_scheme) {
		assert false
	}
	// The snapshot's creator origin uses the existing nonce-preserving IPC form.
	mut opaque := original.url.parsed()?
	origin := dom.origin_create_opaque()
	opaque.set_blob_url_entry(liburl.BlobURLEntry{
		object:      liburl.BlobURLBlob{ type_: '', data: [] }
		environment: liburl.BlobURLEnvironment{ origin: origin.liburl_origin()? }
	})
	actual := browserjs.decode_worker_startup(browserjs.encode_worker_startup(browserjs.WorkerStartup{ ...original, url: dom.url_from_record(opaque) })!)!
	assert actual.url.parsed()?.blob_url_entry()?.environment.origin.is_same_origin(origin.liburl_origin()?)
}

fn test_worker_child_fetches_the_saved_blob_entry_without_a_process_local_url_store() {
	for module_ in [false, true] {
		startup := blob_entry_startup('postMessage(location.href);close();', false, module_)
		mut child := browserjs.WorkerChildSession.create(none)
		defer { child.close() }
		child.accept(browserjs.WorkerProcessFrame{ kind: u32(browserjs.WorkerAgentFrameKind.start), bytes: browserjs.encode_worker_startup(startup)! })!
		frames := child.take_outgoing()
		assert frames.len == 2
		assert frames[0].kind == u32(browserjs.WorkerAgentFrameKind.ready)
		assert frames[1].kind == u32(browserjs.WorkerAgentFrameKind.message)
		assert child.is_finished()
	}
}

fn test_worker_startup_keeps_legacy_headers_and_blob_fetch_origin_checks() {
	for is_shared in [false, true] {
		original := blob_entry_startup('', is_shared, false)
		ordinary := browserjs.WorkerStartup{ ...original, url: dom.URL{ value: 'https://blob-workers.test/worker.js' } }
		bytes := browserjs.encode_worker_startup(ordinary)!
		assert bytes[..4].bytestr() == if is_shared { 'VXS2' } else { 'VXS1' }
		actual := browserjs.decode_worker_startup(bytes)!
		assert actual.is_shared == is_shared && actual.url == ordinary.url
		assert actual.url.parsed()?.blob_url_entry() == none
	}
	original := blob_entry_startup('postMessage("wrong origin")', false, false)
	outside := html.SerializedEnvironmentSettingsObject{ ...original.outside, origin: dom.URL{ value: 'https://other-blob-owner.test/' }.origin() }
	mut child := browserjs.WorkerChildSession.create(none)
	defer { child.close() }
	child.accept(browserjs.WorkerProcessFrame{
		kind:  u32(browserjs.WorkerAgentFrameKind.start)
		bytes: browserjs.encode_worker_startup(browserjs.WorkerStartup{ ...original, outside: outside })!
	})!
	frames := child.take_outgoing()
	assert frames.len == 1 && frames[0].kind == u32(browserjs.WorkerAgentFrameKind.load_failure)
}
