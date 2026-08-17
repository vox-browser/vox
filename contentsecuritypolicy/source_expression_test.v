module contentsecuritypolicy

import url

fn test_source_expression_grammars() {
	scheme := parse_source_expression(.scheme_source, 'https:') or { panic('scheme') }
	assert (scheme.scheme_part or { '' }) == 'https'
	host := parse_source_expression(.host_source, 'https://*.example.com:8443/assets/') or {
		panic('host')
	}
	assert (host.scheme_part or { '' }) == 'https'
	assert (host.host_part or { '' }) == '*.example.com'
	assert (host.port_part or { '' }) == '8443'
	assert (host.path_part or { '' }) == '/assets/'
	assert parse_source_expression(.host_source, 'https://example.com:bad') == none
	nonce := parse_source_expression(.nonce_source, "'nonce-AbC_12=='") or { panic('nonce') }
	assert (nonce.base64_value or { '' }) == 'AbC_12=='
	hash := parse_source_expression(.hash_source, "'sha384-AbCd=='") or { panic('hash') }
	assert (hash.hash_algorithm or { '' }) == 'sha384'
	assert (hash.base64_value or { '' }) == 'AbCd=='
}

fn test_url_component_matching() {
	assert scheme_part_matches('http', 'https') == .matches
	assert scheme_part_matches('https', 'http') == .does_not_match
	assert host_part_matches('*.example.com', url.Host.from_string('www.example.com')) == .matches
	assert host_part_matches('*.example.com', url.Host.from_string('example.com')) == .does_not_match
	assert path_part_matches('/assets/', '/assets/js/app.js') == .matches
	assert path_part_matches('/assets/app.js', '/assets/other.js') == .does_not_match
}
