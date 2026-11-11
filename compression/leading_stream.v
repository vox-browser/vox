// SPDX-License-Identifier: BSD-2-Clause
module compression

import compress.deflate
import encoding.binary
import hash.adler32
import hash.crc32

// A compressed stream decoded from the start of a buffer, and the number of
// buffer bytes it occupies; anything after it is trailing input.
struct LeadingStream {
	data     []u8
	consumed int
}

fn decode_leading_stream(format CompressionFormat, data []u8) !LeadingStream {
	return match format {
		.brotli { brotli_decode_leading_stream(data)! }
		.deflate { inflate_leading_zlib(data)! }
		.deflate_raw { inflate_leading_raw(data, 0)! }
		.gzip { inflate_leading_gzip(data)! }
	}
}

// Whether a decoding error can be cured by more input. The V decoders report a
// read past the available input as truncation. A short DEFLATE prefix can also
// end inside a Huffman code whose missing bits select no symbol, so before the
// input is finished that error waits for more input too.
fn stream_error_needs_more_input(format CompressionFormat, err IError, finish bool) bool {
	message := err.msg()
	if format == .brotli {
		return brotli_error_is_truncation(err)
	}
	return message.contains('unexpected end of stream') || message.contains('truncated')
		|| message.contains('too short') || (!finish && message.contains('invalid Huffman code'))
}

// Raw DEFLATE (RFC 1951) starting at `start`; consumed includes the prefix.
fn inflate_leading_raw(data []u8, start int) !LeadingStream {
	result := deflate.decompress_raw_with_consumed(data[start..])!
	return LeadingStream{result.decoded, start + result.consumed}
}

// zlib (RFC 1950): two header bytes, DEFLATE data, then a big-endian Adler-32.
fn inflate_leading_zlib(data []u8) !LeadingStream {
	// Reject a wrong compression method before the second header byte arrives.
	if data.len == 1 && data[0] & 0x0f != 8 {
		return error('invalid zlib stream: unsupported compression method')
	}
	deflate.validate_zlib_header(data)!
	body := inflate_leading_raw(data, 2)!
	if body.consumed + 4 > data.len {
		return error('invalid zlib stream: truncated adler32')
	}
	if adler32.sum(body.data) != binary.big_endian_u32_at(data, body.consumed) {
		return error('invalid zlib stream: adler32 mismatch')
	}
	return LeadingStream{body.data, body.consumed + 4}
}

// One gzip member (RFC 1952), as a zlib inflater with gzip framing decodes it:
// a following member is trailing input.
fn inflate_leading_gzip(data []u8) !LeadingStream {
	// The header validator wants a whole minimal member first; reject a wrong
	// magic or compression method as soon as those bytes arrive.
	for i, expected in [u8(0x1f), 0x8b, 8] {
		if i < data.len && data[i] != expected {
			return error('invalid gzip stream: bad magic')
		}
	}
	header := deflate.validate_gzip_header(data)!
	body := inflate_leading_raw(data, header.payload_start)!
	if body.consumed + 8 > data.len {
		return error('invalid gzip stream: truncated trailer')
	}
	if crc32.sum(body.data) != binary.little_endian_u32_at(data, body.consumed) {
		return error('invalid gzip stream: crc32 mismatch')
	}
	if u32(body.data.len) != binary.little_endian_u32_at(data, body.consumed + 4) {
		return error('invalid gzip stream: size mismatch')
	}
	return LeadingStream{body.data, body.consumed + 8}
}
