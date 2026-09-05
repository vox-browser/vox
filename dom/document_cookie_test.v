module dom

import httpcookie
import url as liburl

@[heap]
struct DocumentCookieTestClient {
mut:
	version                u64 = 1
	cookie                 string
	request_count          int
	set_count              int
	version_index_requests int
	last_domain            string
	last_parsed            ?httpcookie.ParsedCookie
}

fn document_cookie_test_request_version(target voidptr, _ int) ?u64 {
	client := unsafe { &DocumentCookieTestClient(target) }
	return client.version
}

fn document_cookie_test_request(target voidptr, _ &liburl.URL, source httpcookie.Source) httpcookie.VersionedCookie {
	assert source == .non_http
	mut client := unsafe { &DocumentCookieTestClient(target) }
	client.request_count++
	return httpcookie.VersionedCookie{
		cookie_version: client.version
		cookie: client.cookie
	}
}

fn document_cookie_test_set(target voidptr, _ &liburl.URL, parsed httpcookie.ParsedCookie, source httpcookie.Source) {
	assert source == .non_http
	mut client := unsafe { &DocumentCookieTestClient(target) }
	client.set_count++
	client.last_parsed = parsed
}

fn document_cookie_test_request_index(target voidptr, _ UniqueNodeID, domain string) {
	mut client := unsafe { &DocumentCookieTestClient(target) }
	client.version_index_requests++
	client.last_domain = domain
}

fn test_document_cookie_uses_translated_parser_and_page_client_version_cache() {
	mut document := Document.create(URL{ value: 'https://www.example.test/account/page' })
	document.set_origin(document.url.origin())
	document.set_browsing_context(&BrowsingContext{
		active_document_: document
	})
	mut client := &DocumentCookieTestClient{
		cookie: 'a=1; b=2'
	}
	document.set_cookie_client_hook(DocumentCookieClientHook{
		target: voidptr(client)
		request_document_version: document_cookie_test_request_version
		request_cookie: document_cookie_test_request
		set_cookie: document_cookie_test_set
		request_document_version_index: document_cookie_test_request_index
	})

	document.ensure_cookie_version_index(document.url)
	assert client.version_index_requests == 1
	assert client.last_domain == 'www.example.test'
	document.set_cookie_version_index(7)
	assert document.cookie()! == 'a=1; b=2'
	assert client.request_count == 1
	assert document.cookie()! == 'a=1; b=2'
	assert client.request_count == 1

	client.version = 2
	client.cookie = 'a=updated'
	assert document.cookie()! == 'a=updated'
	assert client.request_count == 2

	document.set_cookie(' session = value ; Domain=.EXAMPLE.test; Path=relative; Secure; SameSite=Lax')!
	assert client.set_count == 1
	parsed := client.last_parsed or { panic('missing parsed cookie') }
	assert parsed.name == 'session'
	assert parsed.value == 'value'
	assert parsed.domain? == 'example.test'
	assert parsed.path? == '/account'
	assert parsed.secure_attribute_present
	assert parsed.same_site_attribute == .lax

	document.set_cookie('bad\x01=value')!
	assert client.set_count == 1
}
