module main

import adblock
import http
import os

// RFC 9111 section 3: a cache must not store a response whose Cache-Control
// carries no-store. The disk resource cache answers later requests from stored
// bodies without revalidation, so storing one would also replay it.
fn browser_response_forbids_storage(headers []adblock.ResponseHeader) bool {
	for header in headers {
		if header.name.len == 'cache-control'.len && header.name.to_lower() == 'cache-control'
			&& http.contains_cache_control_directive(header.value, 'no-store') {
			return true
		}
	}
	return false
}

// A no-store response replaces any response stored earlier for its key; the
// older one must not answer requests in its place. Readers require the final
// URL record (and status provenance, which the writer already removed).
fn discard_browser_cache_resource(path string) {
	os.rm(path + '.url') or {}
	os.rm(path) or {}
}
