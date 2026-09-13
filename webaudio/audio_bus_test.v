module webaudio

import math

fn audio_bus_with_constant_channels(values []f32, frame_count int) &AudioBus {
	mut bus := AudioBus.create(values.len, frame_count)
	for channel, value in values {
		bus.set_channel(channel, []f32{len: frame_count, init: value})
	}
	return bus
}

fn assert_audio_bus_channels(bus &AudioBus, expected []f32) {
	assert bus.channel_count() == expected.len
	for channel, value in expected {
		for sample in bus.channel(channel) {
			assert math.abs(sample - value) < 0.00001
		}
	}
}

fn test_audio_bus_storage_zero_resize_and_copy() {
	mut source := audio_bus_with_constant_channels([f32(1), 2], 4)
	assert source.channel_count() == 2
	assert source.frame_count() == 4
	assert !source.is_silent()
	mut destination := AudioBus.create(1, 4)
	destination.copy_from(source)
	assert_audio_bus_channels(destination, [f32(1), 2])
	source.set_channel_count(3)
	assert source.channel_count() == 3
	assert source.is_silent()
	source.set_channel(2, [f32(1), 2, 3, 4])
	assert !source.is_silent()
	source.zero()
	assert source.is_silent()
}

fn test_audio_bus_discrete_mixing_sums_common_channels_only() {
	source := audio_bus_with_constant_channels([f32(1), 2, 3], 2)
	mut destination := audio_bus_with_constant_channels([f32(10), 20], 2)
	destination.sum_from(source, .discrete)
	assert_audio_bus_channels(destination, [f32(11), 22])

	mono := audio_bus_with_constant_channels([f32(4)], 2)
	mut wider := AudioBus.create(3, 2)
	wider.sum_from(mono, .discrete)
	assert_audio_bus_channels(wider, [f32(4), 0, 0])
}

fn test_audio_bus_speaker_upmixing_layouts() {
	mono := audio_bus_with_constant_channels([f32(2)], 1)
	mut stereo := AudioBus.create(2, 1)
	stereo.sum_from(mono, .speakers)
	assert_audio_bus_channels(stereo, [f32(2), 2])
	mut surround := AudioBus.create(6, 1)
	surround.sum_from(mono, .speakers)
	assert_audio_bus_channels(surround, [f32(0), 0, 2, 0, 0, 0])

	quad := audio_bus_with_constant_channels([f32(1), 2, 3, 4], 1)
	mut five_one := AudioBus.create(6, 1)
	five_one.sum_from(quad, .speakers)
	assert_audio_bus_channels(five_one, [f32(1), 2, 0, 0, 3, 4])
}

fn test_audio_bus_speaker_downmixing_layouts() {
	stereo := audio_bus_with_constant_channels([f32(2), 4], 1)
	mut mono := AudioBus.create(1, 1)
	mono.sum_from(stereo, .speakers)
	assert_audio_bus_channels(mono, [f32(3)])

	five_one := audio_bus_with_constant_channels([f32(1), 2, 3, 40, 5, 6], 1)
	mut downmixed_stereo := AudioBus.create(2, 1)
	downmixed_stereo.sum_from(five_one, .speakers)
	sqrt_half := f32(math.sqrt(0.5))
	assert_audio_bus_channels(downmixed_stereo, [
		f32(1 + sqrt_half * (3 + 5)),
		f32(2 + sqrt_half * (3 + 6)),
	])
	mut downmixed_quad := AudioBus.create(4, 1)
	downmixed_quad.sum_from(five_one, .speakers)
	assert_audio_bus_channels(downmixed_quad, [
		f32(1 + sqrt_half * 3),
		f32(2 + sqrt_half * 3),
		f32(5),
		f32(6),
	])
}

fn test_audio_bus_unknown_speaker_layout_falls_back_to_discrete() {
	source := audio_bus_with_constant_channels([f32(1), 2, 3], 1)
	mut destination := AudioBus.create(5, 1)
	destination.sum_from(source, .speakers)
	assert_audio_bus_channels(destination, [f32(1), 2, 3, 0, 0])
}
