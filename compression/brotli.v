// SPDX-License-Identifier: BSD-2-Clause
module compression

import x.compress.brotli

// Decodes the Brotli stream at the start of data, like a streaming decoder
// that stops at the stream's last meta-block. vlib's V decoder rejects bytes
// after the stream, so locate its end by decoding prefixes: shorter prefixes
// are truncated and longer ones carry trailing data.
fn brotli_decode_leading_stream(data []u8) !LeadingStream {
	mut message := ''
	whole := brotli.decompress(data) or {
		message = err.msg()
		[]u8{}
	}
	if message == '' {
		return LeadingStream{whole, data.len}
	}
	if !message.contains('trailing data') {
		return error(message)
	}
	mut low := 1
	mut high := data.len - 1
	for low <= high {
		middle := low + (high - low) / 2
		message = ''
		decoded := brotli.decompress(unsafe { data[..middle] }) or {
			message = err.msg()
			[]u8{}
		}
		if message == '' {
			return LeadingStream{decoded, middle}
		}
		if message.contains('trailing data') {
			high = middle - 1
		} else if message.contains('truncated') {
			low = middle + 1
		} else {
			return error(message)
		}
	}
	return error('brotli: stream end not found')
}

// The V decoder reports every read past the available input as truncation.
fn brotli_error_is_truncation(err IError) bool {
	return err.msg().contains('truncated')
}

// CompressionStream('brotli') used libbrotlienc quality 5 with a 4 MiB window.
fn encode_brotli(input []u8) ![]u8 {
	return brotli.compress(input, quality: 5, window_size: 22) or {
		return error('TypeError: Unable to compress Brotli input')
	}
}
