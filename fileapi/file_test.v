module fileapi

import time

fn test_construct_basic() {
	parts := [BlobPart.from_string('hello '), BlobPart.from_string('world')]
	f := File.construct(parts, 'greeting.txt', FilePropertyBag{
		BlobPropertyBag: BlobPropertyBag{
			type_: 'text/plain'
		}
		last_modified:   i64(1234567890)
	})
	assert f.name() == 'greeting.txt'
	assert f.last_modified() == i64(1234567890)
	// A File is a Blob: the inherited accessors work through the embedded record.
	assert f.raw_bytes().bytestr() == 'hello world'
	assert f.type_() == 'text/plain'
	assert f.size() == u64(11)
}

fn test_construct_no_options() {
	// With no options the type is empty and lastModified stays 0 (upstream skips the dictionary step).
	f := File.construct([BlobPart.from_string('x')], 'a.txt', none)
	assert f.name() == 'a.txt'
	assert f.type_() == ''
	assert f.last_modified() == i64(0)
	assert f.raw_bytes().bytestr() == 'x'
}

fn test_file_exact_constructor_entry_point() {
	file := File.construct_impl([BlobPart.from_string('body')], 'entry.txt', none)
	assert file.name() == 'entry.txt'
	assert file.raw_bytes().bytestr() == 'body'
}

fn test_file_constructor_type_lowercases_all_printable_ascii_without_mime_parsing() {
	f := File.construct([BlobPart.from_string('x')], 'a.txt', FilePropertyBag{
		BlobPropertyBag: BlobPropertyBag{
			type_: 'Text/Plain;charset=UTF-8'
		}
	})
	assert f.type_() == 'text/plain;charset=utf-8'
	// A printable string is preserved even when it is not a MIME type.
	bad := File.construct([BlobPart.from_string('x')], 'a.txt', FilePropertyBag{
		BlobPropertyBag: BlobPropertyBag{
			type_: 'not a mime type'
		}
	})
	assert bad.type_() == 'not a mime type'
}

fn test_construct_default_last_modified_is_now() {
	// An absent lastModified defaults to the current time in ms since the Unix epoch.
	before := time.now().unix_milli()
	f := File.construct([BlobPart.from_string('x')], 'a.txt', FilePropertyBag{})
	after := time.now().unix_milli()
	assert f.last_modified() >= before
	assert f.last_modified() <= after
}

fn test_construct_native_line_endings() {
	// endings: native normalizes CRLF to LF through the embedded BlobPropertyBag.
	parts := [BlobPart.from_string('a\r\nb')]
	f := File.construct(parts, 'a.txt', FilePropertyBag{
		BlobPropertyBag: BlobPropertyBag{
			endings: .native
		}
	})
	assert f.raw_bytes().bytestr() == 'a\nb'
}

fn test_construct_from_blob_part() {
	// A File can be built from an existing Blob part, concatenated with the other kinds.
	inner := Blob.create('world'.bytes(), '')
	parts := [BlobPart.from_string('hello '), BlobPart.from_blob(inner)]
	f := File.construct(parts, 'a.txt', none)
	assert f.raw_bytes().bytestr() == 'hello world'
}

fn test_create_direct() {
	// The direct field constructor sets name/type/lastModified without any processing.
	f := File.create('data'.bytes(), 'note.bin', 'application/octet-stream', i64(42))
	assert f.name() == 'note.bin'
	assert f.type_() == 'application/octet-stream'
	assert f.last_modified() == i64(42)
	assert f.size() == u64(4)
}

fn test_file_slice_returns_a_blob() {
	// slice is inherited from Blob and returns a plain Blob over the requested span.
	f := File.create('Hello World'.bytes(), 'a.txt', 'text/plain', i64(1))
	sliced := f.slice_blob(6, none, none)
	assert sliced.raw_bytes().bytestr() == 'World'
}

fn test_file_structured_serialization_round_trip() {
	file := File.create('data'.bytes(), 'note.txt', 'text/plain', i64(42))
	restored := File.deserialization_steps(file.serialization_steps())
	assert restored.name() == 'note.txt'
	assert restored.type_() == 'text/plain'
	assert restored.last_modified() == 42
	assert restored.raw_bytes().bytestr() == 'data'
	assert voidptr(restored) != voidptr(file)
}
