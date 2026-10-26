module browsercookies

import httpcookie
import platform
import url

fn put(mut jar Jar, address string, value string, source httpcookie.Source) {
	record := url.parse(address) or { panic(address) }
	parsed := httpcookie.parse_cookie(&record, value) or { panic(value) }
	jar.set_cookie_at(&record, parsed, source, Context{}, 1000)
}

fn read(mut jar Jar, address string, source httpcookie.Source, context Context) string {
	record := url.parse(address) or { panic(address) }
	return jar.cookie_string_at(&record, source, context, 1000)
}

fn test_document_and_http_share_session_without_exposing_http_only() {
	mut jar := &Jar{}
	put(mut jar, 'https://maps.example.test/maps/page', 'session=server; HttpOnly; Path=/', .http)
	put(mut jar, 'https://maps.example.test/maps/page', 'language=ru', .non_http)
	assert read(mut jar, 'https://maps.example.test/maps/data', .http, Context{}) == 'language=ru; session=server'
	assert read(mut jar, 'https://maps.example.test/maps/data', .non_http, Context{}) == 'language=ru'
	put(mut jar, 'https://maps.example.test/', 'session=script; Path=/', .non_http)
	put(mut jar, 'https://maps.example.test/', 'session=; Path=/; Max-Age=0', .non_http)
	put(mut jar, 'https://maps.example.test/', 'hidden=script; HttpOnly', .non_http)
	assert read(mut jar, 'https://maps.example.test/', .http, Context{}) == 'session=server'
}

fn test_host_domain_and_path_boundaries() {
	mut jar := &Jar{}
	put(mut jar, 'https://maps.example.com/maps/page', 'host=1', .http)
	put(mut jar, 'https://maps.example.com/maps/page', 'domain=2; Domain=.EXAMPLE.com; Path=/', .http)
	put(mut jar, 'https://maps.example.com/maps/page', 'wrong=3; Domain=other.com', .http)
	put(mut jar, 'https://maps.example.com/maps/page', 'suffix=4; Domain=com', .http)
	put(mut jar, 'https://maps.example.com/maps/page', 'uk=5; Domain=co.uk', .http)
	assert read(mut jar, 'https://maps.example.com/maps/next', .http, Context{}) == 'host=1; domain=2'
	assert read(mut jar, 'https://maps.example.com/mapstuff', .http, Context{}) == 'domain=2'
	assert read(mut jar, 'https://sub.maps.example.com/maps/page', .http, Context{}) == 'domain=2'
	assert read(mut jar, 'https://notexample.com/maps/page', .http, Context{}) == ''
	assert read(mut jar, 'https://example.com/', .http, Context{}) == 'domain=2'
}

fn test_public_suffix_exact_host_and_ip_are_host_scoped() {
	mut jar := &Jar{}
	put(mut jar, 'https://co.uk/', 'suffix=1; Domain=co.uk', .http)
	put(mut jar, 'http://127.0.0.1/', 'ip=1; Domain=0.0.1', .http)
	put(mut jar, 'http://127.0.0.1/', 'exact=2; Domain=127.0.0.1', .http)
	assert read(mut jar, 'https://co.uk/', .http, Context{}) == 'suffix=1'
	assert read(mut jar, 'https://example.co.uk/', .http, Context{}) == ''
	assert read(mut jar, 'http://127.0.0.1/', .http, Context{}) == 'exact=2'
}

fn test_replacement_preserves_order_and_deletion_uses_complete_key() {
	mut jar := &Jar{}
	put(mut jar, 'https://example.com/', 'a=1; Path=/', .http)
	put(mut jar, 'https://example.com/', 'b=2; Path=/', .http)
	put(mut jar, 'https://example.com/', 'a=3; Path=/', .http)
	put(mut jar, 'https://example.com/', 'a=4; Path=/maps', .http)
	assert read(mut jar, 'https://example.com/maps/', .http, Context{}) == 'a=4; a=3; b=2'
	put(mut jar, 'https://example.com/', 'a=; Path=/; Max-Age=0', .http)
	assert read(mut jar, 'https://example.com/maps/', .http, Context{}) == 'a=4; b=2'
}

fn test_expiry_and_max_age_precedence() {
	mut jar := &Jar{}
	record := url.parse('https://example.com/') or { panic('url') }
	jar.set_cookie_at(&record, httpcookie.ParsedCookie{name: 'short', value: '1', expiry_time_from_expires_attribute: 1005}, .http, Context{}, 1000)
	jar.set_cookie_at(&record, httpcookie.ParsedCookie{name: 'max', value: '2', expiry_time_from_expires_attribute: 999, expiry_time_from_max_age_attribute: 1010}, .http, Context{}, 1000)
	assert jar.cookie_string_at(&record, .http, Context{}, 1004) == 'short=1; max=2'
	assert jar.cookie_string_at(&record, .http, Context{}, 1005) == 'max=2'
	assert jar.cookie_string_at(&record, .http, Context{}, 1010) == ''
}

fn test_secure_cookies_cannot_be_set_or_overlaid_from_http() {
	mut jar := &Jar{}
	put(mut jar, 'http://example.com/', 'invalid=1; Secure', .http)
	put(mut jar, 'https://example.com/login', 'session=secure; Secure; Path=/login', .http)
	put(mut jar, 'http://example.com/login', 'session=plain; Path=/login', .http)
	put(mut jar, 'http://example.com/login', 'session=; Path=/login; Max-Age=0', .non_http)
	assert read(mut jar, 'http://example.com/login', .http, Context{}) == ''
	assert read(mut jar, 'https://example.com/login', .http, Context{}) == 'session=secure'
}

fn test_secure_and_host_prefix_requirements_are_case_insensitive() {
	mut jar := &Jar{}
	for invalid in ['__Secure-no=1', '__Host-no=2; Secure', '__Host-domain=3; Secure; Path=/; Domain=example.com', '__Host-path=4; Secure; Path=/maps', '__secure-value', '__HOST-value'] {
		put(mut jar, 'https://example.com/', invalid, .http)
	}
	put(mut jar, 'https://example.com/', '__Secure-yes=1; Secure', .http)
	put(mut jar, 'https://example.com/', '__Host-yes=2; Secure; Path=/', .http)
	assert read(mut jar, 'https://example.com/', .http, Context{}) == '__Secure-yes=1; __Host-yes=2'
}

fn test_same_site_retrieval_distinguishes_navigation_and_subresources() {
	mut jar := &Jar{}
	for value in ['default=1', 'strict=2; SameSite=Strict', 'lax=3; SameSite=Lax', 'none=4; SameSite=None; Secure', 'insecure=5; SameSite=None'] {
		put(mut jar, 'https://example.com/', value, .http)
	}
	assert read(mut jar, 'https://example.com/', .http, Context{}) == 'default=1; strict=2; lax=3; none=4'
	assert read(mut jar, 'https://example.com/', .http, Context{same_site: false}) == 'none=4'
	assert read(mut jar, 'https://example.com/', .http, Context{same_site: false, top_level: true}) == 'default=1; lax=3; none=4'
	assert read(mut jar, 'https://example.com/', .http, Context{same_site: false, top_level: true, safe_method: false}) == 'none=4'
}

fn test_cross_site_responses_cannot_set_lax_or_strict_subresource_cookies() {
	mut jar := &Jar{}
	record := url.parse('https://example.com/') or { panic('url') }
	for value in ['strict=1; SameSite=Strict', 'default=2', 'none=3; SameSite=None; Secure'] {
		parsed := httpcookie.parse_cookie(&record, value) or { panic(value) }
		jar.set_cookie_at(&record, parsed, .http, Context{same_site: false}, 1000)
	}
	assert read(mut jar, 'https://example.com/', .http, Context{}) == 'none=3'
}

fn test_request_context_uses_schemeful_site_and_safe_method() {
	record := url.parse('https://maps.example.com/data') or { panic('url') }
	assert request_context(&record, 'https://www.example.com/', false, 'GET').same_site
	assert !request_context(&record, 'http://maps.example.com/', false, 'GET').same_site
	assert !request_context(&record, 'https://other.com/', false, 'GET').same_site
	assert !request_context(&record, 'https://example.com/', true, 'POST').safe_method
}

fn test_retained_cookies_outlive_the_document_scratch_arena() {
	mut jar := &Jar{}
	mut scratch := platform.begin_thread_scratch('cookie input')
	put(mut jar, 'https://example.com/maps/page', 'language=ru; Path=/maps', .non_http)
	scratch.finish()
	assert read(mut jar, 'https://example.com/maps/data', .http, Context{}) == 'language=ru'
}
