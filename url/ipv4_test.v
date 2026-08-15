module url

fn test_parse_ipv4_number_decimal() {
	assert parse_ipv4_number('255')?.number == u32(255)
	assert !parse_ipv4_number('255')?.validation_error
	assert parse_ipv4_number('0')?.number == u32(0)
	assert !parse_ipv4_number('0')?.validation_error
	assert parse_ipv4_number('256')?.number == u32(256)
}

fn test_parse_ipv4_number_hex_and_octal() {
	// Hex and octal prefixes flag a (non-decimal) validation error.
	hex := parse_ipv4_number('0xff')?
	assert hex.number == u32(255)
	assert hex.validation_error
	octal := parse_ipv4_number('0377')?
	assert octal.number == u32(255)
	assert octal.validation_error
	// A prefix with no digits is 0.
	empty_hex := parse_ipv4_number('0x')?
	assert empty_hex.number == u32(0)
	assert empty_hex.validation_error
}

fn test_parse_ipv4_number_failures() {
	assert parse_ipv4_number('') == none
	assert parse_ipv4_number('abc') == none
	assert parse_ipv4_number('08') == none // 8 is not an octal digit
	assert parse_ipv4_number('0xG') == none // G is not a hex digit
	assert parse_ipv4_number('4294967296') == none // overflows u32
}

fn test_parse_ipv4_address_dotted_quad() {
	assert parse_ipv4_address('0.0.0.0')? == u32(0)
	assert parse_ipv4_address('127.0.0.1')? == u32(2130706433) // 0x7F000001
	assert parse_ipv4_address('192.168.0.1')? == u32(3232235521) // 0xC0A80001
	assert parse_ipv4_address('255.255.255.255')? == u32(4294967295) // 0xFFFFFFFF
	assert parse_ipv4_address('1.2.3.4')? == u32(0x01020304)
}

fn test_parse_ipv4_address_shorthand_forms() {
	// Fewer than four parts, a single integer, and hex/octal parts all map to the dotted quad.
	assert parse_ipv4_address('192.168.1')? == parse_ipv4_address('192.168.0.1')?
	assert parse_ipv4_address('16909060')? == parse_ipv4_address('1.2.3.4')?
	assert parse_ipv4_address('0xC0.0xA8.0.1')? == parse_ipv4_address('192.168.0.1')?
	assert parse_ipv4_address('0300.0250.0.1')? == parse_ipv4_address('192.168.0.1')?
	// A trailing dot is ignored.
	assert parse_ipv4_address('1.2.3.4.')? == parse_ipv4_address('1.2.3.4')?
}

fn test_parse_ipv4_address_failures() {
	assert parse_ipv4_address('1.2.3.4.5') == none // too many parts
	assert parse_ipv4_address('256.1.1.1') == none // non-last part out of range
	assert parse_ipv4_address('1.2.3.256') == none // last part >= 256^1
	assert parse_ipv4_address('1..2.3') == none // an empty middle part
	assert parse_ipv4_address('a.b.c.d') == none // non-numeric parts
	assert parse_ipv4_address('') == none
}
