// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Compression/CompressionStream.{h,cpp,idl} and the narrow
// GenericTransformStream surface it exposes.
module compression

import x.compress.brotli

pub enum CompressionFormat {
	brotli
	deflate
	deflate_raw
	gzip
}

pub fn parse_compression_format(value string) !CompressionFormat {
	return match value {
		'br' { .brotli }
		'deflate' { .deflate }
		'deflate-raw' { .deflate_raw }
		'gzip' { .gzip }
		else { error('TypeError: Unsupported compression format: ${value}') }
	}
}

pub fn compression_format_string(format CompressionFormat) string {
	return match format {
		.brotli { 'br' }
		.deflate { 'deflate' }
		.deflate_raw { 'deflate-raw' }
		.gzip { 'gzip' }
	}
}

pub enum ByteStreamState {
	readable
	closed
	errored
}

@[heap]
pub struct ReadableByteStream {
mut:
	chunks_ [][]u8
	state_  ByteStreamState
	reason_ string
}

pub fn (stream &ReadableByteStream) state() ByteStreamState {
	return stream.state_
}

pub fn (stream &ReadableByteStream) reason() string {
	return stream.reason_
}

pub fn (stream &ReadableByteStream) chunk_count() int {
	return stream.chunks_.len
}

pub fn (mut stream ReadableByteStream) read() ?[]u8 {
	if stream.chunks_.len == 0 {
		return none
	}
	chunk := stream.chunks_[0].clone()
	stream.chunks_.delete(0)
	return chunk
}

pub fn (mut stream ReadableByteStream) read_all() []u8 {
	mut output := []u8{}
	for chunk in stream.chunks_ {
		output << chunk
	}
	stream.chunks_.clear()
	return output
}

fn (mut stream ReadableByteStream) enqueue(chunk []u8) {
	if chunk.len > 0 && stream.state_ == .readable {
		stream.chunks_ << chunk.clone()
	}
}

fn (mut stream ReadableByteStream) close() {
	if stream.state_ == .readable {
		stream.state_ = .closed
	}
}

fn (mut stream ReadableByteStream) error(reason string) {
	if stream.state_ == .readable {
		stream.state_ = .errored
		stream.reason_ = reason
	}
}

enum TransformOwnerKind {
	compressor
	decompressor
}

@[heap]
pub struct WritableByteStream {
mut:
	owner_kind TransformOwnerKind
	owner      voidptr
	closed_    bool
}

pub fn (stream &WritableByteStream) is_closed() bool {
	return stream.closed_
}

pub fn (mut stream WritableByteStream) write(chunk []u8) ! {
	if stream.closed_ {
		return error('TypeError: Cannot write to a closed Compression stream')
	}
	match stream.owner_kind {
		.compressor {
			mut owner := unsafe { &CompressionStream(stream.owner) }
			owner.compress_and_enqueue_chunk(chunk)!
		}
		.decompressor {
			mut owner := unsafe { &DecompressionStream(stream.owner) }
			owner.decompress_and_enqueue_chunk(chunk)!
		}
	}
}

pub fn (mut stream WritableByteStream) close() ! {
	if stream.closed_ {
		return error('TypeError: Compression stream is already closed')
	}
	stream.closed_ = true
	match stream.owner_kind {
		.compressor {
			mut owner := unsafe { &CompressionStream(stream.owner) }
			owner.compress_flush_and_enqueue()!
		}
		.decompressor {
			mut owner := unsafe { &DecompressionStream(stream.owner) }
			owner.decompress_flush_and_enqueue()!
		}
	}
}

@[heap]
pub struct ByteTransformStream {
mut:
	readable_ &ReadableByteStream = unsafe { nil }
	writable_ &WritableByteStream = unsafe { nil }
}

fn ByteTransformStream.create(owner_kind TransformOwnerKind, owner voidptr) &ByteTransformStream {
	return &ByteTransformStream{
		readable_: &ReadableByteStream{}
		writable_: &WritableByteStream{
			owner_kind: owner_kind
			owner: owner
		}
	}
}

pub fn (stream &ByteTransformStream) readable() &ReadableByteStream {
	return stream.readable_
}

pub fn (stream &ByteTransformStream) writable() &WritableByteStream {
	return stream.writable_
}

@[heap]
pub struct CompressionStream {
mut:
	format_         CompressionFormat
	transform_      &ByteTransformStream = unsafe { nil }
	finished_       bool
	header_emitted_ bool
	adler32_        u32 = 1
	crc32_          u32 = 0xffff_ffff
	input_size_     u32
	input_          []u8
}

// https://compression.spec.whatwg.org/#dom-compressionstream-compressionstream
pub fn CompressionStream.construct_impl(format CompressionFormat) !&CompressionStream {
	return CompressionStream.create_for_constructor(format)
}

pub fn CompressionStream.create_for_constructor(format CompressionFormat) !&CompressionStream {
	return CompressionStream.create(format)
}

pub fn CompressionStream.create(format CompressionFormat) &CompressionStream {
	mut stream := &CompressionStream{
		format_: format
	}
	stream.transform_ = ByteTransformStream.create(.compressor, voidptr(stream))
	return stream
}

pub fn CompressionStream.construct_from_string(format string) !&CompressionStream {
	return CompressionStream.construct_impl(parse_compression_format(format)!)
}

pub fn (stream &CompressionStream) format() CompressionFormat {
	return stream.format_
}

pub fn (stream &CompressionStream) readable() &ReadableByteStream {
	return stream.transform_.readable()
}

pub fn (stream &CompressionStream) writable() &WritableByteStream {
	return stream.transform_.writable()
}

// https://compression.spec.whatwg.org/#compress-and-enqueue-a-chunk
fn (mut stream CompressionStream) compress_and_enqueue_chunk(chunk []u8) ! {
	if stream.finished_ {
		return error('TypeError: Compression stream has already finished')
	}
	buffer := stream.compress(chunk, false)!
	if buffer.len == 0 {
		return
	}
	mut readable := stream.transform_.readable_
	readable.enqueue(buffer)
}

// https://compression.spec.whatwg.org/#compress-flush-and-enqueue
fn (mut stream CompressionStream) compress_flush_and_enqueue() ! {
	if stream.finished_ {
		return error('TypeError: Compression stream has already finished')
	}
	stream.finished_ = true
	buffer := stream.compress([]u8{}, true)!
	mut readable := stream.transform_.readable_
	readable.enqueue(buffer)
	readable.close()
}

// CompressionStream::compress(). The native implementation delegates to
// LibCompress and returns all bytes produced by that invocation. This port
// emits standards-compliant uncompressed DEFLATE blocks so each write can be
// observed immediately without depending on a platform zlib stream object.
fn (mut stream CompressionStream) compress(bytes []u8, finish bool) ![]u8 {
	if stream.format_ == .brotli {
		stream.input_ << bytes
		if !finish {
			return []u8{}
		}
		return brotli.compress(stream.input_)!
	}
	mut output := []u8{}
	if !stream.header_emitted_ {
		match stream.format_ {
			.brotli {}
			.deflate {
				// CMF/FLG for deflate, 32 KiB window, fastest/no-compression level.
				output << [u8(0x78), 0x01]
			}
			.gzip {
				output << [u8(0x1f), 0x8b, 0x08, 0, 0, 0, 0, 0, 0, 0x03]
			}
			.deflate_raw {}
		}
		stream.header_emitted_ = true
	}

	if bytes.len > 0 {
		stream.adler32_ = update_adler32(stream.adler32_, bytes)
		stream.crc32_ = update_crc32(stream.crc32_, bytes)
		stream.input_size_ += u32(bytes.len)
		append_stored_deflate_blocks(mut output, bytes, false)
	}
	if finish {
		append_stored_deflate_blocks(mut output, []u8{}, true)
		match stream.format_ {
			.brotli {}
			.deflate {
				output << u8(stream.adler32_ >> 24)
				output << u8(stream.adler32_ >> 16)
				output << u8(stream.adler32_ >> 8)
				output << u8(stream.adler32_)
			}
			.gzip {
				append_u32_little_endian(mut output, stream.crc32_ ^ 0xffff_ffff)
				append_u32_little_endian(mut output, stream.input_size_)
			}
			.deflate_raw {}
		}
	}
	return output
}

fn append_stored_deflate_blocks(mut output []u8, bytes []u8, final bool) {
	if bytes.len == 0 {
		if final {
			output << [u8(0x01), 0x00, 0x00, 0xff, 0xff]
		}
		return
	}
	mut offset := 0
	for offset < bytes.len {
		length := if bytes.len - offset > 0xffff { 0xffff } else { bytes.len - offset }
		// Writes always use non-final blocks; flush appends the sole final block.
		output << u8(0x00)
		output << u8(length)
		output << u8(length >> 8)
		complement := u16(~u16(length))
		output << u8(complement)
		output << u8(complement >> 8)
		output << bytes[offset..offset + length]
		offset += length
	}
}

fn update_adler32(previous u32, bytes []u8) u32 {
	mut first := previous & 0xffff
	mut second := previous >> 16
	for byte in bytes {
		first = (first + byte) % 65521
		second = (second + first) % 65521
	}
	return (second << 16) | first
}

fn update_crc32(previous u32, bytes []u8) u32 {
	mut crc := previous
	for byte in bytes {
		crc ^= byte
		for _ in 0 .. 8 {
			crc = if crc & 1 != 0 { (crc >> 1) ^ 0xedb8_8320 } else { crc >> 1 }
		}
	}
	return crc
}

fn append_u32_little_endian(mut output []u8, value u32) {
	output << u8(value)
	output << u8(value >> 8)
	output << u8(value >> 16)
	output << u8(value >> 24)
}
