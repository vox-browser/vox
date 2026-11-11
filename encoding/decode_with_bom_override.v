// Copyright (c) 2024, the SerenityOS developers.
// SPDX-License-Identifier: BSD-2-Clause

// LibTextCodec/Decoder.cpp's given-decoder BOM override. The typed boundary
// identifies the fallback Decoder by its registered encoding label.
module encoding

pub fn convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark(fallback_encoding string, input []u8) !string {
	mut actual_encoding := fallback_encoding
	mut bytes := input.clone()
	if bom_encoding := bom_sniff(input) {
		actual_encoding = bom_encoding
		bytes = input[if bom_encoding == 'UTF-8' { 3 } else { 2 }..].clone()
	}
	if registered_encoding := get_an_encoding(actual_encoding) {
		if registered_encoding == 'replacement' {
			return decode_replacement_to_utf8(bytes)
		}
		if registered_encoding == 'UTF-8' {
			// Sniffing already removed the BOM; another U+FEFF is content.
			return decode_source_utf8_whole_to_utf8(bytes, false, false)
		}
		if registered_encoding == 'Shift_JIS' {
			// Source invokes the selected decoder's complete UTF8 operation.
			// Matching-BOM removal leaves this non-Unicode selected span intact.
			return decode_source_shift_jis_whole_to_utf8(bytes, false)
		}
		if registered_encoding == 'UTF-16LE' || registered_encoding == 'UTF-16BE' {
			return decode_source_utf16_whole_to_utf8(bytes, registered_encoding == 'UTF-16BE', false, false)
		}
	}
	// The selected decoder preserves any BOM left after the initial sniff.
	mut decoder := TextDecoder.construct(actual_encoding, TextDecoderOptions{ ignore_bom: true })!
	return decoder.decode(bytes, TextDecodeOptions{})
}
