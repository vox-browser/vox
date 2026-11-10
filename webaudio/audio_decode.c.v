// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Host-backed translation of LibMedia::decode_entire_audio_stream, with a WAV
// implementation retained for portable tests and builds without FFmpeg.
module webaudio

import encoding.binary
import math

#include "audio_decode_bridge.h"

fn C.ladybird_v_decode_audio(bytes &u8, byte_count int, requested_sample_rate int,
	output_channels &int, output_frames &int, output_sample_rate &int) &f32

fn C.ladybird_v_free_decoded_audio(samples &f32)

fn C.ladybird_v_audio_sample_rate_supported(rate u64) bool

fn C.ladybird_v_decoded_audio_fits(frames u64, channels u64) bool

struct DecodedAudioData {
	channels    [][]f32
	sample_rate f32
}

fn wave_bytes_equal(bytes []u8, offset int, expected string) bool {
	if offset < 0 || offset + expected.len > bytes.len {
		return false
	}
	for index in 0 .. expected.len {
		if bytes[offset + index] != expected[index] {
			return false
		}
	}
	return true
}

fn wave_sample(bytes []u8, offset int, format u16, bits_per_sample u16) !f32 {
	if format == 1 {
		return match bits_per_sample {
			8 { (f32(bytes[offset]) - 128.0) / 128.0 }
			16 { f32(i16(binary.little_endian_u16_at(bytes, offset))) / 32768.0 }
			24 {
				mut value := i32(u32(bytes[offset]) | (u32(bytes[offset + 1]) << 8) | (u32(bytes[offset + 2]) << 16))
				if value & 0x00800000 != 0 {
					value -= 0x01000000
				}
				f32(value) / 8388608.0
			}
			32 { f32(i32(binary.little_endian_u32_at(bytes, offset))) / 2147483648.0 }
			else {
				return error('EncodingError: Unsupported PCM sample width')
			}
		}
	}
	if format == 3 {
		return match bits_per_sample {
			32 { math.f32_from_bits(binary.little_endian_u32_at(bytes, offset)) }
			64 { f32(math.f64_from_bits(binary.little_endian_u64_at(bytes, offset))) }
			else {
				return error('EncodingError: Unsupported float sample width')
			}
		}
	}
	return error('EncodingError: Unsupported WAVE audio format')
}

fn checked_decoded_audio_frame_count(frames int, channels int, input_rate u32, output_rate u32) !int {
	if !C.ladybird_v_audio_sample_rate_supported(input_rate)
		|| !C.ladybird_v_audio_sample_rate_supported(output_rate) {
		return error('EncodingError: Audio sample rate is outside the supported range')
	}
	if frames < 0 || channels < 1 || !C.ladybird_v_decoded_audio_fits(u64(frames), u64(channels)) {
		return error('EncodingError: Decoded audio stream is too large')
	}
	// The bounded input count and sample-rate ratio fit exactly within u64.
	output_length := u64(math.round(f64(frames) * f64(output_rate) / f64(input_rate)))
	if !C.ladybird_v_decoded_audio_fits(output_length, u64(channels)) {
		return error('EncodingError: Decoded audio stream is too large')
	}
	return int(output_length)
}

fn resample_decoded_channels(channels [][]f32, input_rate u32, output_rate u32) ![][]f32 {
	if input_rate == output_rate || channels.len == 0 {
		return channels
	}
	input_length := channels[0].len
	output_length := checked_decoded_audio_frame_count(input_length, channels.len, input_rate, output_rate)!
	mut output := [][]f32{cap: channels.len}
	for channel in channels {
		mut resampled := []f32{len: output_length}
		for frame in 0 .. output_length {
			position := f64(frame) * f64(input_rate) / f64(output_rate)
			left := int(math.floor(position))
			right := if left + 1 < input_length { left + 1 } else { left }
			fraction := f32(position - f64(left))
			resampled[frame] = channel[left] + (channel[right] - channel[left]) * fraction
		}
		output << resampled
	}
	return output
}

fn decode_wave_audio(bytes []u8, requested_sample_rate u32) !DecodedAudioData {
	if !C.ladybird_v_audio_sample_rate_supported(requested_sample_rate) {
		return error('EncodingError: Audio sample rate is outside the supported range')
	}
	if bytes.len < 12 || !wave_bytes_equal(bytes, 0, 'RIFF')
		|| !wave_bytes_equal(bytes, 8, 'WAVE') {
		return error('EncodingError: Unable to decode audio data')
	}
	mut format := u16(0)
	mut channel_count := u16(0)
	mut sample_rate := u32(0)
	mut block_alignment := u16(0)
	mut bits_per_sample := u16(0)
	mut data_offset := -1
	mut data_size := 0
	mut offset := 12
	for offset + 8 <= bytes.len {
		chunk_size := int(binary.little_endian_u32_at(bytes, offset + 4))
		payload_offset := offset + 8
		if chunk_size < 0 || payload_offset + chunk_size > bytes.len {
			return error('EncodingError: Truncated WAVE chunk')
		}
		if wave_bytes_equal(bytes, offset, 'fmt ') {
			if chunk_size < 16 {
				return error('EncodingError: Invalid WAVE format chunk')
			}
			format = binary.little_endian_u16_at(bytes, payload_offset)
			channel_count = binary.little_endian_u16_at(bytes, payload_offset + 2)
			sample_rate = binary.little_endian_u32_at(bytes, payload_offset + 4)
			block_alignment = binary.little_endian_u16_at(bytes, payload_offset + 12)
			bits_per_sample = binary.little_endian_u16_at(bytes, payload_offset + 14)
			if format == 0xfffe && chunk_size >= 40 {
				format = binary.little_endian_u16_at(bytes, payload_offset + 24)
			}
		} else if wave_bytes_equal(bytes, offset, 'data') {
			data_offset = payload_offset
			data_size = chunk_size
		}
		offset = payload_offset + chunk_size + (chunk_size & 1)
	}
	bytes_per_sample := int(bits_per_sample) / 8
	if channel_count == 0 || channel_count > max_number_of_channels || sample_rate == 0
		|| bytes_per_sample == 0 || int(block_alignment) < int(channel_count) * bytes_per_sample
		|| data_offset < 0 || data_size < int(block_alignment) {
		return error('EncodingError: Invalid WAVE audio data')
	}
	if !C.ladybird_v_audio_sample_rate_supported(sample_rate) {
		return error('EncodingError: WAVE sample rate is outside the supported range')
	}
	frame_count := data_size / int(block_alignment)
	// Check both input and resampled storage before materializing either.
	checked_decoded_audio_frame_count(frame_count, int(channel_count), sample_rate, requested_sample_rate)!
	mut channels := [][]f32{len: int(channel_count), init: []f32{len: frame_count}}
	for frame in 0 .. frame_count {
		frame_offset := data_offset + frame * int(block_alignment)
		for channel in 0 .. int(channel_count) {
			sample_offset := frame_offset + channel * bytes_per_sample
			channels[channel][frame] = wave_sample(bytes, sample_offset, format, bits_per_sample)!
		}
	}
	return DecodedAudioData{
		channels: resample_decoded_channels(channels, sample_rate, requested_sample_rate)!
		sample_rate: f32(requested_sample_rate)
	}
}

fn decode_audio_bytes(bytes []u8, requested_sample_rate f32) !DecodedAudioData {
	if math.is_nan(requested_sample_rate) || math.is_inf(requested_sample_rate, 0)
		|| requested_sample_rate < 3000 || requested_sample_rate > 768000 {
		return error('EncodingError: Audio sample rate is outside the supported range')
	}
	if bytes.len == 0 {
		return error('EncodingError: Unable to decode audio data')
	}
	mut channel_count := 0
	mut frame_count := 0
	mut output_sample_rate := 0
	interleaved := C.ladybird_v_decode_audio(bytes.data, bytes.len, int(requested_sample_rate), &channel_count, &frame_count, &output_sample_rate)
	if interleaved != unsafe { nil } {
		defer {
			C.ladybird_v_free_decoded_audio(interleaved)
		}
		if channel_count <= 0 || channel_count > int(max_number_of_channels)
			|| frame_count <= 0 || output_sample_rate <= 0 {
			return error('EncodingError: Invalid decoded audio data')
		}
		if !C.ladybird_v_decoded_audio_fits(u64(frame_count), u64(channel_count)) {
			return error('EncodingError: Decoded audio stream is too large')
		}
		mut channels := [][]f32{len: channel_count, init: []f32{len: frame_count}}
		for frame in 0 .. frame_count {
			for channel in 0 .. channel_count {
				channels[channel][frame] = unsafe { interleaved[frame * channel_count + channel] }
			}
		}
		return DecodedAudioData{
			channels: channels
			sample_rate: f32(output_sample_rate)
		}
	}
	return decode_wave_audio(bytes, u32(requested_sample_rate))
}
