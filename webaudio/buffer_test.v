module webaudio

fn test_audio_buffer_validates_shape_and_copies_partial_channels() {
	mut buffer := new_audio_buffer(2, 4, 8000) or { panic(err) }
	assert buffer.number_of_channels() == 2
	assert buffer.duration() == 0.0005
	buffer.copy_to_channel([f32(1), 2, 3], 1, 2) or { panic(err) }
	assert buffer.channel_data(1) or { panic(err) } == [f32(0), 0, 1, 2]
	mut destination := [f32(9), 9, 9]
	buffer.copy_from_channel(mut destination, 1, 3) or { panic(err) }
	assert destination == [f32(2), 9, 9]
	new_audio_buffer(0, 1, 44100) or {
		assert err.msg().contains('Number of channels')
		return
	}
	assert false
}

fn test_periodic_wave_normalizes_shapes_and_zeroes_dc() {
	wave := new_periodic_wave(PeriodicWaveOptions{ real: [f32(5), 2, 3] }) or { panic(err) }
	assert wave.real == [f32(0), 2, 3]
	assert wave.imag == [f32(0), 0, 0]
	assert wave.normalize
	default_wave := new_periodic_wave(PeriodicWaveOptions{}) or { panic(err) }
	assert default_wave.imag == [f32(0), 1]
	new_periodic_wave(PeriodicWaveOptions{ real: [f32(0)], imag: [f32(0)] }) or {
		assert err.msg().contains('at least 2')
		return
	}
	assert false
}
