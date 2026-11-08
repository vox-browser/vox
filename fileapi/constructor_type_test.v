module fileapi

fn test_blob_file_and_slice_types_follow_the_same_printable_ascii_rules() {
	for input, expected in {
		'': ''
		'A': 'a'
		'NonParsable': 'nonparsable'
		' Text/Plain ; CHARSET="UTF-8" ': ' text/plain ; charset="utf-8" '
		'!~': '!~'
		' a\tb': ''
		'a\nb': ''
		'a\x00b': ''
		'a\x7fb': ''
		'TEXT/PLAIN;v=é': ''
	} {
		blob := Blob.construct_impl([BlobPart.from_string('data')], BlobPropertyBag{type_:input})
		file := File.construct_impl([BlobPart.from_string('data')], 'file', FilePropertyBag{BlobPropertyBag: BlobPropertyBag{type_:input}})
		assert blob.type_() == expected, input
		assert file.type_() == expected, input
		assert blob.slice(none, none, input).type_() == expected, input
		assert blob.raw_bytes() == 'data'.bytes()
		assert file.raw_bytes() == blob.raw_bytes()
	}
	// Internal record creation/deserialization keeps the supplied native type.
	assert Blob.create([]u8{}, 'DirectCase').type_() == 'DirectCase'
	assert File.create([]u8{}, 'name', 'DirectCase', 0).type_() == 'DirectCase'
}
