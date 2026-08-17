module url

fn test_serialize_full_url() {
	u := URL{
		scheme:   'https'
		username: 'user'
		password: 'pass'
		host:     Host.from_string('example.com')
		port:     u16(8080)
		paths:    ['path', 'to']
		query:    'a=b'
		fragment: 'frag'
	}
	assert u.serialize(false) == 'https://user:pass@example.com:8080/path/to?a=b#frag'
}

fn test_serialize_minimal_url() {
	u := URL{
		scheme: 'https'
		host:   Host.from_string('example.com')
		paths:  ['foo']
	}
	assert u.serialize(false) == 'https://example.com/foo'
}

fn test_serialize_username_without_password() {
	u := URL{
		scheme:   'https'
		username: 'user'
		host:     Host.from_string('example.com')
		paths:    ['']
	}
	// A username alone still includes credentials, but with no ":password".
	assert u.serialize(false) == 'https://user@example.com/'
}

fn test_serialize_exclude_fragment() {
	u := URL{
		scheme:   'https'
		host:     Host.from_string('example.com')
		paths:    ['']
		fragment: 'section'
	}
	assert u.serialize(false) == 'https://example.com/#section'
	assert u.serialize(true) == 'https://example.com/'
}

fn test_serialize_opaque_path() {
	// mailto:/data: URLs have an opaque path (no host).
	mailto := URL{
		scheme:             'mailto'
		paths:              ['user@example.com']
		has_an_opaque_path: true
	}
	assert mailto.serialize(false) == 'mailto:user@example.com'
	data := URL{
		scheme:             'data'
		paths:              ['text/plain,hello']
		has_an_opaque_path: true
	}
	assert data.serialize(false) == 'data:text/plain,hello'
}

fn test_serialize_ip_hosts() {
	ipv4 := URL{
		scheme: 'https'
		host:   Host.ipv4(u32(3232235521)) // 192.168.0.1
		paths:  ['']
	}
	assert ipv4.serialize(false) == 'https://192.168.0.1/'
	ipv6 := URL{
		scheme: 'https'
		host:   Host.ipv6([u16(0), 0, 0, 0, 0, 0, 0, 1])
		paths:  ['']
	}
	assert ipv6.serialize(false) == 'https://[::1]/'
}

fn test_serialize_empty_query_and_fragment() {
	// An empty (but non-null) query/fragment still adds the "?"/"#".
	u := URL{
		scheme:   'https'
		host:     Host.from_string('example.com')
		paths:    ['']
		query:    ''
		fragment: ''
	}
	assert u.serialize(false) == 'https://example.com/?#'
}

fn test_serialize_hostless_path_guard() {
	// No host, non-opaque path whose first segment is empty: a "/." is inserted so "//bar" is not read
	// as an authority.
	u := URL{
		scheme: 'foo'
		paths:  ['', 'bar']
	}
	assert u.serialize(false) == 'foo:/.//bar'
}

fn test_includes_credentials() {
	assert URL{
		username: 'u'
	}.includes_credentials()
	assert URL{
		password: 'p'
	}.includes_credentials()
	assert !URL{}.includes_credentials()
}
