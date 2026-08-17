module encoding

fn test_text_decoder_constructor_options_and_labels() {
	decoder := TextDecoder.construct(' UTF-8 ', TextDecoderOptions{
		fatal:      true
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
	assert preserve.decode([u8(0xef), 0xbb, 0xbf, `x`], TextDecodeOptions{})! == '\ufeffx'
	assert decoder.decode([u8(0xc3), 0x28], TextDecodeOptions{})! == '\ufffd('
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
	assert user.decode([u8(0x41), 0x80], TextDecodeOptions{})! == 'A\uf780'
}

fn test_text_encoder_stream_split_surrogates_and_flush() {
	mut stream := TextEncoderStream.create()
	assert stream.encoding() == 'utf-8'
	assert stream.encode_and_enqueue_chunk([u16(0xd835)]) == []u8{}
	assert stream.encode_and_enqueue_chunk([u16(0xdd38), `!`]) == '𝔸!'.bytes()
	assert stream.encode_and_enqueue_chunk([u16(0xd800)]) == []u8{}
	assert stream.encode_and_flush() == [u8(0xef), 0xbf, 0xbd]
	assert stream.chunks().len == 2
}

fn test_text_encoder_stream_lone_surrogate_replacement_and_reprocess() {
	mut stream := TextEncoderStream.create()
	assert stream.encode_and_enqueue_chunk([u16(0xd800), `A`, 0xdc00]) == '\ufffdA\ufffd'.bytes()
}
