module fileapi

import mimesniff

fn test_source_blob_and_file_constructor_gate_basic_latin_before_mime_parser() {
	for type_ in ['text/plain;name="é"', '\ttext/plain', 'text/plain\t', 'text/plain;name="\u007f"'] {
		// The MIME parser accepts these strings; the source Blob/File gate must
		// reject their non-basic-Latin code units before reaching that parser.
		assert mimesniff.MimeType.parse(type_) != none
		blob := Blob.construct([BlobPart.from_string('body')], BlobPropertyBag{type_: type_})
		assert blob.type_() == ''
		assert blob.raw_bytes() == 'body'.bytes()
		file := File.construct([BlobPart.from_string('body')], 'name.txt', FilePropertyBag{BlobPropertyBag: BlobPropertyBag{type_: type_}, last_modified: i64(89)})
		assert file.type_() == ''
		assert file.raw_bytes() == 'body'.bytes()
		assert file.name() == 'name.txt' && file.last_modified() == 89
	}
}

fn test_source_constructor_type_gate_preserves_valid_mime_and_raw_record_creation() {
	type_ := 'Text/Plain;name="ASCII"'
	blob := Blob.construct(none, BlobPropertyBag{type_: type_})
	file := File.construct([], 'name.txt', FilePropertyBag{BlobPropertyBag: BlobPropertyBag{type_: type_}, last_modified: 0})
	assert blob.type_() == 'text/plain;name=ASCII'
	assert file.type_() == 'text/plain;name=ASCII'
	// Source direct internal constructors/deserialization do not repeat the
	// author constructor gate or normalize arbitrary internal type slots.
	assert Blob.create([], 'raw-é').type_() == 'raw-é'
	assert File.create([], 'name.txt', 'raw-é', 0).type_() == 'raw-é'
}
