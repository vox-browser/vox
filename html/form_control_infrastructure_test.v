module html

import fileapi

fn test_normalize_line_breaks() {
	assert normalize_line_breaks('one\ntwo\rthree') == 'one\r\ntwo\r\nthree'
	// This preserves the behavior of the translated Ladybird implementation.
	assert normalize_line_breaks('one\r\ntwo') == 'onetwo'
}

fn test_form_entry_creation_normalizes_scalar_strings_and_retains_file_metadata() {
	invalid := [rune(0xd800)].string()
	entry := create_form_data_string_entry('name${invalid}', 'value${invalid}')
	assert entry.name == 'name�'
	assert entry.value == FormDataEntryValue('value�')
	file := fileapi.File.create([u8(1), 2], 'old.bin', 'application/octet-stream', 1234)
	value := create_form_data_native_file_entry('file', file).value as FormDataFile
	assert create_form_data_file_entry('file', value, none).value == FormDataEntryValue(value)
	renamed := create_form_data_file_entry('file', value, 'new.bin').value as FormDataFile
	assert renamed.file? != file
	assert renamed.file?.name() == 'new.bin'
	assert renamed.file?.last_modified() == 1234
	assert renamed.file?.type_() == file.type_()
	assert renamed.file?.raw_bytes() == file.raw_bytes()
}

fn test_serialize_to_multipart_form_data() {
	entries := [create_form_data_string_entry('field"name', 'first\nsecond'),
		create_form_data_file_entry('upload', FormDataFile{
			name:  'a".txt'
			bytes: [u8(0), 1, 2]
		}, none)]
	serialized := serialize_to_multipart_form_data(entries)
	text := serialized.serialized_data.bytestr()
	assert text.starts_with('--${serialized.boundary}\r\n')
	assert text.contains('name="field%22name"')
	assert text.contains('first\r\nsecond\r\n')
	assert text.contains('filename="a%22.txt"')
	assert text.contains('Content-Type: application/octet-stream\r\n\r\n')
	assert text.ends_with('--${serialized.boundary}--\r\n')
}
