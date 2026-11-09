module main

import adblock
import cachepolicy
import time

$if prealloc {
	import platform
}

struct BrowserResourceCacheEntry {
	final_url string
	body string
	headers []adblock.ResponseHeader
	metadata cachepolicy.Response
}

fn browser_resource_policy_headers(headers []adblock.ResponseHeader) []cachepolicy.Header {
	return headers.map(cachepolicy.Header{name: it.name, value: it.value})
}

fn browser_resource_cache_entry(path string) ?BrowserResourceCacheEntry {
	$if prealloc {
		// Parse receipts and hash potentially large bytes in bounded storage.
		// Only the verified response snapshot escapes to the caller's arena.
		scratch := platform.begin_thread_scratch('cached resource response')
		entry := cachepolicy.read_disk_entry(path, max_disk_cache_entry_size) or {
			scratch.finish()
			return none
		}
		scratch.leave()
		owned := adapt_browser_resource_cache_entry(entry, true)
		scratch.finish()
		return owned
	}
	entry := cachepolicy.read_disk_entry(path, max_disk_cache_entry_size) or { return none }
	return adapt_browser_resource_cache_entry(entry, false)
}

fn adapt_browser_resource_cache_entry(entry cachepolicy.DiskEntry, own bool) BrowserResourceCacheEntry {
	mut headers := []adblock.ResponseHeader{cap: entry.response.headers.len}
	for header in entry.response.headers {
		headers << adblock.ResponseHeader{
			name: if own { header.name.clone() } else { header.name }
			value: if own { header.value.clone() } else { header.value }
		}
	}
	return BrowserResourceCacheEntry{
		final_url: if own { entry.final_url.clone() } else { entry.final_url }
		body: if own { entry.body.clone() } else { entry.body }
		headers: headers
		metadata: cachepolicy.Response{
			...entry.response
			headers: browser_resource_policy_headers(headers)
		}
	}
}

// A response retained for painting is not automatically reusable by the next
// navigation. Consuming a preload during its own installation remains a
// separate operation; no-cache responses can still satisfy that one request.
fn reusable_browser_resource(resource PreloadedResource, request_type string) bool {
	if resource.error != '' || resource.adblock_replacement
		|| resource.final_url != resource.url { return false }
	return cachepolicy.evaluate(cachepolicy.Request{}, cachepolicy.Response{
		status: u32(resource.status_code)
		headers: browser_resource_policy_headers(resource.response_headers)
		timing: cachepolicy.Timing{request_time: resource.request_time, response_time: resource.response_time}
	}, cachepolicy.ReuseOptions{storage: .disk, require_immutable: request_type == 'script'},
		time.now().unix_milli()).can_reuse()
}

// RFC 9111 section 3: a cache must not store a response whose Cache-Control
// carries no-store. The disk resource cache answers later requests from stored
// bodies without revalidation, so storing one would also replay it.
fn browser_response_forbids_storage(headers []adblock.ResponseHeader) bool {
	return cachepolicy.forbids_storage(browser_resource_policy_headers(headers))
}

// A no-store response replaces any response stored earlier for its key; the
// older one must not answer requests in its place. Readers require the final
// URL record (and status provenance, which the writer already removed).
fn discard_browser_cache_resource(path string) {
	cachepolicy.discard_disk_entry(path)
}
