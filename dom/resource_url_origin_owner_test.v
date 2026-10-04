module dom

import url as liburl

fn test_source_cached_resource_url_has_the_shared_empty_host_tuple_origin() {
	cached := dom_url_parse('../workers/start.js', URL{'resource://browser:8123/pages/start.html'},
		'UTF-8')?
	assert cached.serialize() == 'resource://browser:8123/workers/start.js'
	record := cached.parsed()?
	assert record.scheme == 'resource'
	assert record.host?.serialize() == 'browser'
	assert record.port? == 8123
	actual := cached.origin()
	assert !actual.is_opaque()
	assert !actual.is_opaque_file_origin()
	assert actual.serialize() == 'resource://'
	typed := actual.liburl_origin()?
	if typed is liburl.OriginTuple {
		assert typed.scheme? == 'resource'
		assert typed.host.serialize() == ''
		assert typed.port == none
		assert typed.domain == none
	} else {
		assert false
	}
	assert actual.is_same_origin(URL{'resource://other-host:9443/different/path'}.origin())
	assert actual.is_same_origin(cached.origin())
}

fn test_source_resource_origin_does_not_change_default_file_data_or_https_origins() {
	first := URL{'file:///tmp/resource-origin-control-a'}.origin()
	second := URL{'file:///tmp/resource-origin-control-b'}.origin()
	assert first.is_opaque_file_origin()
	assert second.is_opaque_file_origin()
	assert !first.is_same_origin(second)
	data := URL{'data:text/plain,resource-control'}.origin()
	assert data.is_opaque()
	assert !data.is_opaque_file_origin()
	secure := URL{'https://resource-control.test:8443/page'}.origin()
	assert secure.serialize() == 'https://resource-control.test:8443'
	assert !secure.is_same_origin(URL{'https://other-resource-control.test:8443/page'}.origin())
	assert !secure.is_same_origin(URL{'https://resource-control.test:9443/page'}.origin())
}
