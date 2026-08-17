module webaudio

fn test_analyser_validates_fft_and_preserves_current_silence_boundary() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	mut analyser := context.base.create_analyser(AnalyserOptions{ fft_size: 32 }) or { panic(err) }
	assert analyser.frequency_bin_count() == 16
	mut time_bytes := []u8{len: 40, init: 255}
	analyser.get_byte_time_domain_data(mut time_bytes)
	assert time_bytes[..32] == []u8{len: 32, init: 128}
	assert time_bytes[32] == 255
	mut frequency_bytes := []u8{len: 16, init: 99}
	analyser.get_byte_frequency_data(mut frequency_bytes)
	assert frequency_bytes == []u8{len: 16}
	analyser.set_fft_size(30) or {
		assert err.msg().contains('power of 2')
		return
	}
	assert false
}

fn test_analyser_decibel_and_smoothing_setters_are_transactional() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	mut analyser := context.base.create_analyser(AnalyserOptions{}) or { panic(err) }
	analyser.set_min_decibels(-20) or { assert err.msg().contains('greater') }
	assert analyser.min_decibels == -100
	analyser.set_smoothing_time_constant(1.1) or {
		assert err.msg().contains('between')
		return
	}
	assert false
}
