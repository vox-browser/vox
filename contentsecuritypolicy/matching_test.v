module contentsecuritypolicy

import sri
import url

fn matching_url(source string, scheme string, host string, path []string, port ?u16) url.URL {
	_ = source
	return url.URL{
		scheme: scheme
		host: url.Host.from_string(host)
		paths: path
		port: port
	}
}

fn test_source_list_url_matching() {
	assert ends_with_ignoring_ascii_case('Sub.Example.TEST', '.example.test')
	assert !ends_with_ignoring_ascii_case('test', 'longer-test')
	assert substring_view('*.example.test', 1) == '.example.test'
	origin := url.Origin.tuple('http', url.Host.from_string('example.test'), none, none)
	secure_self := matching_url('', 'https', 'example.test', ['app.js'], none)
	assert does_url_match_expression_in_origin_with_redirect_count(secure_self, keyword_self, origin, 0) == .matches
	cdn := matching_url('', 'https', 'static.example.test', ['assets', 'app.js'], u16(8443))
	assert does_url_match_expression_in_origin_with_redirect_count(cdn, 'https://*.example.test:8443/assets/', origin, 0) == .matches
	assert does_url_match_expression_in_origin_with_redirect_count(cdn, 'https://*.example.test:8443/other/', origin, 0) == .does_not_match
	// Redirects deliberately ignore source-expression paths.
	assert does_url_match_expression_in_origin_with_redirect_count(cdn, 'https://*.example.test:8443/other/', origin, 1) == .matches
	assert does_url_match_source_list_in_origin_with_redirect_count(cdn, ["'none'"], origin, 0) == .does_not_match
	assert does_url_match_source_list_in_origin_with_redirect_count(cdn, ["'none'",
		'https://static.example.test:8443/assets/'], origin, 0) == .matches
}

fn test_nonce_integrity_and_script_checks() {
	assert does_nonce_match_source_list('abc', ["'nonce-abc'"]) == .matches
	assert does_nonce_match_source_list('', ["'nonce-abc'"]) == .does_not_match
	digest := sri.apply_algorithm_to_bytes('sha256', 'script'.bytes())!
	assert does_integrity_metadata_match_source_list('sha256-${digest}', [
		"'sha256-${digest}'",
	]) == .matches
	mut policy := parse_a_serialized_csp("script-src 'strict-dynamic' 'nonce-abc'", .header, .enforce)
	policy.set_self_origin(url.Origin.tuple('https', url.Host.from_string('example.test'), none, none))
	mut request := new_request(matching_url('', 'https', 'evil.test', ['x.js'], none))
	request.destination = .script
	request.parser_metadata = .parser_inserted
	assert script_directives_pre_request_check(request, policy.directives()[0], policy) == .blocked
	request.cryptographic_nonce_metadata = 'abc'
	assert script_directives_pre_request_check(request, policy.directives()[0], policy) == .allowed
}

fn test_inline_nonce_hash_and_unsafe_inline() {
	element := ElementContext{
		is_script: true
		nonce: 'xyz'
		attributes: {
			'nonce': 'xyz'
		}
		parser_inserted: true
	}
	assert does_element_match_source_list_for_type_and_source(element, ["'nonce-xyz'"], .script, 'x') == .matches
	assert does_element_match_source_list_for_type_and_source(element, [unsafe_inline, "'nonce-other'"], .script, 'x') == .does_not_match
	digest := sri.apply_algorithm_to_bytes('sha384', 'body {}'.bytes())!
	assert does_element_match_source_list_for_type_and_source(none, [
		"'sha384-${digest}'",
	], .style, 'body {}') == .matches
	assert does_element_match_source_list_for_type_and_source(none, [unsafe_hashes,
		"'sha384-${digest}'"], .style_attribute, 'body {}') == .matches
}

fn test_frame_ancestors_and_webrtc() {
	mut policy := parse_a_serialized_csp("frame-ancestors 'self'; webrtc 'allow'", .header, .enforce)
	origin := url.Origin.tuple('https', url.Host.from_string('example.test'), none, none)
	policy.set_self_origin(origin)
	response := Response{
		url: matching_url('', 'https', 'child.test', [], none)
	}
	frame := policy.get_directive_by_name(frame_ancestors) or { panic('frame') }
	assert frame.navigation_response_check(response, NavigableContext{
		ancestor_origins: [
			origin,
		]
	}, .response, policy) == .allowed
	foreign := url.Origin.tuple('https', url.Host.from_string('foreign.test'), none, none)
	assert frame.navigation_response_check(response, NavigableContext{
		ancestor_origins: [
			foreign,
		]
	}, .response, policy) == .blocked
	webrtc_directive := policy.get_directive_by_name(webrtc) or { panic('webrtc') }
	assert webrtc_directive.webrtc_pre_connect_check() == .allowed
}
