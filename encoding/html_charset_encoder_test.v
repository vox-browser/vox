module encoding

import encoding.hex
import x.json2

struct HTMLCharsetVector {
	input string
	encodings map[string]string
}

fn test_html_charset_encoders_match_unchanged_upstream_upload_vectors() {
	vector := json2.decode[HTMLCharsetVector]($embed_file('@VMODROOT/encoding/fixtures/html_form_first100_vectors.json').to_string())!
	for label, expected in vector.encodings {
		encoder := HTMLCharsetEncoder.create(label)!
		assert hex.encode(encoder.encode(vector.input)!) == expected, label
	}
}

fn test_html_iso_2022_jp_switches_state_and_replaces_unsafe_controls() {
	encoder := HTMLCharsetEncoder.create('ISO-2022-JP')!
	assert encoder.encode('¥😀¥')!.bytestr() == '\x1b(J\\&#128512;\\\x1b(B'
	assert encoder.encode('星😀星')!.bytestr() == '\x1b$B@1\x1b(B&#128512;\x1b$B@1\x1b(B'
	assert encoder.encode('\x0e\x0f\x1b')!.bytestr() == '&#65533;&#65533;&#65533;'
	assert encoder.encode('星\x1bA')!.bytestr() == '\x1b$B@1\x1b(B&#65533;A'
	assert encoder.encode('abc\\~')!.bytestr() == 'abc\\~'
}

fn test_html_single_byte_encoder_inverts_defined_index_entries_and_uses_scalar_references() {
	for label in ['windows-1252', 'iso-8859-2', 'windows-1251', 'koi8-r'] {
		encoder := HTMLCharsetEncoder.create(label)!
		table := source_single_byte_table(label) or { panic('single-byte index') }
		for scalar in table {
			if scalar == 0 { continue }
			bytes := encoder.encode(rune(scalar).str())!
			assert bytes.len == 1 && table[int(bytes[0]) - 128] == scalar
		}
		assert encoder.encode('😀')!.bytestr() == '&#128512;'
	}
	user := HTMLCharsetEncoder.create('x-user-defined')!
	assert user.encode('A\uF780\uF7FF😀')! == ('A'+[u8(128),255].bytestr()+'&#128512;').bytes()
	utf8 := HTMLCharsetEncoder.create('utf-16le')!
	assert utf8.encode('A😀\x00')! == 'A😀\x00'.bytes()
}
