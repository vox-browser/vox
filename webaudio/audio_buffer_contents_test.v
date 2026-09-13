module webaudio

fn test_audio_buffer_acquisition_reuses_snapshot_until_channels_reattach() {
	mut buffer := new_audio_buffer(2, 4, 8_000) or { panic(err) }
	buffer.copy_to_channel([f32(1), 2, 3, 4], 0, 0)!
	first := buffer.acquire_contents()
	second := buffer.acquire_contents()
	assert voidptr(first) == voidptr(second)
	assert first.length() == 4
	assert first.duration() == 0.0005
	assert first.channels[0] == [f32(1), 2, 3, 4]

	buffer.attach_acquired_channels()
	buffer.copy_to_channel([f32(9)], 0, 0)!
	assert first.channels[0][0] == 1
	third := buffer.acquire_contents()
	assert voidptr(third) != voidptr(first)
	assert third.channels[0][0] == 9
}

fn test_audio_buffer_constructor_and_external_memory_accounting() {
	buffer := AudioBuffer.create_for_constructor(AudioBufferOptions{
		number_of_channels: 2
		length: 16
		sample_rate: 48_000
	}) or { panic(err) }
	assert buffer.external_memory_size() >= 2 * 16 * int(sizeof(f32))
}
