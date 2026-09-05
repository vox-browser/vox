module httpcookie

import url

fn cookie_test_url(input string) url.URL {
	return url.parse(input) or { panic(err) }
}

fn test_parse_cookie_translates_name_value_and_attributes() {
	record := cookie_test_url('https://www.example.com/account/page')
	parsed := parse_cookie(&record, ' session = value ; Expires=Wed, 09 Jun 2027 10:18:14 GMT; Max-Age=60; Domain=.EXAMPLE.com; Path=/account; Secure; HttpOnly; SameSite=Lax') or {
		panic('cookie should parse')
	}
	assert parsed.name == 'session'
	assert parsed.value == 'value'
	assert parsed.domain? == 'example.com'
	assert parsed.path? == '/account'
	assert parsed.secure_attribute_present
	assert parsed.http_only_attribute_present
	assert parsed.same_site_attribute == .lax
	assert parsed.expiry_time_from_expires_attribute != none
	assert parsed.expiry_time_from_max_age_attribute != none
}

fn test_parse_cookie_matches_upstream_rejection_and_default_path_rules() {
	record := cookie_test_url('https://example.com/account/page')
	assert parse_cookie(&record, 'bad\x01=value') == none
	assert parse_cookie(&record, '${'x'.repeat(4097)}=') == none
	assert parse_cookie(&record, 'a=b; Domain=bücher.example') == none
	parsed := parse_cookie(&record, 'a=b; Path=relative; SameSite=unknown') or { panic('cookie') }
	assert parsed.path? == '/account'
	assert parsed.same_site_attribute == .default_
	assert canonicalize_domain(&record)? == 'example.com'
}
