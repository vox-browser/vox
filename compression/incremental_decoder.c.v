module compression

#flag -lz
#include "@VMODROOT/compression/native_decoder.h"

fn C.vox_decompression_create(i32) voidptr
fn C.vox_decompression_destroy(voidptr)
fn C.vox_decompression_step(voidptr, &u8, uint, &uint, &u8, uint, &uint) i32

pub struct DecompressionOutput {
pub:
	bytes []u8
	error_message string
	complete bool
}

// One codec context per stream. The output and terminal error are separate:
// a pending reader can receive decoded bytes before trailing input errors it.
@[heap]
pub struct IncrementalDecompressor {
mut:
	format CompressionFormat
	context voidptr
	// Brotli input buffered for the whole-stream V decoder, and its length at
	// the last decoding attempt.
	brotli_input []u8
	brotli_attempted int
	closed bool
	complete bool
	failed bool
}

pub fn IncrementalDecompressor.create(format CompressionFormat) !&IncrementalDecompressor {
	if format == .brotli { return &IncrementalDecompressor{format: format} }
	context := C.vox_decompression_create(i32(format))
	if context == unsafe { nil } { return error('TypeError: Unable to create decompressor') }
	return &IncrementalDecompressor{format: format, context: context}
}

pub fn (mut decoder IncrementalDecompressor) close() {
	if decoder.context != unsafe { nil } {
		C.vox_decompression_destroy(decoder.context)
		decoder.context = unsafe { nil }
	}
	decoder.brotli_input = []u8{}
	decoder.closed = true
}

// Decodes buffered Brotli input once the stream is complete. Re-decoding is
// linear in the buffered size, so wait for 25% growth between attempts unless
// the input is finished; the total work stays linear in the stream size.
fn (mut decoder IncrementalDecompressor) push_brotli(input []u8, finish bool) ([]u8, string) {
	decoder.brotli_input << input
	buffered := decoder.brotli_input.len
	if buffered == 0 || (!finish && decoder.brotli_attempted > 0
		&& buffered - decoder.brotli_attempted < decoder.brotli_attempted / 4) {
		return []u8{}, ''
	}
	decoder.brotli_attempted = buffered
	stream := brotli_decode_leading_stream(decoder.brotli_input) or {
		if brotli_error_is_truncation(err) { return []u8{}, '' }
		return []u8{}, 'TypeError: Invalid compressed input'
	}
	decoder.complete = true
	decoder.brotli_input = []u8{}
	if stream.consumed != buffered {
		return stream.data, 'TypeError: Extra input after the compressed stream'
	}
	return stream.data, ''
}

pub fn (mut decoder IncrementalDecompressor) push(input []u8, finish bool) DecompressionOutput {
	mut output := []u8{}
	mut failure := ''
	if decoder.failed || (decoder.complete && input.len > 0) {
		failure = 'TypeError: Extra input after the compressed stream'
	} else if !decoder.complete && decoder.closed {
		failure = 'TypeError: Decompression stream is closed'
	} else if !decoder.complete && decoder.format == .brotli {
		output, failure = decoder.push_brotli(input, finish)
	} else if !decoder.complete {
		mut offset := 0
		for {
			mut block := []u8{len: 65536}
			remaining := input[offset..]
			mut consumed := uint(0)
			mut produced := uint(0)
			status := C.vox_decompression_step(decoder.context, remaining.data, uint(remaining.len),
				&consumed, block.data, uint(block.len), &produced)
			output << block[..int(produced)]
			offset += int(consumed)
			if status == 1 {
				decoder.complete = true
				if offset != input.len { failure = 'TypeError: Extra input after the compressed stream' }
				break
			}
			if status < 0 { failure = 'TypeError: Invalid compressed input'; break }
			if status != 2 && offset == input.len { break }
			if consumed == 0 && produced == 0 { failure = 'TypeError: Invalid compressed input'; break }
		}
	}
	if finish && !decoder.complete && failure == '' { failure = 'TypeError: Incomplete compressed input' }
	if failure != '' { decoder.failed = true }
	if decoder.complete || decoder.failed || finish { decoder.close() }
	return DecompressionOutput{bytes: output, error_message: failure, complete: decoder.complete}
}
