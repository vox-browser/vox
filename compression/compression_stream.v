// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Compression/CompressionStream.{h,cpp,idl} and the narrow
// GenericTransformStream surface it exposes.
module compression

import compress.deflate

pub enum CompressionFormat {
	deflate
	deflate_raw
	gzip
}

pub fn parse_compression_format(value string) !CompressionFormat {
	return match value {
		'deflate' { .deflate }
		'deflate-raw' { .deflate_raw }
		'gzip' { .gzip }
		else { error('TypeError: Unsupported compression format: ${value}') }
	}
}

pub fn compression_format_string(format CompressionFormat) string {
	return match format {
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
			owner:      owner
		}
	}
}

pub fn (stream &ByteTransformStream) readable() &ReadableByteStream {
	return stream.readable_
}

pub fn (stream &ByteTransformStream) writable() &WritableByteStream {
	return stream.writable_
}

fn encode_bytes(format CompressionFormat, bytes []u8) ![]u8 {
	return match format {
		.deflate { deflate.compress(bytes, format: .zlib)! }
		.deflate_raw { deflate.compress(bytes, format: .raw_deflate)! }
		.gzip { deflate.compress(bytes, format: .gzip)! }
	}
}

@[heap]
pub struct CompressionStream {
mut:
	format_    CompressionFormat
	transform_ &ByteTransformStream = unsafe { nil }
	input_     []u8
	finished_  bool
}

// https://compression.spec.whatwg.org/#dom-compressionstream-compressionstream
pub fn CompressionStream.construct_impl(format CompressionFormat) !&CompressionStream {
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
	// LibCompress may buffer a whole input chunk. The pure-V codec similarly
	// buffers until flush, while retaining the same format context and output.
	stream.input_ << chunk
}

// https://compression.spec.whatwg.org/#compress-flush-and-enqueue
fn (mut stream CompressionStream) compress_flush_and_enqueue() ! {
	if stream.finished_ {
		return error('TypeError: Compression stream has already finished')
	}
	stream.finished_ = true
	buffer := encode_bytes(stream.format_, stream.input_) or {
		reason := 'TypeError: Unable to compress flush: ${err}'
		mut readable := stream.transform_.readable_
		readable.error(reason)
		return error(reason)
	}
	mut readable := stream.transform_.readable_
	readable.enqueue(buffer)
	readable.close()
}
