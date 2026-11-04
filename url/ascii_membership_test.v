module url

// Independent character lists from the URL Standard; no masks or production
// extra-character arrays are used to build this oracle.
fn reference_percent_membership(code_point u32, set PercentEncodeSet) bool {
	if code_point < 0x20 || code_point > 0x7e { return true }
	if set == .c0_control { return false }
	if set == .encode_uri {
		return !(code_point >= `a` && code_point <= `z`)
			&& !(code_point >= `A` && code_point <= `Z`)
			&& !(code_point >= `0` && code_point <= `9`)
			&& u8(code_point) !in ";,/?:@&=+$-_.!~*'()#".bytes()
	}
	extras := match set {
		.fragment { ' "<>`' }
		.query { ' "#<>' }
		.special_query { ' "#<>\'' }
		.path { ' "#<>?^`{}' }
		.userinfo { ' "#<>?^`{}/:;=@[\\]|' }
		.component { ' "#<>?^`{}/:;=@[\\]|$%&+,' }
		.application_x_www_form_urlencoded { ' "#<>?^`{}/:;=@[\\]|$%&+,!\'()~' }
		else { '' }
	}
	return u8(code_point) in extras.bytes()
}

fn test_ascii_membership_matches_standard_for_every_unicode_code_point() {
	sets := [PercentEncodeSet.c0_control, .fragment, .query, .special_query, .path, .userinfo,
		.component, .application_x_www_form_urlencoded, .encode_uri]
	forbidden := '\x00\t\n\r #/:<>?@[\\]^|'.bytes()
	for code_point in u32(0) .. u32(0x110000) {
		expected_host := code_point < 128 && u8(code_point) in forbidden
		assert is_forbidden_host_code_point(code_point) == expected_host
		assert is_forbidden_domain_code_point(code_point) == (expected_host
			|| code_point < 0x20 || code_point == 0x25 || code_point == 0x7f)
		for set in sets {
			assert code_point_is_in_percent_encode_set(code_point, set) == reference_percent_membership(code_point, set)
		}
	}
}

fn test_ascii_membership_does_not_alias_large_or_invalid_code_points() {
	for code_point in [u32(0x110000), 0x80000000, 0xffffff00, 0xffffffff] {
		assert !is_forbidden_host_code_point(code_point)
		assert !is_forbidden_domain_code_point(code_point)
		for set in [PercentEncodeSet.c0_control, .fragment, .query, .special_query, .path, .userinfo,
			.component, .application_x_www_form_urlencoded, .encode_uri] {
			assert code_point_is_in_percent_encode_set(code_point, set)
		}
	}
}

fn test_host_and_percent_encoding_preserve_boundary_and_unicode_behavior() {
	assert parse_opaque_host('a@b') == none
	assert parse_opaque_host('a|b') == none
	assert parse_opaque_host('a%b')? == 'a%b'
	assert parse_opaque_host('a\x7fb')? == 'a%7Fb'
	assert parse_opaque_host('ŀĉ')? == '%C5%80%C4%89'
	assert percent_encode('Az09_~ @/%[]{}é😀', .encode_uri, false) == 'Az09_~%20@/%25%5B%5D%7B%7D%C3%A9%F0%9F%98%80'
	assert percent_encode('Az09_~ @/%[]{}é😀', .application_x_www_form_urlencoded, true) == 'Az09_%7E+%40%2F%25%5B%5D%7B%7D%C3%A9%F0%9F%98%80'
}
