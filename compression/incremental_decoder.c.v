module compression

#flag -lz
$if windows {
	#flag -lbrotlidec
	#flag -lbrotlienc
} $else {
	#pkgconfig libbrotlidec libbrotlienc
}
#include "@VMODROOT/compression/native_decoder.h"

fn C.vox_decompression_create(i32) voidptr
fn C.vox_decompression_destroy(voidptr)
fn C.vox_decompression_step(voidptr, &u8, uint, &uint, &u8, uint, &uint) i32
fn C.vox_brotli_encoded_bound(uint) uint
fn C.vox_brotli_encode(&u8, uint, &u8, &uint) i32

fn encode_brotli(input []u8) ![]u8 {
	mut capacity := C.vox_brotli_encoded_bound(uint(input.len))
	mut output := []u8{len: int(capacity)}
	if C.vox_brotli_encode(input.data, uint(input.len), output.data, &capacity) == 0 {
		return error('TypeError: Unable to compress Brotli input')
	}
	return output[..int(capacity)]
}

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
	context voidptr
	complete bool
	failed bool
}

pub fn IncrementalDecompressor.create(format CompressionFormat) !&IncrementalDecompressor {
	context := C.vox_decompression_create(i32(format))
	if context == unsafe { nil } { return error('TypeError: Unable to create decompressor') }
	return &IncrementalDecompressor{context: context}
}

pub fn (mut decoder IncrementalDecompressor) close() {
	if decoder.context != unsafe { nil } {
		C.vox_decompression_destroy(decoder.context)
		decoder.context = unsafe { nil }
	}
}

pub fn (mut decoder IncrementalDecompressor) push(input []u8, finish bool) DecompressionOutput {
	mut output := []u8{}
	mut failure := ''
	if decoder.failed || (decoder.complete && input.len > 0) {
		failure = 'TypeError: Extra input after the compressed stream'
	} else if !decoder.complete && decoder.context == unsafe { nil } {
		failure = 'TypeError: Decompression stream is closed'
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
