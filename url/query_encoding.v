module url

import strings

// Encodes one code point in a legacy encoding: its bytes, or none when the
// encoding cannot represent it.
pub type QueryEncoder = fn (code_point u32) ?[]u8

// The encoding module registers its encoders here; url cannot import it.
__global url_query_encoders = map[string]QueryEncoder{}

pub fn register_query_encoder(name string, encoder QueryEncoder) {
	url_query_encoders[name.to_lower()] = encoder
}

fn query_encoder_for(encoding string) ?QueryEncoder {
	name := encoding.to_lower()
	if name == '' || name == 'utf-8' {
		return none
	}
	return url_query_encoders[name] or { return none }
}

// https://url.spec.whatwg.org/#string-percent-encode-after-encoding with a
// legacy encoding. A code point the encoding cannot represent is written as
// its percent-encoded numeric character reference.
fn percent_encode_after_encoding(input string, encoder QueryEncoder, set PercentEncodeSet) string {
	mut output := strings.new_builder(input.len)
	for character in input.runes() {
		code_point := u32(character)
		bytes := encoder(code_point) or {
			output.write_string('%26%23${code_point}%3B')
			continue
		}
		for value in bytes {
			if value < 0x80 && !code_point_is_in_percent_encode_set(u32(value), set) {
				output.write_u8(value)
			} else {
				output.write_string('%${value:02X}')
			}
		}
	}
	return output.str()
}
