module main

import url
import dom

enum BrowserScriptPolicy {
	automatic
	enabled
	disabled
}

// Keep this list explicit: a page's markup cannot establish whether its
// navigation, forms and content will remain usable without JavaScript.
const html_css_only_sites = ['wikipedia.org']

fn browser_document_can_load_scripts(document &dom.Document) bool {
	if !document.is_scripting_enabled_by_embedder() { return false }
	if document.has_page() && document.page().has_scripting_enabled_owner() {
		return document.as_node().is_scripting_enabled()
	}
	// Standalone parser/loader adapters need no active browsing context. Actual
	// navigation documents use their Page/settings owner above.
	return true
}

fn browser_scripting_enabled(address string, policy BrowserScriptPolicy) bool {
	if policy == .enabled { return true }
	if policy == .disabled { return false }
	parsed := url.parse(address) or { return true }
	if parsed.scheme !in ['http', 'https'] { return true }
	host := parsed.host or { return true }
	hostname := host.serialize().trim_right('.').to_lower()
	for site in html_css_only_sites {
		if hostname == site || hostname.ends_with('.${site}') { return false }
	}
	return true
}
