module url

fn test_ipv6_full_form() {
	assert parse_ipv6_address('1:2:3:4:5:6:7:8')? == [u16(1), 2, 3, 4, 5, 6, 7, 8]
	assert parse_ipv6_address('2001:db8:0:0:0:0:0:1')? == [u16(0x2001), 0x0db8, 0, 0, 0, 0, 0, 1]
}

fn test_ipv6_compression() {
	assert parse_ipv6_address('::')? == [u16(0), 0, 0, 0, 0, 0, 0, 0]
	assert parse_ipv6_address('::1')? == [u16(0), 0, 0, 0, 0, 0, 0, 1]
	assert parse_ipv6_address('fe80::')? == [u16(0xfe80), 0, 0, 0, 0, 0, 0, 0]
	assert parse_ipv6_address('2001:db8::1')? == [u16(0x2001), 0x0db8, 0, 0, 0, 0, 0, 1]
	// Compression in the middle.
	assert parse_ipv6_address('1::8')? == [u16(1), 0, 0, 0, 0, 0, 0, 8]
}

fn test_ipv6_is_case_insensitive() {
	assert parse_ipv6_address('FE80::')? == parse_ipv6_address('fe80::')?
	assert parse_ipv6_address('2001:DB8::AB')? == [u16(0x2001), 0x0db8, 0, 0, 0, 0, 0, 0x00ab]
}

fn test_ipv6_with_embedded_ipv4() {
	// The IPv4 tail fills the last two pieces.
	assert parse_ipv6_address('::ffff:192.168.0.1')? == [u16(0), 0, 0, 0, 0, 0xffff, 0xc0a8, 0x0001]
	assert parse_ipv6_address('::1.2.3.4')? == [u16(0), 0, 0, 0, 0, 0, 0x0102, 0x0304]
}

fn test_ipv6_failures() {
	assert parse_ipv6_address('1:2:3:4:5:6:7:8:9') == none // too many pieces
	assert parse_ipv6_address('1:2:3') == none // too few, no compression
	assert parse_ipv6_address('1::2::3') == none // multiple compressions
	assert parse_ipv6_address('gg::') == none // invalid hex
	assert parse_ipv6_address('12345::') == none // more than four hex digits in a piece
	assert parse_ipv6_address('1:2:3:4:5:6:7:') == none // trailing single colon
	assert parse_ipv6_address(':1:2') == none // a single leading colon
}

fn test_ipv6_embedded_ipv4_failures() {
	assert parse_ipv6_address('::192.168.0.256') == none // octet out of range
	assert parse_ipv6_address('::192.168.0') == none // too few octets
	assert parse_ipv6_address('::192.168.00.1') == none // leading zero in an octet
	assert parse_ipv6_address('1:2:3:4:5:6:7:1.2.3.4') == none // no room for the IPv4 tail
}

fn test_serialize_ipv6_address() {
	assert serialize_ipv6_address([u16(1), 2, 3, 4, 5, 6, 7, 8]) == '1:2:3:4:5:6:7:8'
	assert serialize_ipv6_address([u16(0), 0, 0, 0, 0, 0, 0, 0]) == '::'
	assert serialize_ipv6_address([u16(0), 0, 0, 0, 0, 0, 0, 1]) == '::1'
	assert serialize_ipv6_address([u16(0xfe80), 0, 0, 0, 0, 0, 0, 0]) == 'fe80::'
	assert serialize_ipv6_address([u16(0x2001), 0x0db8, 0, 0, 0, 0, 0, 1]) == '2001:db8::1'
	// An embedded IPv4 tail serializes as hex pieces, not a dotted quad.
	assert serialize_ipv6_address([u16(0), 0, 0, 0, 0, 0xffff, 0xc0a8, 1]) == '::ffff:c0a8:1'
}

fn test_serialize_ipv6_compresses_longest_zero_run() {
	// Two zero runs: only the longer one (indices 4-6) is compressed.
	assert serialize_ipv6_address([u16(1), 0, 0, 1, 0, 0, 0, 1]) == '1:0:0:1::1'
	// A single zero is not compressed (a run must be longer than one piece).
	assert serialize_ipv6_address([u16(1), 0, 1, 1, 1, 1, 1, 1]) == '1:0:1:1:1:1:1:1'
}

fn test_ipv6_round_trips() {
	// Parsing then serializing yields the canonical compressed form.
	for canonical in ['::', '::1', '2001:db8::1', 'fe80::', '1:2:3:4:5:6:7:8', '1:0:0:1::1'] {
		assert serialize_ipv6_address(parse_ipv6_address(canonical)?) == canonical
	}
	// A non-canonical input normalizes.
	assert serialize_ipv6_address(parse_ipv6_address('2001:0db8:0:0:0:0:0:0001')?) == '2001:db8::1'
}
