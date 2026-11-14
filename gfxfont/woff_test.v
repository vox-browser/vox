module gfxfont

// testdata retains the pinned upstream TestWOFF/TestWOFF2 malformed inputs,
// LibWeb/Assets/HashSans.woff and Screenshot/data/variable-font-example.woff2.

import crypto.sha256
import encoding.binary
import os

fn source_font_fixture(name string) []u8 {
	return os.read_bytes(os.join_path(os.dir(@FILE), 'testdata', name)) or { panic(err) }
}

fn test_source_woff_font_decodes_with_retained_sfnt_table_directory() {
	compressed := source_font_fixture('HashSans.woff')
	font := convert_woff_to_sfnt(compressed)!
	assert font.len == int(binary.big_endian_u32_at(compressed, 16))
	assert binary.big_endian_u32(font) == binary.big_endian_u32_at(compressed, 4)
	assert binary.big_endian_u16_at(font, 4) == binary.big_endian_u16_at(compressed, 12)
	assert typeface_data_is_valid(font, 0)
}

struct WoffMutation {
	offset  int
	value   u32
	message string
}

fn test_source_woff_rejects_invalid_headers_and_table_lengths() {
	valid := source_font_fixture('HashSans.woff')
	for setting in [
		WoffMutation{0, 0, 'Invalid WOFF signature'},
		WoffMutation{8, u32(valid.len + 1), 'Invalid WOFF length'},
		WoffMutation{16, 0, 'Invalid WOFF total sfnt size'},
		WoffMutation{16, 10 * 1024 * 1024 + 1, 'Uncompressed font is more than 10 MiB'},
		WoffMutation{24, 1, 'Invalid WOFF meta block offset'},
		WoffMutation{36, 1, 'Invalid WOFF private block offset'},
		WoffMutation{48, u32(valid.len), 'Truncated WOFF table'},
	] {
		mut data := valid.clone()
		binary.big_endian_put_u32_at(mut data, setting.value, setting.offset)
		if _ := convert_woff_to_sfnt(data) {
			assert false, 'source rejected field ${setting.offset}'
		} else {
			assert err.msg() == setting.message
		}
	}
	for data in [valid[..43], source_font_fixture('invalid_sfnt_size.woff')] {
		if _ := convert_woff_to_sfnt(data) { assert false
		 }
	}
}

fn test_source_woff_aligns_table_offsets_and_keeps_header_search_calculation() {
	// A small source-conversion fixture observes four-byte table alignment;
	// font validity is checked separately by the actual Skia decoder above.
	mut data := []u8{len: 109}
	binary.big_endian_put_u32_at(mut data, 0x774f4646, 0)
	binary.big_endian_put_u32_at(mut data, 0x00010000, 4)
	binary.big_endian_put_u32_at(mut data, 109, 8)
	binary.big_endian_put_u16_at(mut data, 3, 12)
	binary.big_endian_put_u32_at(mut data, 72, 16)
	for i in 0 .. 3 {
		directory := 44 + i * 20
		binary.big_endian_put_u32_at(mut data, u32(i + 1), directory)
		binary.big_endian_put_u32_at(mut data, u32(104 + i), directory + 4)
		binary.big_endian_put_u32_at(mut data, 1, directory + 8)
		binary.big_endian_put_u32_at(mut data, 1, directory + 12)
		data[104 + i] = u8(65 + i)
	}
	font := convert_woff_to_sfnt(data)!
	assert binary.big_endian_u16_at(font, 6) == 64
	assert binary.big_endian_u16_at(font, 8) == 2
	assert binary.big_endian_u16_at(font, 10) == u16(65520)
	assert binary.big_endian_u32_at(font, 20) == 60
	assert binary.big_endian_u32_at(font, 36) == 64
	assert binary.big_endian_u32_at(font, 52) == 68
	assert font[60..72] == [u8(`A`), 0, 0, 0, `B`, 0, 0, 0, `C`, 0, 0, 0]
}

fn test_source_woff2_decoder_accepts_valid_fonts_and_tolerates_incorrect_declared_sfnt_size() {
	font := convert_woff2_to_sfnt(source_font_fixture('variable-font-example.woff2'))!
	assert typeface_data_is_valid(font, 0)
	tolerated := convert_woff2_to_sfnt(source_font_fixture('incorrect_sfnt_size.woff2'))!
	assert typeface_data_is_valid(tolerated, 0)
	for name, message in {
		'incorrect_compressed_size.woff2': 'Failed to convert the WOFF2 font to TTF'
		// The bounded directory parser rejects this before native decoding.
		'invalid_numtables.woff2': 'UIntBase128 overflow'
	} {
		if _ := convert_woff2_to_sfnt(source_font_fixture(name)) {
			assert false, name
		} else {
			assert err.msg() == message
		}
	}
}

fn test_v_woff2_decoder_matches_libwoff2_output() {
	// SHA-256 of the sfnt bytes Google's libwoff2 1.0.2 produced for these fixtures.
	for name, expected in {
		'variable-font-example.woff2': '8fb025fefe7ef6faf3e3f5bdf12b42dd4dabf759ddb534c821e3489917eae9ab'
		'incorrect_sfnt_size.woff2':   '0e8f88ad1512e41df1363911bb8744798706760c29be2dded81063da5dc9463c'
	} {
		assert sha256.sum(convert_woff2_to_sfnt(source_font_fixture(name))!).hex() == expected, name
	}
}

fn test_v_woff2_decoder_ignores_bytes_after_the_brotli_stream() {
	// libwoff2 stops at the Brotli stream's last meta-block, so a compressed
	// block with four extra bytes after the stream decodes the same font.
	valid := source_font_fixture('variable-font-example.woff2')
	expected := convert_woff2_to_sfnt(valid)!
	mut padded := valid.clone()
	padded << [u8(0), 0, 0, 0]
	binary.big_endian_put_u32_at(mut padded, u32(padded.len), 8)
	binary.big_endian_put_u32_at(mut padded, binary.big_endian_u32_at(valid, 20) + 4, 20)
	assert convert_woff2_to_sfnt(padded)! == expected
}

fn test_v_woff2_writer_preserves_output_limit() {
	mut out := Woff2Out{}
	if _ := out.write_at([u8(1)], int(woff2_max_output_size)) {
		assert false, 'oversized write must fail before allocation'
	}
	assert out.data.len == 0
	out.data = []u8{len: int(woff2_max_output_size)}
	if _ := out.write([u8(1)]) {
		assert false, 'append past output limit must fail'
	}
	assert out.data.len == int(woff2_max_output_size)
}
