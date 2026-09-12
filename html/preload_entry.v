// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/PreloadEntry.{h,cpp}.
module html

import dom

pub type PreloadedResponseAvailable = fn (LinkResourceResponse)

@[heap]
pub struct PreloadEntry {
pub mut:
	integrity_metadata    string
	response              ?LinkResourceResponse
	on_response_available ?PreloadedResponseAvailable
}

pub fn create_a_preload_key(request PotentialCORSRequest) PreloadKey {
	return PreloadKey.create(request)
}

fn preload_key_storage_key(key PreloadKey) string {
	url := key.url.serialize()
	destination := if value := key.destination { value.str() } else { '-' }
	return '${url.len}:${url}|${destination}|${key.mode}|${key.credentials_mode}'
}

pub fn store_preloaded_resource(document &dom.Document, key PreloadKey, entry &PreloadEntry) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_preloaded_resource_entry(preload_key_storage_key(key), voidptr(entry))
}

pub fn (mut entry PreloadEntry) set_response(response LinkResourceResponse) {
	entry.response = response
	if callback := entry.on_response_available {
		callback(response)
		entry.on_response_available = none
	}
}

// https://html.spec.whatwg.org/multipage/links.html#consume-a-preloaded-resource
pub fn consume_a_preloaded_resource(document &dom.Document, url dom.URL, destination ?RequestDestination, mode PotentialCORSRequestMode, credentials_mode CredentialsMode, integrity_metadata string, on_response_available PreloadedResponseAvailable) bool {
	key := PreloadKey{
		url: url
		destination: destination
		mode: mode
		credentials_mode: credentials_mode
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	handle := mutable_document.take_preloaded_resource_entry(preload_key_storage_key(key)) or {
		return false
	}
	mut entry := unsafe { &PreloadEntry(handle) }

	// FIXME: Parse and compare consumer and preload integrity metadata per SRI.
	_ = integrity_metadata
	if response := entry.response {
		on_response_available(response)
	} else {
		entry.on_response_available = on_response_available
	}
	return true
}
