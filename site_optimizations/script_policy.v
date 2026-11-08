module main

import url

enum BrowserScriptPolicy {
	automatic
	enabled
	disabled
}

// Keep this list explicit: a page's markup cannot establish whether its
// navigation, forms and content will remain usable without JavaScript.
const html_css_only_sites = ['wikipedia.org']

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
