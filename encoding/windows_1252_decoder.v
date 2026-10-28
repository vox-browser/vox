// Source Windows1252 is a SingleByteDecoder with its registered table.
module encoding

struct Windows1252Decoder {}

fn (_ Windows1252Decoder) decode_to_utf8_raw(input []u8, mut output []u8, last bool) (SingleByteDecoderResult, int, int) {
	decoder := SourceSingleByteDecoder{ table: single_byte_windows_1252 }
	return decoder.decode_to_utf8_raw(input, mut output, last)
}

$if test {
	fn decode_windows_1252_to_utf8(input []u8) string {
		return decode_source_single_byte_to_utf8(input, single_byte_windows_1252, false) or {
			panic('Source VERIFY: Windows1252 contains no undefined input bytes')
		}
	}
}
