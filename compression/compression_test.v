module compression

import encoding.hex

fn compressed_hello(format CompressionFormat) []u8 {
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

fn test_parse_compression_formats() {
	assert parse_compression_format('br')! == .brotli
	assert parse_compression_format('deflate')! == .deflate
	assert parse_compression_format('deflate-raw')! == .deflate_raw
	assert parse_compression_format('gzip')! == .gzip
	assert compression_format_string(.brotli) == 'br'
	assert compression_format_string(.deflate) == 'deflate'
	assert compression_format_string(.deflate_raw) == 'deflate-raw'
	assert compression_format_string(.gzip) == 'gzip'

	if _ := parse_compression_format('zstd') {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
}

fn test_compression_and_decompression_round_trip_all_formats() {
	input := 'Ladybird CompressionStream: hello from several chunks.'.bytes()
	for format in [CompressionFormat.brotli, .deflate, .deflate_raw, .gzip] {
		mut compressor := CompressionStream.construct_impl(format)!
		mut compressor_writable := compressor.writable()
		compressor_writable.write(input[..9])!
		assert compressor.readable().chunk_count() == if format == .brotli { 0 } else { 1 }
		compressor_writable.write(input[9..31])!
		assert compressor.readable().chunk_count() == if format == .brotli { 0 } else { 2 }
		compressor_writable.write(input[31..])!
		assert compressor.readable().chunk_count() == if format == .brotli { 0 } else { 3 }
		compressor_writable.close()!
		assert compressor_writable.is_closed()
		assert compressor.readable().state() == .closed
		mut compressor_readable := compressor.readable()
		encoded := compressor_readable.read_all()
		assert encoded.len > 0

		mut decompressor := DecompressionStream.construct_impl(format)!
		mut decompressor_writable := decompressor.writable()
		for byte in encoded {
			decompressor_writable.write([byte])!
		}
		assert decompressor.readable().chunk_count() == 1
		decompressor_writable.close()!
		assert decompressor.readable().state() == .closed
		mut decompressor_readable := decompressor.readable()
		assert decompressor_readable.read_all() == input
	}
}

fn test_decompression_accepts_external_format_vectors() {
	for format in [CompressionFormat.brotli, .deflate, .deflate_raw, .gzip] {
		mut stream := DecompressionStream.construct_impl(format)!
		mut writable := stream.writable()
		writable.write(compressed_hello(format))!
		assert stream.readable().chunk_count() == 1
		writable.close()!
		mut readable := stream.readable()
		assert readable.read_all().bytestr() == 'hello'
	}
}

fn test_brotli_decodes_external_compressed_html_with_dictionary_and_utf8() {
	// Node's native Brotli encoder, quality 11; independent of our V encoder.
	encoded := hex.decode('1b7300008c94acf5893a84054e50eaf0f838e5c0a5057108f55d0e76cfe173704a94da26b0e07f3dc1840a57b85439a179f9f8df7b2e231c0d')!
	mut stream := DecompressionStream.construct_from_string('br')!
	mut writable := stream.writable()
	for byte in encoded {
		writable.write([byte])!
	}
	writable.close()!
	assert stream.readable().state() == .closed
	mut readable := stream.readable()
	assert readable.read_all().bytestr() == '<!doctype html><meta charset="utf-8"><p>Compression dictionary: international information. Привет, 世界!</p>'
}

fn test_brotli_round_trips_large_binary_input() {
	// Exercise sizes beyond vlib's optional native-encoder threshold (4096).
	input := []u8{len: 8193, init: u8(index % 251)}
	mut compressor := CompressionStream.construct_from_string('br')!
	mut writable := compressor.writable()
	writable.write(input[..4096])!
	writable.write(input[4096..])!
	writable.close()!
	mut encoded := compressor.readable()
	mut decompressor := DecompressionStream.construct_from_string('br')!
	mut decoder := decompressor.writable()
	decoder.write(encoded.read_all())!
	decoder.close()!
	mut decoded := decompressor.readable()
	assert decoded.read_all() == input
}

fn test_empty_input_round_trips_all_formats() {
	for format in [CompressionFormat.brotli, .deflate, .deflate_raw, .gzip] {
		mut compressor := CompressionStream.construct_impl(format)!
		mut compressor_writable := compressor.writable()
		compressor_writable.close()!
		mut compressor_readable := compressor.readable()
		encoded := compressor_readable.read_all()
		assert encoded.len > 0

		mut decompressor := DecompressionStream.construct_impl(format)!
		mut decompressor_writable := decompressor.writable()
		decompressor_writable.write(encoded)!
		decompressor_writable.close()!
		assert decompressor.readable().state() == .closed
		assert decompressor.readable().chunk_count() == 0
	}
}

fn test_decompression_errors_the_readable_stream_for_invalid_input() {
	for format in [CompressionFormat.brotli, .deflate, .deflate_raw, .gzip] {
		mut stream := DecompressionStream.construct_impl(format)!
		mut writable := stream.writable()
		writable.write([u8(0xde), 0xad, 0xbe, 0xef])!
		if _ := writable.close() {
			assert false
		} else {
			assert err.msg().starts_with('TypeError: Unable to decompress flush:')
		}
		assert stream.readable().state() == .errored
		assert stream.readable().reason().starts_with('TypeError:')
	}
}

fn test_raw_deflate_rejects_trailing_bytes() {
	mut stream := DecompressionStream.construct_impl(.deflate_raw)!
	mut writable := stream.writable()
	mut encoded := compressed_hello(.deflate_raw)
	encoded << u8(0xff)
	writable.write(encoded)!
	if _ := writable.close() {
		assert false
	} else {
		assert err.msg().contains('trailing bytes')
	}
	assert stream.readable().state() == .errored
}

fn test_writable_stream_rejects_operations_after_close() {
	mut stream := CompressionStream.construct_from_string('gzip')!
	mut writable := stream.writable()
	writable.write('ok'.bytes())!
	writable.close()!
	if _ := writable.write('late'.bytes()) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	if _ := writable.close() {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
}
