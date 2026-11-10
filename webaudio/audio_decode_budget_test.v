// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Ladybird 6cffda19bd949448d336d61761aff9dc767c51fe.
module webaudio

import encoding.binary

fn test_decoded_audio_budget_checks_both_input_and_resampled_storage() {
	// Exercise 512 MiB boundaries without allocating their sample arrays.
	assert checked_decoded_audio_frame_count(134_217_728, 1, 48_000, 48_000)! == 134_217_728
	assert checked_decoded_audio_frame_count(67_108_864, 2, 48_000, 48_000)! == 67_108_864
	assert checked_decoded_audio_frame_count(524_288, 1, 3000, 768_000)! == 134_217_728
	for input in [[134_217_729, 1, 48_000, 48_000], [67_108_865, 2, 48_000, 48_000],
		[524_289, 1, 3000, 768_000], [134_217_729, 1, 768_000, 3000]] {
		if _ := checked_decoded_audio_frame_count(input[0], input[1], u32(input[2]), u32(input[3])) {
			assert false
		} else {
			assert err.msg() == 'EncodingError: Decoded audio stream is too large'
		}
	}
}

fn test_small_wave_cannot_expand_past_the_decoded_audio_budget() {
	// Half a megabyte of 8-bit mono at 3000 Hz would expand past 512 MiB at
	// 768000 Hz. Rejection happens before either channel array is allocated.
	frames := 524_289
	mut wave := []u8{len: 44 + frames}
	for offset, text in {
		0:  'RIFF'
		8:  'WAVE'
		12: 'fmt '
		36: 'data'
	} {
		for i, byte in text.bytes() {
			wave[offset + i] = byte
		}
	}
	binary.little_endian_put_u32_at(mut wave, u32(wave.len - 8), 4)
	binary.little_endian_put_u32_at(mut wave, 16, 16)
	binary.little_endian_put_u16_at(mut wave, 1, 20)
	binary.little_endian_put_u16_at(mut wave, 1, 22)
	binary.little_endian_put_u32_at(mut wave, 3000, 24)
	binary.little_endian_put_u32_at(mut wave, 3000, 28)
	binary.little_endian_put_u16_at(mut wave, 1, 32)
	binary.little_endian_put_u16_at(mut wave, 8, 34)
	binary.little_endian_put_u32_at(mut wave, u32(frames), 40)
	if _ := decode_wave_audio(wave, 768_000) {
		assert false
	} else {
		assert err.msg() == 'EncodingError: Decoded audio stream is too large'
	}
}
