@[has_globals]
module loader

import dom
import fetch
import http
import referrerpolicy

fn ignore_file_result(_ FileDescriptorResult) {}

fn test_proxy_mappings_use_ordered_wildcards_and_skip_invalid_proxies() {
	mut mappings := ProxyMappings.create()
	mappings.set_mappings(['not-a-proxy', 'http://alice:secret@proxy.test:8080',
		'socks5://socks.test'], [
		ProxyMapping{'https://skip.example/*', 0},
		ProxyMapping{'https://*.example/*', 1},
		ProxyMapping{'*', 2},
	])
	proxy := mappings.proxy_for_url(dom.URL{'https://www.example/path'}) or {
		panic('expected HTTP proxy')
	}
	assert proxy.type_ == .http
	assert proxy.host == 'proxy.test'
	assert proxy.port == 8080
	assert proxy.username == 'alice'
	assert proxy.password == 'secret'
	fallback := mappings.proxy_for_url(dom.URL{'http://elsewhere.test/'}) or {
		panic('expected fallback proxy')
	}
	assert fallback.type_ == .socks5
	assert fallback.port == 1080
}

fn test_load_request_defaults_mutators_timer_and_file_request_surface() {
	mut headers := http.HeaderList.create()
	mut request := LoadRequest.create(headers)
	assert request.method() == 'GET'
	assert request.include_credentials()
	assert request.destination() == none
	assert request.request_mode() == .no_cors
	assert request.referrer_policy() == referrerpolicy.default_referrer_policy
	assert !request.is_navigation_request()
	assert request.priority() == .auto
	assert request.source_url() == none
	request.set_url(dom.URL{'https://example.test/'})
	request.set_method('POST')
	request.set_body([u8(1), 2, 3])
	request.set_cache_mode(fetch.CacheMode.no_store)
	request.set_initiator_type(fetch.InitiatorType.fetch)
	request.set_include_credentials(false)
	request.set_destination(fetch.Destination.image)
	request.set_request_mode(.cors)
	request.set_referrer_policy(.no_referrer)
	request.set_is_navigation_request(true)
	request.set_priority(.high)
	request.set_source_url(dom.URL{'https://source.example/path'})
	request.set_page(42)
	assert (request.url() or { panic('missing URL') }).serialize() == 'https://example.test/'
	assert request.method() == 'POST'
	assert request.body() == [u8(1), 2, 3]
	assert request.cache_mode() == .no_store
	assert !request.include_credentials()
	assert (request.initiator_type() or { panic('missing initiator') }) == fetch.InitiatorType.fetch
	assert (request.destination() or { panic('missing destination') }) == fetch.Destination.image
	assert request.request_mode() == .cors
	assert request.referrer_policy() == .no_referrer
	assert request.is_navigation_request()
	assert request.priority() == .high
	assert (request.source_url() or { panic('missing source URL') }).serialize() == 'https://source.example/path'
	assert (request.page() or { panic('missing page') }) == u64(42)
	assert request.headers() == headers
	request.start_timer()
	assert request.load_time() >= 0
	file_request := FileRequest.create('/tmp/example', ignore_file_result)
	assert file_request.path() == '/tmp/example'
}

fn test_loader_singletons_are_stable() {
	assert ContentBlocker.the() == ContentBlocker.the()
	assert ProxyMappings.the() == ProxyMappings.the()
}

fn test_user_agent_and_platform_match_upstream_tokens() {
	assert default_user_agent().starts_with('Mozilla/5.0 (')
	assert default_user_agent().contains('Ladybird/1.0')
	assert default_user_agent().ends_with(compatibility_token)
	assert default_platform() == '${os_string()} ${cpu_string()}'
	assert default_navigator_compatibility_mode == .chrome
}

fn test_host_user_agent_tokens_are_not_unknown() {
	assert cpu_string() != 'Unknown'
	assert os_string() != 'Unknown'
}
