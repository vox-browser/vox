module libjs

import os
import strconv
import encoding.hex

fn test_translated_base64_codec_matches_pinned_simdutf_output_status_and_utf16_read_counts() {
	fixture := os.read_file(os.join_path(os.dir(@DIR), 'libjs', 'testdata', 'base64-codec.tsv'))!
	mut count := 0
	for line in fixture.split_into_lines() {
		if line.starts_with('#') || line == '' { continue
		 }
		fields := line.split('|')
		assert fields.len == 7
		mut units := []u16{}
		for position := 0; position < fields[0].len; position += 4 {
			units << u16(strconv.parse_uint(fields[0][position..position + 4], 16, 16)!)
		}
		alphabet := if fields[1] == '0' { Base64Alphabet.base64 } else { Base64Alphabet.base64url }
		handling := [Base64LastChunkHandling.loose, .strict, .stop_before_partial][fields[2].int()]
		result := decode_base64_codec(units, uint(fields[3].u64()), alphabet, handling)
		assert result.error.str() == fields[4], 'status: ${line}, got ${result.error}'
		assert result.read == uint(fields[5].u64()), 'read: ${line}, got ${result.read}'
		assert result.bytes == hex.decode(fields[6])!, 'bytes: ${line}'
		count++
	}
	assert count > 10000
}

fn test_translated_base64_encoder_retains_alphabets_padding_and_byte_boundaries() {
	vectors := {
		'':        ''
		'f':       'Zg=='
		'fo':      'Zm8='
		'foo':     'Zm9v'
		'foob':    'Zm9vYg=='
		'fooba':   'Zm9vYmE='
		'foobar':  'Zm9vYmFy'
		'🤓':      '8J+kkw=='
		'🤓foo🖖': '8J+kk2Zvb/CflpY='
	}
	for input, expected in vectors {
		for alphabet in [Base64Alphabet.base64, .base64url] {
			encoded := if alphabet == .base64 {
				expected
			} else {
				expected.replace('+', '-').replace('/', '_')
			}
			for omit_padding in [false, true] {
				assert encode_base64_codec(input.bytes(), alphabet, omit_padding).str() == if omit_padding {
					encoded.trim_right('=')
				} else {
					encoded
				}
			}
		}
	}
	mut bytes := []u8{}
	for byte in 0 .. 256 {
		bytes << u8(byte)
	}
	for alphabet in [Base64Alphabet.base64, .base64url] {
		for omit_padding in [false, true] {
			encoded := encode_base64_codec(bytes, alphabet, omit_padding)
			result := decode_base64_codec(encoded.as_slice(), uint(bytes.len), alphabet, .loose)
			assert result.error == .success && result.bytes == bytes
		}
	}
}
