module fileapi

fn test_create_and_accessors() {
	blob := Blob.create('hello'.bytes(), 'text/plain')
	assert blob.size() == u64(5)
	assert blob.type_() == 'text/plain'
	assert blob.raw_bytes().bytestr() == 'hello'
}

fn test_construct_empty() {
	blob := Blob.construct(none, none)
	assert blob.size() == u64(0)
	assert blob.type_() == ''
}

fn test_blob_exact_constructor_and_slice_entry_points() {
	blob := Blob.construct_impl([BlobPart.from_string('abcdef')], BlobPropertyBag{})
	slice := blob.slice(1, 4, 'TEXT/PLAIN')
	assert slice.raw_bytes().bytestr() == 'bcd'
	assert slice.type_() == 'text/plain'
}

fn test_construct_from_parts() {
	inner := Blob.create('world'.bytes(), '')
	parts := [BlobPart.from_string('hello '), BlobPart.from_bytes('big '.bytes()),
		BlobPart.from_blob(inner)]
	blob := Blob.construct(parts, BlobPropertyBag{ type_: 'text/plain' })
	assert blob.raw_bytes().bytestr() == 'hello big world'
	assert blob.type_() == 'text/plain'
}

fn test_blob_constructor_type_lowercases_all_printable_ascii_without_mime_parsing() {
	blob := Blob.construct([BlobPart.from_string('x')], BlobPropertyBag{
		type_: 'Text/Plain;charset=UTF-8'
	})
	assert blob.type_() == 'text/plain;charset=utf-8'
	// A printable string is preserved even when it is not a MIME type.
	bad := Blob.construct([BlobPart.from_string('x')], BlobPropertyBag{ type_: 'not a mime type' })
	assert bad.type_() == 'not a mime type'
}

fn test_convert_line_endings_to_native() {
	assert convert_line_endings_to_native('a\r\nb\rc\nd') == 'a\nb\nc\nd'
	assert convert_line_endings_to_native('no endings') == 'no endings'
	assert convert_line_endings_to_native('\r\n') == '\n'
}

fn test_process_blob_parts_native_endings() {
	parts := [BlobPart.from_string('a\r\nb')]
	// With native endings the string is CRLF-normalized; with transparent it is not.
	native := process_blob_parts(parts, BlobPropertyBag{ endings: .native })
	assert native.bytestr() == 'a\nb'
	transparent := process_blob_parts(parts, BlobPropertyBag{ endings: .transparent })
	assert transparent.bytestr() == 'a\r\nb'
}

fn test_slice() {
	blob := Blob.create('Hello World'.bytes(), 'text/plain')
	// A positive start with no end slices to the end.
	assert blob.slice_blob(6, none, none).raw_bytes().bytestr() == 'World'
	// A negative start is measured from the end.
	assert blob.slice_blob(-5, none, none).raw_bytes().bytestr() == 'World'
	// A positive start and end.
	assert blob.slice_blob(0, 5, none).raw_bytes().bytestr() == 'Hello'
	// A negative end.
	assert blob.slice_blob(0, -6, none).raw_bytes().bytestr() == 'Hello'
	// Out-of-order start/end yields an empty span.
	assert blob.slice_blob(5, 2, none).size() == u64(0)
}

fn test_slice_content_type() {
	blob := Blob.create('data'.bytes(), 'text/plain')
	// A basic-latin content type is ASCII-lowercased.
	assert blob.slice_blob(none, none, 'Text/HTML').type_() == 'text/html'
	// A content type with characters outside U+0020..U+007E becomes the empty string.
	assert blob.slice_blob(none, none, 'té/xt').type_() == ''
	// No content type → empty string.
	assert blob.slice_blob(none, none, none).type_() == ''
}

fn test_blob_owns_input_and_returns_fresh_buffers() {
	mut source := 'abc'.bytes()
	blob := Blob.create(source, 'text/plain')
	source[0] = `z`
	assert blob.raw_bytes().bytestr() == 'abc'
	mut exposed := blob.raw_bytes()
	exposed[1] = `z`
	assert blob.raw_bytes().bytestr() == 'abc'
	mut bytes := blob.bytes()
	bytes[2] = `z`
	assert blob.bytes().bytestr() == 'abc'
}

fn test_blob_text_array_buffer_and_stream() {
	blob := Blob.create('héllo'.bytes(), 'text/plain')
	assert read_all_blob_bytes(blob)! == 'héllo'.bytes()
	assert blob.text()! == 'héllo'
	assert blob.array_buffer() == 'héllo'.bytes()
	mut stream := blob.stream()!
	mut reader := stream.get_default_reader()!
	assert reader.read_all_bytes()! == 'héllo'.bytes()
}

fn test_blob_structured_serialization_round_trip() {
	blob := Blob.create('payload'.bytes(), 'application/octet-stream')
	serialized := blob.serialization_steps()
	restored := Blob.deserialization_steps(serialized)
	assert restored.type_() == blob.type_()
	assert restored.raw_bytes() == blob.raw_bytes()
	assert voidptr(restored) != voidptr(blob)
}
