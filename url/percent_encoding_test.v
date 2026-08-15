module url

fn test_c0_control_set() {
	// The C0 control set is everything outside the printable ASCII range 0x20..0x7E.
	assert code_point_is_in_percent_encode_set(0x1F, .c0_control)
	assert code_point_is_in_percent_encode_set(0x7F, .c0_control)
	assert !code_point_is_in_percent_encode_set(u32(` `), .c0_control) // 0x20
	assert !code_point_is_in_percent_encode_set(u32(`A`), .c0_control)
	assert !code_point_is_in_percent_encode_set(0x7E, .c0_control)
}

fn test_sets_are_layered() {
	// A space is added by the fragment/query sets but is not a C0 control.
	assert code_point_is_in_percent_encode_set(u32(` `), .fragment)
	assert code_point_is_in_percent_encode_set(u32(` `), .query)
	// '#' is in query (and thus path/userinfo/component) but not fragment.
	assert code_point_is_in_percent_encode_set(u32(`#`), .query)
	assert !code_point_is_in_percent_encode_set(u32(`#`), .fragment)
	// "'" is added by the special-query set only.
	assert code_point_is_in_percent_encode_set(u32(`'`), .special_query)
	assert !code_point_is_in_percent_encode_set(u32(`'`), .query)
	// '/' is added by userinfo but not path.
	assert code_point_is_in_percent_encode_set(u32(`/`), .userinfo)
	assert !code_point_is_in_percent_encode_set(u32(`/`), .path)
	// ',' is added by the component set.
	assert code_point_is_in_percent_encode_set(u32(`,`), .component)
	assert !code_point_is_in_percent_encode_set(u32(`,`), .userinfo)
}

fn test_encode_uri_set() {
	// encodeURI() leaves alphanumerics and the reserved/mark set un-encoded, but encodes space.
	assert !code_point_is_in_percent_encode_set(u32(`a`), .encode_uri)
	assert !code_point_is_in_percent_encode_set(u32(`5`), .encode_uri)
	assert !code_point_is_in_percent_encode_set(u32(`#`), .encode_uri)
	assert !code_point_is_in_percent_encode_set(u32(`/`), .encode_uri)
	assert code_point_is_in_percent_encode_set(u32(` `), .encode_uri)
	assert code_point_is_in_percent_encode_set(0x100, .encode_uri) // > 0x7E
}

fn test_percent_encode_ascii() {
	// A space is in the userinfo set (via query), so it is percent-encoded.
	assert percent_encode('a b', .userinfo, false) == 'a%20b'
	// Unreserved characters pass through.
	assert percent_encode('AZaz09-._', .userinfo, false) == 'AZaz09-._'
}

fn test_percent_encode_space_as_plus() {
	assert percent_encode('a b c', .application_x_www_form_urlencoded, true) == 'a+b+c'
	// Without the flag the space is percent-encoded instead.
	assert percent_encode('a b', .application_x_www_form_urlencoded, false) == 'a%20b'
}

fn test_percent_encode_multibyte() {
	// U+00E9 é -> C3 A9, and U+1F600 (astral) -> F0 9F 98 80.
	assert percent_encode('é', .userinfo, false) == '%C3%A9'
	assert percent_encode('😀', .userinfo, false) == '%F0%9F%98%80'
}

fn test_percent_decode_basic() {
	assert percent_decode('a%20b').bytestr() == 'a b'
	assert percent_decode('%C3%A9').bytestr() == 'é'
	assert percent_decode('no-percent').bytestr() == 'no-percent'
	// Lowercase hex digits decode too.
	assert percent_decode('%c3%a9').bytestr() == 'é'
}

fn test_percent_decode_leaves_malformed_sequences() {
	// A '%' not followed by two hex digits is left as-is.
	assert percent_decode('100%').bytestr() == '100%'
	assert percent_decode('%2').bytestr() == '%2'
	assert percent_decode('%GG').bytestr() == '%GG'
	assert percent_decode('%2G').bytestr() == '%2G'
}

fn test_encode_then_decode_round_trips() {
	original := "Hello, World! $&+=/:@ café 😀"
	encoded := percent_encode(original, .component, false)
	assert percent_decode(encoded).bytestr() == original
}
