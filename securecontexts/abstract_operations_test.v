module securecontexts

import dom

fn test_trustworthy_url_special_cases_and_origins() {
	for value in ['about:blank', 'about:srcdoc', 'data:text/plain,ok', 'https://example.test/',
		'wss://example.test/', 'http://localhost/', 'http://sub.localhost./', 'file:///tmp/x',
		'resource://ladybird/x', 'http://127.1.2.3/', 'http://192.0.2.1/', 'http://[::1]/'] {
		assert is_url_potentially_trustworthy(dom.URL{value: value}) == .potentially_trustworthy, value
	}
	assert is_url_potentially_trustworthy(dom.URL{value: 'http://example.test/'}) == .not_trustworthy
	assert is_origin_potentially_trustworthy(dom.origin_create_opaque()) == .not_trustworthy
}
