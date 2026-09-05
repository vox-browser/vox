module url

fn https_origin(host string, port ?u16) Origin {
	return Origin.tuple('https', Host.from_string(host), port, none)
}

fn test_serialize_tuple_origin() {
	assert https_origin('example.com', u16(8080)).serialize() == 'https://example.com:8080'
	assert https_origin('example.com', none).serialize() == 'https://example.com'
	// The host is serialized (IPv6 bracketed).
	ipv6 := Origin.tuple('https', Host.ipv6([u16(0), 0, 0, 0, 0, 0, 0, 1]), u16(443), none)
	assert ipv6.serialize() == 'https://[::1]:443'
}

fn test_serialize_opaque_origin() {
	assert Origin.opaque([16]u8{}, .standard).serialize() == 'null'
	assert Origin.opaque([16]u8{}, .file).serialize() == 'null'
}

fn test_is_opaque_and_file_origin() {
	standard := Origin.opaque([16]u8{}, .standard)
	assert standard.is_opaque()
	assert !standard.is_opaque_file_origin()

	file := Origin.opaque([16]u8{}, .file)
	assert file.is_opaque()
	assert file.is_opaque_file_origin()

	tuple := https_origin('example.com', none)
	assert !tuple.is_opaque()
	assert !tuple.is_opaque_file_origin()
}

fn test_is_same_origin() {
	a := https_origin('example.com', u16(443))
	assert a.is_same_origin(https_origin('example.com', u16(443)))
	// Differing scheme/host/port are not same-origin.
	assert !a.is_same_origin(https_origin('example.com', u16(8080)))
	assert !a.is_same_origin(https_origin('other.com', u16(443)))
	assert !a.is_same_origin(Origin.tuple('http', Host.from_string('example.com'), u16(443), none))
	// A tuple and an opaque origin are never same-origin.
	assert !a.is_same_origin(Origin.opaque([16]u8{}, .standard))
}

fn test_is_same_origin_opaque() {
	mut nonce1 := [16]u8{}
	nonce1[0] = 1
	mut nonce2 := [16]u8{}
	nonce2[0] = 2
	first := Origin.opaque(nonce1, .standard)
	// The same opaque origin (equal nonce) is same-origin; a different nonce is not.
	assert first.is_same_origin(Origin.opaque(nonce1, .standard))
	assert !first.is_same_origin(Origin.opaque(nonce2, .standard))
}

fn test_is_same_origin_domain() {
	// Two tuple origins with the same non-null domain and scheme are same-origin-domain, even with
	// different hosts/ports.
	a := Origin.tuple('https', Host.from_string('a.example.com'), u16(1), 'example.com')
	b := Origin.tuple('https', Host.from_string('b.example.com'), u16(2), 'example.com')
	assert a.is_same_origin_domain(b)
	// Different domains are not same-origin-domain.
	c := Origin.tuple('https', Host.from_string('a.example.com'), u16(1), 'other.com')
	assert !a.is_same_origin_domain(c)
	// Both domains null: falls back to same-origin.
	d := https_origin('example.com', u16(443))
	assert d.is_same_origin_domain(https_origin('example.com', u16(443)))
	assert !d.is_same_origin_domain(https_origin('example.com', u16(8080)))
}

fn test_effective_domain() {
	// A non-null domain is the effective domain.
	with_domain := Origin.tuple('https', Host.from_string('a.example.com'), none, 'example.com')
	assert with_domain.effective_domain()?.serialize() == 'example.com'
	// Otherwise the host is.
	without_domain := https_origin('example.com', none)
	assert without_domain.effective_domain()?.serialize() == 'example.com'
	// An opaque origin has no effective domain.
	assert Origin.opaque([16]u8{}, .standard).effective_domain() == none
}

fn test_create_opaque_uses_fresh_nonce_and_same_site_uses_registrable_domain() {
	first := Origin.create_opaque(.standard)
	second := Origin.create_opaque(.standard)
	assert first.is_same_origin(first)
	assert !first.is_same_origin(second)
	assert !first.is_same_site(second)
	a := Origin.tuple('https', Host.from_string('a.example.co.uk'), none, none)
	b := Origin.tuple('https', Host.from_string('b.example.co.uk'), none, none)
	c := Origin.tuple('http', Host.from_string('b.example.co.uk'), none, none)
	assert a.is_same_site(b)
	assert !a.is_same_site(c)
}

fn test_url_origin_algorithm() {
	assert parse('https://example.test/path')?.origin().serialize() == 'https://example.test'
	assert parse('blob:https://example.test/id')?.origin().serialize() == 'https://example.test'
	assert parse('file:///tmp/a')?.origin().is_opaque_file_origin()
	assert parse('data:text/plain,x')?.origin().is_opaque()
}
