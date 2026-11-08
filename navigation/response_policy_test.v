module main

import adblock
import dom
import html
import net

fn serve_response_policy(mut listener net.TcpListener) {
	mut socket := listener.accept() or { return }
	defer { socket.close() or {} }
	mut bytes := []u8{len: 4096}
	_ = socket.read(mut bytes) or { return }
	body := '<!doctype html><meta http-equiv="Content-Security-Policy" content="img-src data:"><p>policies</p>'
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Security-Policy: worker-src \'none\'\r\nContent-Security-Policy-Report-Only: script-src \'self\'\r\nReferrer-Policy: no-referrer\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}') or {}
}

fn test_navigation_keeps_http_response_policies_before_parsing_meta_policies() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	server := spawn serve_response_policy(mut listener)
	address := 'http://${listener.addr()!}/page'
	loaded := fetch_page(address, '')!
	assert loaded.response_status == 200
	assert loaded.response_headers.any(it.name.to_lower() == 'content-security-policy' && it.value == "worker-src 'none'")
	prepared := prepare_loaded_browser_navigation_document(loaded, dom.URL{value: address}, none, none, none, true)
	mut document := prepared.document
	defer { document.finalize() }
	assert document.policy_container().csp_list.len == 2
	assert document.policy_container().referrer_policy == .no_referrer
	parse_prepared_browser_navigation_document(prepared)
	container := document.policy_container()
	assert container.csp_list.len == 3
	assert container.csp_list[0].source == .header && container.csp_list[0].disposition == .enforce
	assert container.csp_list[1].source == .header && container.csp_list[1].disposition == .report
	assert container.csp_list[2].source == .meta
	assert container.referrer_policy == .no_referrer
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert !html.worker_constructor_csp_allows(settings, dom.URL{value: 'data:text/javascript,void 0'}, false)
	server.wait()
}

fn test_navigation_without_response_headers_preserves_javascript_url_policy_identity() {
	url := dom.URL{value: 'https://response-policy.test/'}
	mut source := parse_loaded_browser_navigation_document(LoadedPage{url: url.serialize(), markup: '<!doctype html>',
		content_type: 'text/html', response_headers: [adblock.ResponseHeader{name: 'Content-Security-Policy', value: "worker-src 'none'"}]}, url, none, none, none, true)
	defer { source.finalize() }
	mut replacement := parse_loaded_browser_navigation_document(LoadedPage{url: url.serialize(), markup: '<!doctype html><p>replacement</p>', content_type: 'text/html', javascript_url_source: source}, url, source.origin(), source, none, true)
	defer { replacement.finalize() }
	assert replacement.policy_container().csp_list.len == 1
	assert replacement.policy_container().csp_list[0].directives[0].name == 'worker-src'
}
