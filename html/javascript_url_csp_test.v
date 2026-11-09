module html

import dom

fn test_javascript_url_navigation_requires_unsafe_hashes_and_the_exact_decoded_hash() {
	for policy, blocked in {
		"script-src 'nonce-abc'":true,
		"script-src 'nonce-abc' 'sha256-l0Wxf12cHMZT6UQ2zsQ7AcFSb6Y198d37Ki8zWITecM='":true,
		"script-src 'nonce-abc' 'unsafe-hashes' 'sha256-l0Wxf12cHMZT6UQ2zsQ7AcFSb6Y198d37Ki8zWITecM='":false,
		"script-src 'unsafe-inline'":false,
	} {
		url := dom.URL{value:'https://navigation-csp.test/'}
		mut document := parse_navigation_document('<!doctype html>',url,url.origin(),none)!
		defer { document.finalize() }
		window := unsafe { &WindowModel(document.get_window() or { panic('window') }) }
		mut settings := window.environment_settings_.settings
		settings.set_policy_container(&PolicyContainer{csp_list:[parse_response_csp_policy(policy,.enforce,settings.origin())]})
		assert javascript_url_is_blocked_by_csp(document,dom.URL{value:'javascript:navigated%28%29%3B'}) == blocked,policy
	}
}
