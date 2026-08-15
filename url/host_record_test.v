module url

fn test_host_is_domain_and_empty() {
	domain := Host.from_string('example.com')
	assert domain.is_domain()
	assert !domain.is_empty_host()

	empty := Host.from_string('')
	assert !empty.is_domain()
	assert empty.is_empty_host()

	// An IP host is neither a domain nor an empty host.
	ipv4 := Host.ipv4(0)
	assert !ipv4.is_domain()
	assert !ipv4.is_empty_host()
}

fn test_host_serialize_string() {
	assert Host.from_string('example.com').serialize() == 'example.com'
	// An opaque host is serialized verbatim.
	assert Host.from_string('opaque%20host').serialize() == 'opaque%20host'
	// The empty host serializes to the empty string.
	assert Host.from_string('').serialize() == ''
}

fn test_host_serialize_ipv4() {
	assert Host.ipv4(u32(3232235521)).serialize() == '192.168.0.1' // 0xC0A80001
	assert Host.ipv4(0).serialize() == '0.0.0.0'
}

fn test_host_serialize_ipv6_is_bracketed() {
	assert Host.ipv6([u16(0), 0, 0, 0, 0, 0, 0, 1]).serialize() == '[::1]'
	assert Host.ipv6([u16(0x2001), 0x0db8, 0, 0, 0, 0, 0, 1]).serialize() == '[2001:db8::1]'
}

fn test_host_serialize_round_trips_from_parsers() {
	// A host built from the address parsers serializes back to the canonical text.
	ipv4 := Host.ipv4(parse_ipv4_address('192.168.1')?)
	assert ipv4.serialize() == '192.168.0.1'
	ipv6 := Host.ipv6(parse_ipv6_address('2001:0db8:0:0:0:0:0:1')?)
	assert ipv6.serialize() == '[2001:db8::1]'
}
