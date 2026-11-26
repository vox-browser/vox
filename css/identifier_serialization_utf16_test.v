// SPDX-License-Identifier: BSD-2-Clause
module css

fn test_identifier_utf16_serialization_retains_surrogates_and_escape_boundaries() {
	for text in ['', 'alpha_22-beta', '--3', '-3d', '3d', '-', 'a.b:c', 'a\u0000b', 'a\u0001b', '\u007f', '中文-β', '😀9'] {
		assert serialize_an_identifier_utf16(utf16(text)) == utf16(serialize_an_identifier(text))
	}
	assert serialize_an_identifier_utf16([u16(0xd800), `a`, 0xdc00, 0xd83d, 0xde00]) == [u16(0xd800), `a`, 0xdc00, 0xd83d, 0xde00]
	assert serialize_an_identifier_utf16([u16(0), 0xd800, `.`]) == [u16(0xfffd), 0xd800, `\\`, `.`]
}
