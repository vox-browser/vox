module css

// https://www.w3.org/TR/css-syntax-3/#ident-code-point, spelled out.
fn reference_ident_code_point(code_point u32) bool {
	return (code_point >= `A` && code_point <= `Z`) || (code_point >= `a` && code_point <= `z`)
		|| (code_point > 0x7f && code_point <= 0x10ffff) || code_point == `_`
		|| (code_point >= `0` && code_point <= `9`) || code_point == `-`
}

fn test_ident_code_point_bits_match_the_definition() {
	for code_point in u32(0) .. 0x400 {
		assert is_ident_code_point(code_point) == reference_ident_code_point(code_point), '${code_point}'
	}
	for code_point in [u32(0xd800), 0xfffd, 0x10ffff, 0x110000, 0x7fffffff, 0xffffffff] {
		assert is_ident_code_point(code_point) == reference_ident_code_point(code_point), '${code_point}'
	}
}
