module main

import browserjs
import dom
import httpcookie
import url as cookie_url

@[heap]
struct CompactDocumentCookieTestClient {
mut:
	cookie      string = 'language=en'
	last_cookie ?httpcookie.ParsedCookie
}

fn compact_document_cookie_test_get(target voidptr, _ &cookie_url.URL, source httpcookie.Source) httpcookie.VersionedCookie {
	assert source == .non_http
	client := unsafe { &CompactDocumentCookieTestClient(target) }
	return httpcookie.VersionedCookie{
		cookie: client.cookie
	}
}

fn compact_document_cookie_test_set(target voidptr, _ &cookie_url.URL, cookie httpcookie.ParsedCookie, source httpcookie.Source) {
	assert source == .non_http
	mut client := unsafe { &CompactDocumentCookieTestClient(target) }
	client.last_cookie = cookie
}

fn test_compact_location_uses_native_url_components_and_captured_parser_for_navigation() {
	$if !darwin { return }
	address := 'https://user:pass@example.test:8443/portal/index.html?uselang=en#de'
	document := parse_browser_navigation_document('<!doctype html><p>portal</p>', dom.URL{
		value: address
	}, none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	destination := run_document_javascript(document, address, [
		r'
 globalThis.components=[location.protocol,location.host,location.hostname,location.port,location.pathname,location.search,location.hash,location.origin,String(location)];
 globalThis.URL=function(){throw new Error("author URL constructor")};location.hash="next value";
 ',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('JSON.stringify(components)')! == '["https:","example.test:8443","example.test","8443","/portal/index.html","?uselang=en","#de","https://example.test:8443","${address}"]'
	assert destination or { '' } == 'https://user:pass@example.test:8443/portal/index.html?uselang=en#next%20value'
}

fn test_compact_document_cookie_reads_live_native_owner_and_uses_native_write_parser() {
	$if !darwin { return }
	address := 'https://example.test/account/page'
	mut document := parse_browser_navigation_document('<!doctype html><p>portal</p>', dom.URL{
		value: address
	}, none)
	mut client := &CompactDocumentCookieTestClient{}
	document.set_cookie_client_hook(dom.DocumentCookieClientHook{
		target:         client
		request_cookie: compact_document_cookie_test_get
		set_cookie:     compact_document_cookie_test_set
	})
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, address, [
		r'
 globalThis.languageCookie=document.cookie.match(/language=([^;]+)/)[1];globalThis.cookieConversions=0;
 document.cookie={toString(){cookieConversions++;return "session=value; Path=/account; Secure; SameSite=Lax"}};
 ',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('languageCookie+":"+cookieConversions')! == 'en:1'
	parsed := client.last_cookie or { panic('missing native cookie write') }
	assert parsed.name == 'session'
	assert parsed.value == 'value'
	assert parsed.path or { '' } == '/account'
	assert parsed.secure_attribute_present
	assert parsed.same_site_attribute == .lax
	client.cookie = 'language=fr'
	assert runtime.evaluate_host('document.cookie')! == 'language=fr'
}

fn test_compact_document_cookie_keeps_cookie_averse_documents_empty() {
	$if !darwin { return }
	document := parse_browser_navigation_document('<!doctype html>', dom.url_about_blank(), none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'document.cookie="session=value";globalThis.averseCookie=document.cookie;',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('averseCookie')! == ''
}

fn test_compact_document_cookie_preserves_security_error_for_opaque_http_origins() {
	$if !darwin { return }
	address := 'https://opaque-cookie.example.test/'
	mut document := parse_browser_navigation_document('<!doctype html><p>opaque</p>', dom.URL{
		value: address
	}, none)
	document.set_origin(dom.origin_create_opaque())
	assert !document.is_cookie_averse()
	assert document.origin().is_opaque()
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, address, [
		r'
const CookieDOMException=DOMException;
globalThis.DOMException=function(){throw new Error("author DOMException constructor")};
globalThis.opaqueCookieErrors=[];
for(const operation of [()=>document.cookie,()=>{document.cookie="session=value"}]){
 try{operation();throw new Error("opaque cookie access succeeded")}
 catch(error){if(!(error instanceof CookieDOMException)||error.name!=="SecurityError"||error.code!==CookieDOMException.SECURITY_ERR||error.message!=="Document origin is opaque")throw error;opaqueCookieErrors.push(error.name);}
}
',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('opaqueCookieErrors.join(",")')! == 'SecurityError,SecurityError'
}
