module fileapi

import libjs

fn test_file_byte_name_boundary_retains_source_wtf8_units_in_direct_and_parts_construction() {
	name := libjs.utf16_string_from_code_units([u16(`n`), 0xd800, 0, 0xdc00, 0xd83d, 0xde00])
	type_ := libjs.utf16_string_from_code_units([u16(`x`), 0xdfff, 0])
	direct := File.create([u8(1), 0xff], name.str(), type_.str(), -7)
	assert direct.name_utf16().code_units() == name.code_units()
	assert direct.type_utf16().code_units() == type_.code_units()
	assert direct.last_modified() == -7
	options := FilePropertyBag{
		BlobPropertyBag: BlobPropertyBag{
			type_: 'TEXT/PLAIN'
		}
		last_modified:   -4096
	}
	parts := File.construct([BlobPart.from_bytes([u8(1), 0xff])], name.str(), options)
	assert parts.name_utf16().code_units() == name.code_units()
	assert parts.raw_bytes() == direct.raw_bytes()
	assert parts.type_() == 'text/plain'
	assert parts.last_modified() == -4096
	assert File.deserialization_steps(parts.serialization_steps()).name_utf16().code_units() == name.code_units()
}

fn test_file_byte_name_boundary_uses_native_source_unvalidated_decoder_rules() {
	truncated := File.create([], [u8(0xe2), 0x82].bytestr(), '', 0)
	assert truncated.name_utf16().code_units() == [u16(0xfffd), 0xfffd]
	too_large := File.create([], [u8(0xf4), 0x90, 0x80, 0x80].bytestr(), '', 0)
	assert too_large.name_utf16().code_units() == [u16(0xfffd)]
	overlong := File.create([], [u8(0xc0), 0xaf].bytestr(), '', 0)
	assert overlong.name_utf16().code_units() == [u16(`/`)]
	assert !overlong.name_utf16().has_ascii_storage()
}
