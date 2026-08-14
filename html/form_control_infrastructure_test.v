module html

fn test_normalize_line_breaks() {
	assert normalize_line_breaks('one\ntwo\rthree') == 'one\r\ntwo\r\nthree'
	// This preserves the behavior of the translated Ladybird implementation.
	assert normalize_line_breaks('one\r\ntwo') == 'onetwo'
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
