module html

import dom

fn anchor(href string) &dom.Element {
	doc := dom.Document.create(dom.URL{
		value: 'https://base.example/'
	})
	mut a := doc.create_element('a') or { panic('${err}') }
	a.set_attribute_value('href', href)
	return a
}

fn test_getters_decompose_the_href() {
	a := anchor('https://user:pass@example.com:8443/a/b?x=1#h')
	assert hyperlink_protocol(a) == 'https:'
	assert hyperlink_username(a) == 'user'
	assert hyperlink_password(a) == 'pass'
	assert hyperlink_host(a) == 'example.com:8443'
	assert hyperlink_hostname(a) == 'example.com'
	assert hyperlink_port(a) == '8443'
	assert hyperlink_pathname(a) == '/a/b'
	assert hyperlink_search(a) == '?x=1'
	assert hyperlink_hash(a) == '#h'
	assert hyperlink_origin(a) == 'https://example.com:8443'
}

fn test_null_url_getters() {
	doc := dom.Document.create(dom.url_about_blank())
	a := doc.create_element('a') or { panic('${err}') }
	// No href attribute → url is null.
	assert hyperlink_href(a) == ''
	assert hyperlink_protocol(a) == ':'
	assert hyperlink_host(a) == ''
	assert hyperlink_search(a) == ''
	assert hyperlink_hash(a) == ''
}

fn test_href_getter_falls_back_to_attribute_when_unparseable() {
	// A value the URL parser rejects: href getter returns the raw attribute value.
	a := anchor('http://[:::')
	assert hyperlink_href(a) == 'http://[:::'
}

fn test_set_protocol_updates_href() {
	mut a := anchor('https://example.com/p')
	set_hyperlink_protocol(mut a, 'http')
	assert hyperlink_protocol(a) == 'http:'
	assert hyperlink_hostname(a) == 'example.com'
}

fn test_set_hostname_and_port() {
	mut a := anchor('https://example.com:8443/p')
	set_hyperlink_hostname(mut a, 'other.example')
	assert hyperlink_hostname(a) == 'other.example'
	// The port is preserved when only the hostname changes.
	assert hyperlink_port(a) == '8443'
	set_hyperlink_port(mut a, '9000')
	assert hyperlink_port(a) == '9000'
	// An empty port clears it.
	set_hyperlink_port(mut a, '')
	assert hyperlink_port(a) == ''
}

fn test_set_search_and_hash() {
	mut a := anchor('https://example.com/p')
	set_hyperlink_search(mut a, 'y=2')
	assert hyperlink_search(a) == '?y=2'
	// A leading "?" is stripped before parsing.
	set_hyperlink_search(mut a, '?z=3')
	assert hyperlink_search(a) == '?z=3'
	// Empty clears the query.
	set_hyperlink_search(mut a, '')
	assert hyperlink_search(a) == ''

	set_hyperlink_hash(mut a, 'frag')
	assert hyperlink_hash(a) == '#frag'
	set_hyperlink_hash(mut a, '#other')
	assert hyperlink_hash(a) == '#other'
	set_hyperlink_hash(mut a, '')
	assert hyperlink_hash(a) == ''
}

fn test_set_username_password() {
	mut a := anchor('https://example.com/p')
	set_hyperlink_username(mut a, 'alice')
	assert hyperlink_username(a) == 'alice'
	set_hyperlink_password(mut a, 'secret')
	assert hyperlink_password(a) == 'secret'
}
