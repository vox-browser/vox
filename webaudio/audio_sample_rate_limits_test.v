// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Ladybird 2abe68fefd4e5bedce639d19f0c1620c2b14fbf9.
module webaudio

import encoding.base64
import encoding.binary
import math

fn rate_limit_wave(rate u32) []u8 {
	mut bytes := base64.decode('UklGRiwAAABXQVZFZm10IBAAAAABAAIAQB8AAAB9AAAEABAAZGF0YQgAAAAAAP9/AIAAQA==')
	binary.little_endian_put_u32_at(mut bytes, rate, 24)
	binary.little_endian_put_u32_at(mut bytes, rate * 4, 28)
	return bytes
}

fn test_wave_sample_rate_limits_reject_before_resampling() {
	for rate in [u32(0), 1, 2999, 768001, 0xffffffff] {
		if _ := decode_wave_audio(rate_limit_wave(rate), 48_000) {
			assert false, '${rate} Hz must be rejected'
		} else {
			assert err.msg().starts_with('EncodingError:')
		}
	}
	for rate in [u32(3000), 48_000, 768_000] {
		decoded := decode_wave_audio(rate_limit_wave(rate), rate)!
		assert decoded.sample_rate == f32(rate)
		assert decoded.channels.len == 2
		assert decoded.channels[0] == [f32(0), -1]
		assert decoded.channels[1] == [f32(32767.0 / 32768.0), 0.5]
	}
}

fn test_audio_decode_validates_target_rate_before_native_conversion() {
	for rate in [f32(0), 1, 2999, 768001, f32(math.nan()), f32(math.inf(1)), f32(math.inf(-1))] {
		if _ := decode_audio_bytes(rate_limit_wave(48_000), rate) {
			assert false
		} else {
			assert err.msg() == 'EncodingError: Audio sample rate is outside the supported range'
		}
	}
	for rate in [u64(0), 1, 2999, 768001, u64(0xffffffffffffffff)] {
		assert !C.ladybird_v_audio_sample_rate_supported(rate)
	}
	assert C.ladybird_v_audio_sample_rate_supported(3000)
	assert C.ladybird_v_audio_sample_rate_supported(768000)
}
