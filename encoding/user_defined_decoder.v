// Copyright Mozilla Foundation
//
// Permission is hereby granted, free of charge, to any
// person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the
// Software without restriction, including without
// limitation the rights to use, copy, modify, merge,
// publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software
// is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice
// shall be included in all copies or substantial portions
// of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
// ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
// TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
// SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
// IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
// Source encoding_rs UserDefinedDecoder and decoder_function! expansion.
module encoding

struct UserDefinedDecoder {}

// x_user_defined.rs uses decoder_function! with empty preamble/loop/EOF.
// macros.rs checks input availability before destination.check_space_bmp,
// then commits exactly one byte before its actual UserDefined body executes.
fn (_ UserDefinedDecoder) decode_to_utf8_raw(input []u8, mut output []u8, last bool) (SingleByteDecoderResult, int, int) {
	mut read := 0
	mut written := 0
	for {
		if read == input.len {
			return SingleByteDecoderResult{ status: .input_empty }, read, written
		}
		// Source requires BMP space before ASCII too. Its UserDefined raw
		// body intentionally does not optimize ASCII runs for binary data.
		if written + 2 >= output.len {
			return SingleByteDecoderResult{ status: .output_full }, read, written
		}
		byte := input[read]
		read++
		if byte < 0x80 {
			output[written] = byte
			written++
			continue
		}
		mapped := u16(byte) + 0xf700
		// Utf8Destination::write_upper_bmp.
		output[written] = u8((mapped >> 12) | 0xe0)
		output[written + 1] = u8(((mapped & 0xfc0) >> 6) | 0x80)
		output[written + 2] = u8((mapped & 0x3f) | 0x80)
		written += 3
	}
	return SingleByteDecoderResult{ status: .input_empty }, read, written
}

// UserDefinedDecoder max_utf8_buffer_length is checked byte_length * 3.
// Every input byte is defined, so replacement/fatal yield identical output.
fn decode_x_user_defined(input []u8) string {
	// Source uses uint; this flattened V owned array has signed int lengths.
	if input.len > int(0x7fffffff) / 3 {
		panic('UserDefined UTF8 output exceeds flattened V int array capacity')
	}
	decoder := UserDefinedDecoder{}
	mut output := []u8{len: input.len * 3}
	result, read, written := decoder.decode_to_utf8_raw(input, mut output, true)
	if result.status != .input_empty || read != input.len {
		panic('Source VERIFY: UserDefined maximum UTF8 output capacity')
	}
	return output[..written].bytestr()
}
