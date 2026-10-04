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
	// Source passes IgnoreBOM::No and Replacement to the chosen decoder.
	// Its Rust decode_with_bom_removal strips one further same-encoding BOM;
	// it does not sniff a second BOM to replace the selected encoding.
	mut decoder := TextDecoder.construct(actual_encoding, TextDecoderOptions{})!
	return decoder.decode(bytes, TextDecodeOptions{})
}
