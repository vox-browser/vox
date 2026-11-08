// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Compression/DecompressionStream.{h,cpp,idl}.
module compression

import compress.deflate

fn decode_raw_bytes(bytes []u8) ![]u8 {
	result := deflate.decompress_raw_with_consumed(bytes)!
	if result.consumed != bytes.len {
		return error('trailing bytes after the raw DEFLATE stream')
	}
	return result.decoded
}

fn decode_bytes(format CompressionFormat, bytes []u8) ![]u8 {
	return match format {
		.brotli {
			mut decoder := IncrementalDecompressor.create(.brotli)!
			defer { decoder.close() }
			result := decoder.push(bytes, true)
			if result.error_message != '' { return error(result.error_message) }
			result.bytes
		}
		.deflate { deflate.decompress_zlib(bytes)! }
		.deflate_raw { decode_raw_bytes(bytes)! }
		.gzip { deflate.decompress_gzip(bytes)! }
	}
}

@[heap]
pub struct DecompressionStream {
mut:
	format_    CompressionFormat
	transform_ &ByteTransformStream = unsafe { nil }
	input_     []u8
	emitted_   int
	finished_  bool
}

// https://compression.spec.whatwg.org/#dom-decompressionstream-decompressionstream
pub fn DecompressionStream.construct_impl(format CompressionFormat) !&DecompressionStream {
	return DecompressionStream.create_for_constructor(format)
}

pub fn DecompressionStream.create_for_constructor(format CompressionFormat) !&DecompressionStream {
	return DecompressionStream.create(format)
}

pub fn DecompressionStream.create(format CompressionFormat) &DecompressionStream {
	mut stream := &DecompressionStream{
		format_: format
	}
	stream.transform_ = ByteTransformStream.create(.decompressor, voidptr(stream))
	return stream
}

pub fn DecompressionStream.construct_from_string(format string) !&DecompressionStream {
	return DecompressionStream.construct_impl(parse_compression_format(format)!)
}

pub fn (stream &DecompressionStream) format() CompressionFormat {
	return stream.format_
}

pub fn (stream &DecompressionStream) readable() &ReadableByteStream {
	return stream.transform_.readable()
}

pub fn (stream &DecompressionStream) writable() &WritableByteStream {
	return stream.transform_.writable()
}

// https://compression.spec.whatwg.org/#decompress-and-enqueue-a-chunk
fn (mut stream DecompressionStream) decompress_and_enqueue_chunk(chunk []u8) ! {
	if stream.finished_ {
		return error('TypeError: Decompression stream has already finished')
	}
	stream.input_ << chunk
	// The translated codec consumes a complete byte slice rather than owning an
	// input stream. Re-run it over the accumulated input and enqueue only the
	// newly produced suffix once the stream is complete. Incomplete-input errors
	// remain pending until later chunks or flush, matching a streaming decoder's
	// need for more input.
	if decoded := decode_bytes(stream.format_, stream.input_) {
		if decoded.len > stream.emitted_ {
			mut readable := stream.transform_.readable_
			readable.enqueue(decoded[stream.emitted_..])
			stream.emitted_ = decoded.len
		}
	}
}

// https://compression.spec.whatwg.org/#decompress-flush-and-enqueue
fn (mut stream DecompressionStream) decompress_flush_and_enqueue() ! {
	if stream.finished_ {
		return error('TypeError: Decompression stream has already finished')
	}
	stream.finished_ = true
	buffer := decode_bytes(stream.format_, stream.input_) or {
		reason := 'TypeError: Unable to decompress flush: ${err}'
		mut readable := stream.transform_.readable_
		readable.error(reason)
		return error(reason)
	}
	mut readable := stream.transform_.readable_
	if buffer.len > stream.emitted_ {
		readable.enqueue(buffer[stream.emitted_..])
		stream.emitted_ = buffer.len
	}
	readable.close()
}
