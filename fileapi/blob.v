// Copyright (c) 2022-2023, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained core of Libraries/LibWeb/FileAPI/Blob.cpp — the Blob record
// (a byte sequence + a MIME type), convert-line-endings-to-native, process-blob-parts, the
// constructor, slice, stream and data accessors. WebIDL Promise settlement is a LibJS boundary;
// the standalone typed API returns the deterministically settled value directly. The type is
// normalized via the mimesniff MimeType parser, matching upstream.
// https://w3c.github.io/FileAPI/#blob-section
module fileapi

import mimesniff
import encoding
import streams
import libjs

// Bindings::EndingType.
pub enum EndingType {
	transparent
	native
}

// https://w3c.github.io/FileAPI/#dfn-BlobPropertyBag
pub struct BlobPropertyBag {
pub mut:
	type_   string
	endings EndingType = .transparent
}

// A single blob part: a string (USVString), a byte buffer (BufferSource), or a Blob.
pub enum BlobPartKind {
	string
	bytes
	blob
}

pub struct BlobPart {
pub:
	kind         BlobPartKind
	string_value string
	bytes_value  []u8
	blob_value   ?&Blob
}

pub fn BlobPart.from_string(value string) BlobPart {
	return BlobPart{
		kind: .string
		string_value: value
	}
}

pub fn BlobPart.from_bytes(value []u8) BlobPart {
	return BlobPart{
		kind: .bytes
		bytes_value: value
	}
}

pub fn BlobPart.from_blob(value &Blob) BlobPart {
	return BlobPart{
		kind: .blob
		blob_value: value
	}
}

// https://w3c.github.io/FileAPI/#convert-line-endings-to-native
pub fn convert_line_endings_to_native(input string) string {
	// 1-2. The native line ending is LF (this port does not target Windows).
	native_line_ending := '\n'
	// 3. result is the empty string.
	mut result := ''
	bytes := input.bytes()
	mut position := 0
	// 5-6. Collect the first run of non-LF/CR code points.
	for {
		start := position
		for position < bytes.len && bytes[position] != `\n` && bytes[position] != `\r` {
			position++
		}
		result += bytes[start..position].bytestr()
		// 7. While not past the end:
		if position >= bytes.len {
			break
		}
		if bytes[position] == `\r` {
			// 1. CR (optionally followed by LF) → one native line ending.
			result += native_line_ending
			position++
			if position < bytes.len && bytes[position] == `\n` {
				position++
			}
		} else {
			// 2. LF → one native line ending.
			result += native_line_ending
			position++
		}
	}
	// 8. Return result.
	return result
}

// https://w3c.github.io/FileAPI/#process-blob-parts
pub fn process_blob_parts(blob_parts []BlobPart, options BlobPropertyBag) []u8 {
	// 1. Let bytes be an empty sequence.
	mut bytes := []u8{}
	// 2. For each element in parts:
	for blob_part in blob_parts {
		match blob_part.kind {
			.string {
				// 1. A USVString: convert line endings to native if requested, then UTF-8 encode.
				mut s := blob_part.string_value
				if options.endings == .native {
					s = convert_line_endings_to_native(s)
				}
				bytes << s.bytes()
			}
			.bytes {
				// 2. A BufferSource: append a copy of its bytes.
				bytes << blob_part.bytes_value
			}
			.blob {
				// 3. A Blob: append the bytes it represents.
				if blob := blob_part.blob_value {
					bytes << blob.raw_bytes()
				}
			}
		}
	}
	// 3. Return bytes.
	return bytes
}

fn is_basic_latin(input string) bool {
	// Every code point is in the range U+0020 to U+007E.
	for code_point in input.runes() {
		cp := u32(code_point)
		if cp < 0x20 || cp > 0x7E {
			return false
		}
	}
	return true
}

fn ascii_lowercase(input string) string {
	mut bytes := input.bytes()
	for i, ch in bytes {
		if ch >= `A` && ch <= `Z` {
			bytes[i] = ch + 0x20
		}
	}
	return bytes.bytestr()
}

// https://w3c.github.io/FileAPI/#dfn-Blob
@[heap]
pub struct Blob {
mut:
	byte_buffer []u8
	type_       string
	type_utf16_ ?libjs.Utf16String
}

// https://w3c.github.io/FileAPI/#ref-for-dom-blob-blob②
pub fn Blob.create(byte_buffer []u8, type_ string) &Blob {
	return Blob.create_utf16(byte_buffer, libjs.utf16_string(type_))
}

// Blob.cpp's actual ByteBuffer/Utf16String internal constructor. Public
// constructor normalization happens before this source record is allocated.
pub fn Blob.create_utf16(byte_buffer []u8, type_ libjs.Utf16String) &Blob {
	return &Blob{byte_buffer: byte_buffer.clone(), type_: type_.str(), type_utf16_: type_}
}

// https://w3c.github.io/FileAPI/#constructorBlob
pub fn Blob.construct(blob_parts ?[]BlobPart, options ?BlobPropertyBag) &Blob {
	// 1. With zero parameters, return a 0-byte Blob with an empty type.
	if blob_parts == none && options == none {
		return &Blob{}
	}
	// 2. bytes = process blob parts given blobParts and options.
	mut byte_buffer := []u8{}
	if parts := blob_parts {
		byte_buffer = process_blob_parts(parts, options or { BlobPropertyBag{} })
	}
	mut type_ := ''
	// 3. If the type member is non-empty, normalize it via the MIME type parser.
	if opts := options {
		if opts.type_.len != 0 && is_basic_latin(opts.type_) {
			if parsed_type := mimesniff.MimeType.parse(opts.type_) {
				type_ = parsed_type.serialized()
			}
		}
	}
	// 4. Return the Blob referring to bytes.
	return Blob.create(byte_buffer, type_)
}

pub fn Blob.construct_impl(blob_parts ?[]BlobPart, options ?BlobPropertyBag) &Blob {
	return Blob.construct(blob_parts, options)
}

// https://w3c.github.io/FileAPI/#dfn-size
pub fn (blob &Blob) size() u64 {
	return u64(blob.byte_buffer.len)
}

// https://w3c.github.io/FileAPI/#dfn-type
pub fn (blob &Blob) type_() string {
	return blob.type_
}

pub fn (blob &Blob) type_utf16() libjs.Utf16String {
	return fileapi_preserved_utf16(blob.type_, blob.type_utf16_)
}

pub fn (blob &Blob) raw_bytes() []u8 {
	return blob.byte_buffer.clone()
}

// https://w3c.github.io/FileAPI/#slice-blob
pub fn (blob &Blob) slice_blob(start ?i64, end ?i64, content_type ?string) &Blob {
	// 1. originalSize = blob's size.
	original_size := i64(blob.size())
	// 2. Normalize start.
	mut relative_start := i64(0)
	if start_value := start {
		relative_start = if start_value < 0 {
			max_i64(original_size + start_value, 0)
		} else {
			min_i64(start_value, original_size)
		}
	}
	// 3. Normalize end.
	mut relative_end := original_size
	if end_value := end {
		relative_end = if end_value < 0 {
			max_i64(original_size + end_value, 0)
		} else {
			min_i64(end_value, original_size)
		}
	}
	// 4. Normalize contentType.
	mut relative_content_type := ''
	if content_type_value := content_type {
		// Characters outside U+0020..U+007E → empty string; otherwise ASCII-lowercase.
		if is_basic_latin(content_type_value) {
			relative_content_type = ascii_lowercase(content_type_value)
		}
	}
	// 5. span = max(relativeEnd - relativeStart, 0).
	span := max_i64(relative_end - relative_start, 0)
	// 6. Return a new Blob over the span consecutive bytes from relativeStart.
	byte_buffer := blob.byte_buffer[int(relative_start)..int(relative_start + span)]
	return Blob.create(byte_buffer, relative_content_type)
}

pub fn (blob &Blob) slice(start ?i64, end ?i64, content_type ?string) &Blob {
	return blob.slice_blob(start, end, content_type)
}

fn max_i64(a i64, b i64) i64 {
	return if a > b { a } else { b }
}

fn min_i64(a i64, b i64) i64 {
	return if a < b { a } else { b }
}

// https://w3c.github.io/FileAPI/#blob-get-stream
pub fn (blob &Blob) get_stream() !&streams.ReadableStream {
	mut stream := streams.ReadableStream.construct_impl(streams.UnderlyingSource{
		type_: .bytes
	}, streams.QueuingStrategy{})!
	if blob.byte_buffer.len > 0 {
		stream.pull_from_bytes(blob.byte_buffer)!
	}
	stream.close()
	return stream
}

// https://w3c.github.io/FileAPI/#dom-blob-stream
pub fn (blob &Blob) stream() !&streams.ReadableStream {
	return blob.get_stream()
}

pub fn read_all_blob_bytes(blob &Blob) ![]u8 {
	mut stream := blob.get_stream()!
	mut reader := stream.get_default_reader()!
	return reader.read_all_bytes()!
}

// https://w3c.github.io/FileAPI/#dom-blob-text
pub fn (blob &Blob) text() !string {
	decoder := encoding.TextDecoder.create()
	return decoder.decode(read_all_blob_bytes(blob)!, encoding.TextDecodeOptions{})
}

// The WebIDL ArrayBuffer and Uint8Array wrappers are LibJS-owned. Both typed
// accessors return a fresh byte buffer, preserving the spec's NewObject rule.
pub fn (blob &Blob) array_buffer() []u8 {
	return read_all_blob_bytes(blob) or { []u8{} }
}

pub fn (blob &Blob) bytes() []u8 {
	return read_all_blob_bytes(blob) or { []u8{} }
}

pub struct SerializedBlob {
pub:
	type_ string
	type_utf16_ ?libjs.Utf16String
	bytes []u8
}

// Typed host form of the StructuredSerialize payload.
pub fn (blob &Blob) serialization_steps() SerializedBlob {
	return SerializedBlob{
		type_: blob.type_
		type_utf16_: blob.type_utf16()
		bytes: blob.byte_buffer.clone()
	}
}

pub fn Blob.deserialization_steps(serialized SerializedBlob) &Blob {
	return Blob.create_utf16(serialized.bytes, fileapi_preserved_utf16(serialized.type_, serialized.type_utf16_))
}

// Source deserialization mutates the record created before its payload is read.
pub fn (mut blob Blob) deserialization_steps_utf16(type_ libjs.Utf16String, bytes []u8) {
	blob.type_ = type_.str()
	blob.type_utf16_ = type_
	blob.byte_buffer = bytes.clone()
}
