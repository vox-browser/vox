// Copyright (c) 2022-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained core of Libraries/LibWeb/FileAPI/File.cpp — the File record,
// which extends Blob with a name and a lastModified timestamp, plus its constructor. The type is
// normalized as printable ASCII with ASCII lowercase, and an absent lastModified
// defaults to the current time in milliseconds since the Unix epoch. Structured serialization is
// exposed as a typed payload while the wire encoder remains an HTML/runtime concern.
// https://w3c.github.io/FileAPI/#file-section
module fileapi

import time
import libjs

// https://w3c.github.io/FileAPI/#dfn-FilePropertyBag
// FilePropertyBag : BlobPropertyBag { long long lastModified; }
pub struct FilePropertyBag {
	BlobPropertyBag
pub mut:
	last_modified ?i64
}

// https://w3c.github.io/FileAPI/#dfn-file — File : Blob, adding a name and a lastModified time.
@[heap]
pub struct File {
	Blob
mut:
	name_          string
	name_utf16_    ?libjs.Utf16String
	last_modified_ i64
}

// The private `File(realm, byte_buffer, file_name, type, last_modified)` constructor: build a File
// directly from its byte sequence, name, type and lastModified time.
pub fn File.create(byte_buffer []u8, file_name string, type_ string, last_modified i64) &File {
	return File.create_utf16(byte_buffer, libjs.utf16_string_from_utf8_without_validation(file_name),
		libjs.utf16_string_from_utf8_without_validation(type_), last_modified)
}

// File.cpp's direct source field constructor and deserialization own actual
// Utf16String name/type slots; public USVString/normalization stays separate.
pub fn File.create_utf16(byte_buffer []u8, file_name libjs.Utf16String, type_ libjs.Utf16String, last_modified i64) &File {
	return &File{
		Blob: Blob{byte_buffer: byte_buffer.clone(), type_: type_.str(), type_utf16_: type_}
		name_: file_name.str()
		name_utf16_: file_name
		last_modified_: last_modified
	}
}

// https://w3c.github.io/FileAPI/#ref-for-dom-file-file — the File(fileBits, fileName, options)
// constructor.
pub fn File.construct(file_bits []BlobPart, file_name string, options ?FilePropertyBag) &File {
	// 1. Let bytes be the result of processing blob parts given fileBits and options.
	blob_options := if opts := options { opts.BlobPropertyBag } else { BlobPropertyBag{} }
	bytes := process_blob_parts(file_bits, blob_options)
	// 2. Let n be the fileName argument to the constructor.
	name := file_name
	// 3. Process the FilePropertyBag dictionary argument.
	mut type_ := ''
	mut last_modified := i64(0)
	if opts := options {
		// File API lowercases the complete printable ASCII string without MIME parsing.
		if is_basic_latin(opts.type_) {
			type_ = ascii_lowercase(opts.type_)
		}
		// lastModified defaults to the current time in ms since the Unix epoch when not provided.
		last_modified = opts.last_modified or { time.now().unix_milli() }
	}
	// 4. Return a new File object referring to bytes, with the given name, type and lastModified.
	return File.create(bytes, name, type_, last_modified)
}

pub fn File.construct_impl(file_bits []BlobPart, file_name string, options ?FilePropertyBag) &File {
	return File.construct(file_bits, file_name, options)
}

// https://w3c.github.io/FileAPI/#dfn-name
pub fn (file &File) name() string {
	return file.name_
}

pub fn (file &File) name_utf16() libjs.Utf16String {
	return fileapi_preserved_utf16(file.name_, file.name_utf16_)
}

// https://w3c.github.io/FileAPI/#dfn-lastModified
pub fn (file &File) last_modified() i64 {
	return file.last_modified_
}

pub struct SerializedFile {
pub:
	type_         string
	type_utf16_   ?libjs.Utf16String
	name_utf16_   ?libjs.Utf16String
	bytes         []u8
	name          string
	last_modified i64
}

pub fn (file &File) serialization_steps() SerializedFile {
	return SerializedFile{
		type_:         file.type_()
		type_utf16_:   file.type_utf16()
		name_utf16_:   file.name_utf16()
		bytes:         file.raw_bytes()
		name:          file.name_
		last_modified: file.last_modified_
	}
}

pub fn File.deserialization_steps(serialized SerializedFile) &File {
	return File.create_utf16(serialized.bytes, fileapi_preserved_utf16(serialized.name, serialized.name_utf16_), fileapi_preserved_utf16(serialized.type_, serialized.type_utf16_), serialized.last_modified)
}

pub fn (mut file File) deserialization_steps_utf16(type_ libjs.Utf16String, bytes []u8, name libjs.Utf16String, last_modified i64) {
	file.Blob.deserialization_steps_utf16(type_, bytes)
	file.name_ = name.str()
	file.name_utf16_ = name
	file.last_modified_ = last_modified
}
