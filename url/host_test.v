module url

fn test_is_forbidden_host_code_point() {
	// The whitespace and delimiter code points are forbidden.
	for cp in [u32(0x00), 0x09, 0x0A, 0x0D, u32(` `), u32(`#`), u32(`/`), u32(`:`), u32(`<`),
		u32(`>`), u32(`?`), u32(`@`), u32(`[`), u32(`\\`), u32(`]`), u32(`^`), u32(`|`)] {
		assert is_forbidden_host_code_point(cp)
	}
	// Ordinary host characters are allowed; note % and DEL are NOT forbidden host code points.
	assert !is_forbidden_host_code_point(u32(`a`))
	assert !is_forbidden_host_code_point(u32(`.`))
	assert !is_forbidden_host_code_point(u32(`-`))
	assert !is_forbidden_host_code_point(u32(`%`))
	assert !is_forbidden_host_code_point(0x7F)
	assert !is_forbidden_host_code_point(0x00E9) // é
}

fn test_is_forbidden_domain_code_point() {
	// Everything forbidden for a host, plus C0 controls, %, and DEL.
	assert is_forbidden_domain_code_point(u32(`/`)) // forbidden host
	assert is_forbidden_domain_code_point(0x01) // C0 control
	assert is_forbidden_domain_code_point(0x1F) // C0 control
	assert is_forbidden_domain_code_point(u32(`%`))
	assert is_forbidden_domain_code_point(0x7F) // DEL
	// Ordinary domain characters are allowed.
	assert !is_forbidden_domain_code_point(u32(`a`))
	assert !is_forbidden_domain_code_point(u32(`.`))
	assert !is_forbidden_domain_code_point(u32(`-`))
}

fn test_parse_opaque_host() {
	// A plain opaque host passes through unchanged.
	assert parse_opaque_host('example.com')? == 'example.com'
	// A forbidden host code point is a failure.
	assert parse_opaque_host('a b') == none // space
	assert parse_opaque_host('a/b') == none // slash
	assert parse_opaque_host('a#b') == none // hash
	// A non-forbidden C0 control is percent-encoded (with the C0 control set).
	assert parse_opaque_host('a\x07b')? == 'a%07b'
	// Non-ASCII is percent-encoded too.
	assert parse_opaque_host('ä')? == '%C3%A4'
}

fn test_ends_in_a_number_checker() {
	// A last label that is all digits or a 0x-prefixed hex number ends in a number.
	assert ends_in_a_number_checker('1.2.3.4')
	assert ends_in_a_number_checker('example.255')
	assert ends_in_a_number_checker('192.168.1')
	assert ends_in_a_number_checker('example.0x10')
	assert ends_in_a_number_checker('0x') // "0x" with no digits still counts
	// A trailing dot is ignored.
	assert ends_in_a_number_checker('1.2.3.4.')
	// Ordinary domains do not end in a number.
	assert !ends_in_a_number_checker('example.com')
	assert !ends_in_a_number_checker('example.com.')
	assert !ends_in_a_number_checker('a.b')
	assert !ends_in_a_number_checker('')
	assert !ends_in_a_number_checker('.')
}

fn test_domain_to_ascii_and_host_parser_match_whatwg_url() {
	assert domain_to_ascii('EXAMPLE.COM', false)? == 'example.com'
	assert domain_to_ascii('faß.de', false)? == 'xn--fa-hia.de'
	assert domain_to_ascii('測試', false)? == 'xn--g6w251d'
	assert domain_to_ascii('', false) == none
	assert domain_to_ascii('xn--a', false) == none

	domain := parse_host('fa%C3%9F.de', false) or { panic('expected domain') }
	assert domain is string
	assert domain as string == 'xn--fa-hia.de'
	ipv4 := parse_host('0x7f.1', false) or { panic('expected IPv4') }
	assert ipv4 is Ipv4Host
	assert (ipv4 as Ipv4Host).address == u32(0x7f000001)
	ipv6 := parse_host('[2001:db8::1]', false) or { panic('expected IPv6') }
	assert ipv6 is Ipv6Host
	assert ipv6.serialize() == '[2001:db8::1]'
	assert parse_host('[2001:db8::1', false) == none
	assert parse_host('a/b', false) == none
}
