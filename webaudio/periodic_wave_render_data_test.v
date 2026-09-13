module webaudio

fn test_periodic_wave_render_data_is_an_immutable_snapshot() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	wave := PeriodicWave.create_for_constructor(&context.base, PeriodicWaveOptions{
		real: [f32(9), 1, 2]
		imag: [f32(8), 3, 4]
	}) or { panic(err) }
	render_data := wave.render_data()
	assert render_data.real == [f32(0), 1, 2]
	assert render_data.imag == [f32(0), 3, 4]
	assert render_data.normalize
	assert wave.external_memory_size() == 6 * int(sizeof(f32))
	assert render_data.real.data != wave.real.data
	assert render_data.imag.data != wave.imag.data
}

fn test_periodic_wave_vector_helpers_copy_and_zero() {
	mut source := [f32(1), 2]
	copy := copy_float_vector(source)
	source[0] = 9
	assert copy == [f32(1), 2]
	assert zeroed_float_vector(3) == [f32(0), 0, 0]
}
