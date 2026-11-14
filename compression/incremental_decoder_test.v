module compression

import compress.deflate

fn incremental_hello(format CompressionFormat) []u8 {
	return match format {
		.brotli {
			[u8(0x0f), 0x02, 0x80, 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x03]
		}
		.deflate {
			[u8(0x78), 0x9c, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x06, 0x2c, 0x02, 0x15]
		}
		.deflate_raw {
			[u8(0xcb), 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00]
		}
		.gzip {
			[u8(0x1f), 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0xcb, 0x48, 0xcd, 0xc9,
				0xc9, 0x07, 0x00, 0x86, 0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00]
		}
	}
}


fn test_incremental_decoder_preserves_output_before_rejecting_trailing_input() {
	for format in [CompressionFormat.brotli, .deflate, .deflate_raw, .gzip] {
		mut decoder := IncrementalDecompressor.create(format)!
		defer { decoder.close() }
		mut bytes := incremental_hello(format)
		bytes << u8(0)
		result := decoder.push(bytes, false)
		assert result.bytes.bytestr() == 'hello'
		assert result.complete
		assert result.error_message.starts_with('TypeError: Extra input')
	}
}

fn test_incremental_decoder_handles_split_headers_large_output_and_late_extra_input() {
	input := []u8{len: 160001, init: u8(index % 251)}
	for format in [CompressionFormat.brotli, .deflate, .deflate_raw, .gzip] {
		mut encoder := CompressionStream.construct_impl(format)!
		mut writable := encoder.writable()
		writable.write(input)!
		writable.close()!
		mut readable := encoder.readable()
		encoded := readable.read_all()
		mut decoder := IncrementalDecompressor.create(format)!
		defer { decoder.close() }
		mut actual := []u8{}
		for byte in encoded[..3] {
			part := decoder.push([byte], false)
			assert part.error_message == ''
			actual << part.bytes
		}
		part := decoder.push(encoded[3..], false)
		assert part.complete && part.error_message == ''
		actual << part.bytes
		assert actual == input
		assert decoder.push([], true).error_message == ''
		assert decoder.push([u8(0)], false).error_message.starts_with('TypeError: Extra input')
	}
}

fn test_incremental_decoder_requires_end_marker_and_checks_corruption() {
	for format in [CompressionFormat.brotli, .deflate, .deflate_raw, .gzip] {
		mut decoder := IncrementalDecompressor.create(format)!
		encoded := incremental_hello(format)
		part := decoder.push(encoded[..encoded.len - 1], false)
		assert part.error_message == ''
		assert !part.complete
		assert decoder.push([], true).error_message == 'TypeError: Incomplete compressed input'
	}
	mut decoder := IncrementalDecompressor.create(.gzip)!
	assert decoder.push([u8(0), 1, 2, 3], false).error_message == 'TypeError: Invalid compressed input'
}

fn test_incremental_brotli_decoder_completes_from_small_chunks() {
	input := []u8{len: 70000, init: u8((index * 7) % 253)}
	mut encoder := CompressionStream.construct_impl(.brotli)!
	mut writable := encoder.writable()
	writable.write(input)!
	writable.close()!
	mut readable := encoder.readable()
	encoded := readable.read_all()
	mut decoder := IncrementalDecompressor.create(.brotli)!
	defer { decoder.close() }
	mut actual := []u8{}
	mut offset := 0
	for offset < encoded.len {
		end := if offset + 7 < encoded.len { offset + 7 } else { encoded.len }
		part := decoder.push(encoded[offset..end], false)
		assert part.error_message == ''
		actual << part.bytes
		offset = end
	}
	finished := decoder.push([], true)
	assert finished.error_message == '' && finished.complete
	actual << finished.bytes
	assert actual == input
}

fn test_brotli_leading_stream_reports_its_length() {
	mut bytes := incremental_hello(.brotli)
	stream_length := bytes.len
	bytes << [u8(1), 2, 3]
	stream := brotli_decode_leading_stream(bytes)!
	assert stream.data.bytestr() == 'hello'
	assert stream.consumed == stream_length
	// WBITS bits 1, 000, 001 then a set reserved bit: an invalid large-window marker.
	if _ := brotli_decode_leading_stream([u8(0x91)]) {
		assert false
	} else {
		assert !brotli_error_is_truncation(err)
	}
}

// Real Huffman-coded streams fed one byte at a time: prefixes that end inside a
// code, a header or a trailer wait for more input instead of failing.
fn test_incremental_zlib_family_decoders_complete_from_single_bytes() {
	input := []u8{len: 20000, init: u8((index * 13 + index / 97) % 61 + 32)}
	for format in [CompressionFormat.deflate, .deflate_raw, .gzip] {
		encoded := match format {
			.deflate { deflate.compress_zlib(input)! }
			.gzip { deflate.compress_gzip(input)! }
			else { deflate.compress_raw(input)! }
		}
		mut decoder := IncrementalDecompressor.create(format)!
		defer { decoder.close() }
		mut actual := []u8{}
		for i, byte in encoded {
			part := decoder.push([byte], false)
			assert part.error_message == '', '${format} ${i}'
			assert part.complete == (i == encoded.len - 1) || part.complete == false
			actual << part.bytes
		}
		finished := decoder.push([], true)
		assert finished.error_message == '', '${format}'
		actual << finished.bytes
		assert actual == input, '${format}'
	}
}

fn test_leading_zlib_family_streams_report_their_length() {
	for format in [CompressionFormat.deflate, .deflate_raw, .gzip] {
		mut bytes := incremental_hello(format)
		stream_length := bytes.len
		bytes << [u8(0x1f), 0x8b, 9]
		stream := decode_leading_stream(format, bytes)!
		assert stream.data.bytestr() == 'hello'
		assert stream.consumed == stream_length
	}
	mut corrupt := incremental_hello(.gzip)
	corrupt[corrupt.len - 8] ^= 1
	if _ := decode_leading_stream(.gzip, corrupt) {
		assert false
	} else {
		assert err.msg().contains('crc32 mismatch')
	}
}
