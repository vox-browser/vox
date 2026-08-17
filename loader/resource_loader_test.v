@[has_globals]
module loader

import dom
import http
import os

fn header_value(headers []http.Header, name string) ?string {
	for header in headers {
		if header.name.to_lower() == name.to_lower() {
			return header.value
		}
	}
	return none
}

fn load_request_for(value string) &LoadRequest {
	mut request := LoadRequest.create(http.HeaderList.create())
	request.url = dom.URL{value}
	return request
}

fn test_resource_loader_initialization_and_configuration() {
	mut resource_loader := initialize()
	assert is_initialized()
	assert the() == resource_loader
	assert resource_loader.user_agent == default_user_agent()
	assert resource_loader.platform == default_platform()
	assert resource_loader.preferred_languages == ['en-US']
	resource_loader.set_preferred_languages(['fr', 'en']) or { panic(err) }
	assert resource_loader.preferred_languages == ['fr', 'en']
	mut rejected_empty := false
	resource_loader.set_preferred_languages([]) or { rejected_empty = true }
	assert rejected_empty
}

fn test_connection_preparation_and_request_blocking() {
	mut resource_loader := ResourceLoader.create()
	assert resource_loader.prepare_connection(dom.URL{'file:///tmp/a'}, true) == .none
	assert resource_loader.prepare_connection(dom.URL{'data:text/plain,a'}, false) == .none
	assert resource_loader.prepare_connection(dom.URL{'https://example.test/'}, false) == .resolve_only
	assert resource_loader.prepare_connection(dom.URL{'https://example.test/'}, true) == .create_connection
	mut filter := resource_loader.content_filter()
	filter.set_patterns(['blocked.test']) or { panic(err) }
	assert resource_loader.prepare_connection(dom.URL{'https://blocked.test/'}, true) == .none
	assert resource_loader.should_block_request(load_request_for('http://example.test:22/'))
	assert resource_loader.should_block_request(load_request_for('https://blocked.test/a'))
	assert !resource_loader.should_block_request(load_request_for('https://example.test/a'))
}

fn test_load_dispatches_about_resource_and_unsupported_protocols() {
	mut resource_loader := ResourceLoader.create()
	mut about_request := load_request_for('about:version')
	about := resource_loader.load(mut about_request)
	assert about.success
	assert about.protocol == 'about'
	assert about.data.bytestr().contains('Ladybird')
	assert (header_value(about.headers, 'content-type') or { panic('missing content type') }) == 'text/html; charset=UTF-8'
	mut encoded_about_request := load_request_for('about:%76ersion')
	encoded_about := resource_loader.load(mut encoded_about_request)
	assert encoded_about.success
	assert encoded_about.data.bytestr().contains('Ladybird')
	resource_loader.register_about_page('custom page', 'custom contents'.bytes())
	mut custom_about_request := load_request_for('about:custom%20page')
	assert resource_loader.load(mut custom_about_request).data.bytestr() == 'custom contents'

	resource_loader.register_resource('resource://ladybird/app.js', StoredResource{
		data:          'let answer = 42;'.bytes()
		content_type:  'text/javascript'
		last_modified: 'Sun, 16 Aug 2026 00:00:00 GMT'
	})
	mut resource_request := load_request_for('resource://ladybird/app.js')
	resource := resource_loader.load(mut resource_request)
	assert resource.success
	assert resource.data.bytestr() == 'let answer = 42;'
	assert (header_value(resource.headers, 'Access-Control-Allow-Origin') or {
		panic('missing CORS header')
	}) == 'null'
	assert (header_value(resource.headers, 'Content-Type') or { panic('missing content type') }) == 'text/javascript'
	assert (header_value(resource.headers, 'Last-Modified') or {
		panic('missing modification time')
	}) == 'Sun, 16 Aug 2026 00:00:00 GMT'

	mut unsupported_request := load_request_for('ftp://example.test/a')
	unsupported := resource_loader.load(mut unsupported_request)
	assert !unsupported.success
	assert (unsupported.error_message or { panic('missing failure message') }) == 'Protocol not implemented: ftp'
}

fn test_load_blocks_filtered_and_bad_port_requests_before_dispatch() {
	mut resource_loader := ResourceLoader.create()
	mut filter := resource_loader.content_filter()
	filter.set_patterns(['blocked.test']) or { panic(err) }
	for value in ['https://blocked.test/a', 'http://example.test:6379/a'] {
		mut request := load_request_for(value)
		result := resource_loader.load(mut request)
		assert !result.success
		assert (result.error_message or { panic('missing block message') }) == 'Request was blocked'
	}
}

fn test_file_load_reads_bytes_and_synthesizes_response_headers() {
	path := os.join_path(os.temp_dir(), 'libweb_v_loader_file_${os.getpid()}.txt')
	os.write_file(path, 'file contents') or { panic(err) }
	defer {
		os.rm(path) or {}
	}
	mut resource_loader := ResourceLoader.create()
	mut request := load_request_for('file://${path}')
	result := resource_loader.load(mut request)
	assert result.success
	assert result.protocol == 'file'
	assert result.data.bytestr() == 'file contents'
	assert (header_value(result.headers, 'Access-Control-Allow-Origin') or {
		panic('missing CORS header')
	}) == 'null'
	assert (header_value(result.headers, 'Content-Type') or { panic('missing content type') }) == 'text/plain'
}

fn test_network_load_applies_proxy_and_finishes_active_counter() {
	mut resource_loader := ResourceLoader.create()
	mut proxies := resource_loader.proxy_mappings()
	proxies.set_mappings(['http://proxy.test:3128'], [ProxyMapping{'https://*', 0}])
	resource_loader.register_network_response('https://example.test/data', NetworkResponse{
		data:          'payload'.bytes()
		headers:       [http.Header{'Content-Type', 'text/plain'}]
		status_code:   206
		reason_phrase: 'Partial Content'
	})
	mut request := load_request_for('https://example.test/data')
	result := resource_loader.load(mut request)
	assert result.success
	assert result.data.bytestr() == 'payload'
	assert (result.status_code or { panic('missing status') }) == 206
	assert (result.reason_phrase or { panic('missing reason phrase') }) == 'Partial Content'
	proxy := result.proxy or { panic('proxy should be selected') }
	assert proxy.host == 'proxy.test'
	assert proxy.port == 3128
	assert resource_loader.pending_loads() == 0

	resource_loader.register_network_response('https://example.test/fail', NetworkResponse{
		error_message: 'connection reset'
	})
	mut failed_request := load_request_for('https://example.test/fail')
	failed := resource_loader.load(mut failed_request)
	assert (failed.error_message or { panic('missing network failure') }) == 'Request finished with error: connection reset'
	assert resource_loader.pending_loads() == 0
}
