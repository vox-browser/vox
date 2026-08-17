// Copyright (c) 2022-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained core of Libraries/LibWeb/FileAPI/File.cpp — the File record,
// which extends Blob with a name and a lastModified timestamp, plus its constructor. The type is
// normalized through the mimesniff MimeType parser (matching upstream), and an absent lastModified
// defaults to the current time in milliseconds since the Unix epoch. Structured serialization is
// exposed as a typed payload while the wire encoder remains an HTML/runtime concern.
// https://w3c.github.io/FileAPI/#file-section
module fileapi

import mimesniff
import time

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
	name_          string
	last_modified_ i64
}

// The private `File(realm, byte_buffer, file_name, type, last_modified)` constructor: build a File
// directly from its byte sequence, name, type and lastModified time.
pub fn File.create(byte_buffer []u8, file_name string, type_ string, last_modified i64) &File {
	return &File{
		Blob:           Blob{
			byte_buffer: byte_buffer.clone()
			type_:       type_
		}
		name_:          file_name
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
		// The spec is out of date: the type is normalized through the MimeType parser (an
		// unparseable, e.g. empty, type leaves the type as the empty string).
		if parsed_type := mimesniff.MimeType.parse(opts.type_) {
			type_ = parsed_type.serialized()
		}
		// lastModified defaults to the current time in ms since the Unix epoch when not provided.
		last_modified = opts.last_modified or { time.now().unix_milli() }
	}
	// 4. Return a new File object referring to bytes, with the given name, type and lastModified.
	return File.create(bytes, name, type_, last_modified)
}

// https://w3c.github.io/FileAPI/#dfn-name
pub fn (file &File) name() string {
	return file.name_
}

// https://w3c.github.io/FileAPI/#dfn-lastModified
pub fn (file &File) last_modified() i64 {
	return file.last_modified_
}

pub struct SerializedFile {
pub:
	type_         string
	bytes         []u8
	name          string
	last_modified i64
}

pub fn (file &File) serialization_steps() SerializedFile {
	return SerializedFile{
		type_:         file.type_()
		bytes:         file.raw_bytes()
		name:          file.name_
		last_modified: file.last_modified_
	}
}

pub fn File.deserialization_steps(serialized SerializedFile) &File {
	return File.create(serialized.bytes, serialized.name, serialized.type_,
		serialized.last_modified)
}
