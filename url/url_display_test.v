module url

fn test_serialize_for_display_omits_credentials() {
	u := URL{
		scheme:   'https'
		username: 'user'
		password: 'pass'
		host:     Host.from_string('example.com')
		port:     u16(8080)
		paths:    ['a']
		query:    'q'
		fragment: 'f'
	}
	// serialize includes credentials; serialize_for_display drops them.
	assert u.serialize(false) == 'https://user:pass@example.com:8080/a?q#f'
	assert u.serialize_for_display() == 'https://example.com:8080/a?q#f'
}

fn test_serialize_for_display_opaque_path() {
	mailto := URL{
		scheme:             'mailto'
		paths:              ['user@example.com']
		has_an_opaque_path: true
	}
	assert mailto.serialize_for_display() == 'mailto:user@example.com'
}

fn test_serialize_for_display_hostless_guard() {
	u := URL{
		scheme: 'foo'
		paths:  ['', 'bar']
	}
	assert u.serialize_for_display() == 'foo:/.//bar'
}

fn test_path_segments_are_percent_decoded() {
	u := URL{
		scheme: 'https'
		host:   Host.from_string('example.com')
		paths:  ['foo', 'bar%20baz']
	}
	assert u.path_segment_count() == 2
	assert u.path_segment_at_index(0) == 'foo'
	assert u.path_segment_at_index(1) == 'bar baz'
	assert u.basename() == 'bar baz'
}

fn test_basename_empty_path() {
	u := URL{
		scheme:             'data'
		paths:              []
		has_an_opaque_path: false
	}
	assert u.basename() == ''
}

fn test_url_equals() {
	a := URL{
		scheme:   'https'
		host:     Host.from_string('example.com')
		paths:    ['']
		fragment: 'one'
	}
	b := URL{
		scheme:   'https'
		host:     Host.from_string('example.com')
		paths:    ['']
		fragment: 'two'
	}
	// Different fragments: unequal unless the fragment is excluded.
	assert !a.equals(b, false)
	assert a.equals(b, true)
	// Identical URLs are equal either way.
	assert a.equals(a, false)
}
