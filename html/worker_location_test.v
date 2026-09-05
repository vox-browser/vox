module html

import dom

fn loc(url string) &WorkerLocation {
	scope := WorkerGlobalScope.create(dom.URL{
		value: url
	}, .classic, '', &ScriptingRealm{})
	return scope.location()
}

fn test_location_reflects_the_worker_global_scope_url_live() {
	mut scope := WorkerGlobalScope.create(dom.URL{ value: 'https://example.test/first' },
		.classic, '', &ScriptingRealm{})
	location := scope.location()
	assert location.pathname() == '/first'
	scope.set_url(dom.URL{ value: 'https://example.test/second?q=1' })
	assert location.href() == 'https://example.test/second?q=1'
	assert location.pathname() == '/second'
	assert location.search() == '?q=1'
}

fn test_full_url_components() {
	l := loc('https://user:pass@example.com:8443/a/b?x=1&y=2#frag')
	assert l.href() == 'https://user:pass@example.com:8443/a/b?x=1&y=2#frag'
	assert l.protocol() == 'https:'
	assert l.host() == 'example.com:8443'
	assert l.hostname() == 'example.com'
	assert l.port() == '8443'
	assert l.pathname() == '/a/b'
	assert l.search() == '?x=1&y=2'
	assert l.hash() == '#frag'
	assert l.origin() == 'https://example.com:8443'
}

fn test_no_port_no_query_no_fragment() {
	l := loc('http://example.org/path')
	assert l.host() == 'example.org'
	assert l.hostname() == 'example.org'
	assert l.port() == ''
	assert l.pathname() == '/path'
	assert l.search() == ''
	assert l.hash() == ''
	assert l.origin() == 'http://example.org'
}

fn test_empty_query_and_fragment_are_ignored() {
	l := loc('http://example.org/p?#')
	// An empty query or fragment serializes to the empty string.
	assert l.search() == ''
	assert l.hash() == ''
}

fn test_url_component_accessors_directly() {
	u := dom.URL{
		value: 'https://h.example:81/p?q#f'
	}
	assert u.scheme() == 'https'
	assert u.serialized_host() == 'h.example'
	assert u.port()? == u16(81)
	assert u.serialize_path() == '/p'
	assert u.query()? == 'q'
	assert u.fragment()? == 'f'
}
