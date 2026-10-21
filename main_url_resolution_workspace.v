module main

import platform
import url

// Resource discovery keeps the serialized URL, not the parser records or its
// copied component strings. Preserve the existing fallback policy and publish
// only the resulting string into the caller's allocation owner.
fn resolve_document_reference(reference string, base string) string {
	trimmed := reference.trim_space()
	if trimmed == '' { return base }
	mut work := platform.begin_thread_scratch('document reference resolution')
	resolved := resolve_document_reference_in_workspace(trimmed, base)
	work.leave()
	owned := resolved.clone()
	work.finish()
	return owned
}

fn resolve_document_reference_in_workspace(trimmed string, base string) string {
	if parsed := url.parse(trimmed) { return parsed.serialize(false) }
	base_url := url.parse(base) or { return resolve_url(trimmed, '') }
	return (url.parse_with_base(trimmed, &base_url) or { return resolve_url(trimmed, '') }).serialize(false)
}
