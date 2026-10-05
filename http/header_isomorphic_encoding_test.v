module http

import libjs

fn test_source_header_utf16_and_string_view_overloads_preserve_isomorphic_bytes() {
	latin := libjs.utf16_string_from_code_units([u16(0x41), 0xe9, 0xff])
	utf16_header := Header.isomorphic_encode_utf16('X-é', latin)
	assert utf16_header.name.bytes() == [u8(0x58), 0x2d, 0xe9]
	assert utf16_header.value.bytes() == [u8(0x41), 0xe9, 0xff]
	string_header := Header.isomorphic_encode_utf8('X-é', 'Aéÿ')
	assert string_header == utf16_header
	mut list := HeaderList.create()
	list.append(utf16_header)
	assert list.headers()[0].value.bytes() == [u8(0x41), 0xe9, 0xff]
}
