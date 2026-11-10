module encoding

fn test_text_decoder_constructor_options_and_labels() {
	decoder := TextDecoder.construct(' UTF-8 ', TextDecoderOptions{
		fatal: true
		ignore_bom: true
	})!
	assert decoder.encoding() == 'utf-8'
	assert decoder.fatal()
	assert decoder.ignore_bom()
	if _ := TextDecoder.construct('replacement', TextDecoderOptions{}) {
		assert false
	}
	if _ := TextDecoder.construct('does-not-exist', TextDecoderOptions{}) {
		assert false
	}
}

fn test_text_decoder_utf8_bom_and_errors() {
	decoder := TextDecoder.create()
	assert decoder.decode([u8(0xef), 0xbb, 0xbf, `o`, `k`], TextDecodeOptions{})! == 'ok'
	preserve := TextDecoder.construct('utf-8', TextDecoderOptions{ ignore_bom: true })!
	assert preserve.decode([u8(0xef), 0xbb, 0xbf, `x`], TextDecodeOptions{})! == '﻿x'
	assert decoder.decode([u8(0xc3), 0x28], TextDecodeOptions{})! == '�('
	fatal := TextDecoder.construct('utf-8', TextDecoderOptions{ fatal: true })!
	if _ := fatal.decode([u8(0xc3), 0x28], TextDecodeOptions{}) {
		assert false
	}
}

fn test_text_decoder_utf16_and_x_user_defined() {
	le := TextDecoder.construct('utf-16', TextDecoderOptions{})!
	assert le.decode([u8(0x41), 0, 0x35, 0xd8, 0x38, 0xdd], TextDecodeOptions{})! == 'A𝔸'
	be := TextDecoder.construct('utf-16be', TextDecoderOptions{})!
	assert be.decode([u8(0), 0x41], TextDecodeOptions{})! == 'A'
	user := TextDecoder.construct('x-user-defined', TextDecoderOptions{})!
	assert user.decode([u8(0x41), 0x80], TextDecodeOptions{})! == 'A'
}

fn test_text_encoder_stream_split_surrogates_and_flush() {
	mut stream := TextEncoderStream.create()
	assert stream.encoding() == 'utf-8'
	assert stream.encode_and_enqueue_chunk([u16(0xd835)]) == []u8{}
	assert stream.encode_and_enqueue_chunk([u16(0xdd38), u16(`!`)]) == '𝔸!'.bytes()
	assert stream.encode_and_enqueue_chunk([u16(0xd800)]) == []u8{}
	assert stream.encode_and_flush() == [u8(0xef), 0xbf, 0xbd]
	assert stream.chunks().len == 2
}

fn test_text_encoder_stream_lone_surrogate_replacement_and_reprocess() {
	mut stream := TextEncoderStream.create()
	assert stream.encode_and_enqueue_chunk([u16(0xd800), u16(`A`), 0xdc00]) == '�A�'.bytes()
}

fn test_exact_constructors_and_scalar_conversion_entry_point() {
	assert TextDecoder.construct_impl('utf-8', TextDecoderOptions{})!.encoding() == 'utf-8'
	assert TextEncoder.construct_impl().encoding() == 'utf-8'
	mut stream := TextEncoderStream.construct_impl()
	assert stream.convert_code_unit_to_scalar_value(0xd83d).value == none
	converted := stream.convert_code_unit_to_scalar_value(0xde00)
	assert converted.value? == u32(0x1f600)
	assert TextEncoderStream.create_for_constructor().encoding() == 'utf-8'
}

fn test_decoder_output_queue_uses_single_then_builder_storage() {
	mut output := TextDecoderOutputQueue{}
	output.push('')!
	output.push('one')!
	output.push('two')!
	output.push('three')!
	assert output.serialize()! == 'onetwothree'

	mut single := TextDecoderOutputQueue{}
	single.push('only')!
	assert single.serialize()! == 'only'
	assert single.serialize()! == ''
}

fn test_text_decoder_stream_preserves_split_sequences_and_bom() {
	mut stream := TextDecoderStream.create_for_constructor('utf-8', TextDecoderOptions{})!
	assert stream.encoding() == 'utf-8'
	assert !stream.fatal()
	assert stream.decode_and_enqueue_chunk([u8(0xef)])! == ''
	assert stream.decode_and_enqueue_chunk([u8(0xbb), 0xbf, `A`, 0xf0, 0x9d])! == 'A'
	assert stream.decode_and_enqueue_chunk([u8(0x94), 0xb8])! == '𝔸'
	assert stream.flush_and_enqueue()! == ''
	assert stream.chunks() == ['A', '𝔸']

	mut incomplete := TextDecoderStream.create('utf-8', TextDecoderOptions{})!
	assert incomplete.decode_and_enqueue_chunk([u8(0xc3)])! == ''
	assert incomplete.flush_and_enqueue()! == '�'
	mut fatal := TextDecoderStream.create('utf-8', TextDecoderOptions{ fatal: true })!
	fatal.decode_and_enqueue_chunk([u8(0xc3)])!
	if _ := fatal.flush_and_enqueue() {
		assert false
	}
}

fn test_native_transform_decoder_does_not_retain_consumed_output() {
	mut decoder := TextDecoderStream.create('utf-8', TextDecoderOptions{})!
	assert decoder.decode_chunk([u8(0xef)])! == ''
	assert decoder.decode_chunk([u8(0xbb), 0xbf, `A`, 0xe2])! == 'A'
	assert decoder.decode_chunk([u8(0x82), 0xac])! == '€'
	for _ in 0 .. 1000 {
		assert decoder.decode_chunk('streamed text'.bytes())! == 'streamed text'
	}
	assert decoder.decode_chunk([u8(0xe2), 0x82])! == ''
	assert decoder.flush()! == '�'
	assert decoder.chunks().len == 0
}

fn test_utf8_stream_boundary_validation() {
	assert is_utf8_continuation_byte(0x80)
	assert !is_utf8_continuation_byte(0x40)
	assert is_utf8_second_byte_in_range(0xe0, 0xa0)
	assert !is_utf8_second_byte_in_range(0xe0, 0x9f)
	assert find_utf8_safe_decode_boundary([u8(`A`), 0xf0, 0x9d]) == 1
	assert find_utf8_safe_decode_boundary([u8(0xe0), 0x80]) == 2
	assert find_utf8_safe_decode_boundary([u8(0x80), 0x80, 0x80, 0x80]) == 4
}

fn test_text_decoder_stream_preserves_split_utf16_units() {
	mut stream := TextDecoderStream.create('utf-16le', TextDecoderOptions{})!
	assert stream.decode_and_enqueue_chunk([u8(0x41), 0x00, 0x35, 0xd8])! == 'A'
	assert stream.decode_and_enqueue_chunk([u8(0x38), 0xdd])! == '𝔸'
	assert stream.flush_and_enqueue()! == ''
}

fn test_text_decoder_decode_reuses_streaming_state_and_resets_after_flush() {
	decoder := TextDecoder.construct('utf-8', TextDecoderOptions{})!
	assert decoder.decode([u8(0xf0), 0x9d], TextDecodeOptions{ stream: true })! == ''
	assert decoder.decode([u8(0x94), 0xb8], TextDecodeOptions{})! == '𝔸'
	assert decoder.decode([u8(`A`)], TextDecodeOptions{})! == 'A'

	fatal := TextDecoder.construct('utf-8', TextDecoderOptions{ fatal: true })!
	// A literal U+FFFD is valid input; fatal mode rejects codec errors rather
	// than the replacement character itself.
	assert fatal.decode([u8(0xef), 0xbf, 0xbd], TextDecodeOptions{})! == '�'
}
