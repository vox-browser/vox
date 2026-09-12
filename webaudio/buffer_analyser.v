// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of AudioBuffer and AnalyserNode.
module webaudio

import math

pub struct AudioBuffer {
pub:
	sample_rate f32
	length      u32
pub mut:
	channels [][]f32
}

pub struct AudioBufferOptions {
pub:
	number_of_channels u32 = 1
	length             u32
	sample_rate        f32
}

pub fn AudioBuffer.from_options(options AudioBufferOptions) !AudioBuffer {
	return new_audio_buffer(options.number_of_channels, options.length, options.sample_rate)
}

pub fn new_audio_buffer(number_of_channels u32, length u32, sample_rate f32) !AudioBuffer {
	verify_audio_options(number_of_channels, length, sample_rate)!
	mut channels := [][]f32{cap: int(number_of_channels)}
	for _ in 0 .. number_of_channels {
		channels << []f32{len: int(length)}
	}
	return AudioBuffer{
		sample_rate: sample_rate
		length: length
		channels: channels
	}
}

pub fn (buffer AudioBuffer) duration() f64 {
	return f64(buffer.length) / f64(buffer.sample_rate)
}

pub fn (buffer AudioBuffer) number_of_channels() u32 {
	return u32(buffer.channels.len)
}

pub fn (buffer AudioBuffer) channel_data(channel u32) ![]f32 {
	if channel >= u32(buffer.channels.len) {
		return error('IndexSizeError: Channel index is out of range')
	}
	// Float32Array identity is SameObject upstream; V slices retain the backing array.
	return buffer.channels[channel]
}

pub fn (buffer AudioBuffer) copy_from_channel(mut destination []f32, channel_number u32, buffer_offset u32) ! {
	channel := buffer.channel_data(channel_number)!
	if buffer_offset >= u32(channel.len) {
		return
	}
	count := if destination.len < channel.len - int(buffer_offset) {
		destination.len
	} else {
		channel.len - int(buffer_offset)
	}
	for index in 0 .. count {
		destination[index] = channel[int(buffer_offset) + index]
	}
}

pub fn (mut buffer AudioBuffer) copy_to_channel(source []f32, channel_number u32, buffer_offset u32) ! {
	if channel_number >= u32(buffer.channels.len) {
		return error('IndexSizeError: Channel index is out of range')
	}
	if buffer_offset >= buffer.length {
		return
	}
	count := if source.len < int(buffer.length - buffer_offset) {
		source.len
	} else {
		int(buffer.length - buffer_offset)
	}
	for index in 0 .. count {
		buffer.channels[channel_number][int(buffer_offset) + index] = source[index]
	}
}

pub struct AnalyserOptions {
pub:
	fft_size                u32 = 2048
	max_decibels            f64 = -30
	min_decibels            f64 = -100
	smoothing_time_constant f64 = 0.8
	node                    AudioNodeOptions
}

pub struct AnalyserNode {
pub mut:
	node                    AudioNode
	fft_size                u32
	max_decibels            f64
	min_decibels            f64
	smoothing_time_constant f64
	previous_block          []f32
}

pub fn (mut context BaseAudioContext) create_analyser(options AnalyserOptions) !AnalyserNode {
	if options.min_decibels >= options.max_decibels {
		return error('IndexSizeError: Analyser node minDecibels greater than maxDecibels')
	}
	if options.smoothing_time_constant < 0 || options.smoothing_time_constant > 1 {
		return error('IndexSizeError: smoothingTimeConstant not between 0 and 1')
	}
	node := context.allocate_node(.analyser, 1, 1, options.node, 2, .max, .speakers)!
	mut analyser := AnalyserNode{
		node: node
		max_decibels: options.max_decibels
		min_decibels: options.min_decibels
		smoothing_time_constant: options.smoothing_time_constant
	}
	analyser.set_fft_size(options.fft_size)!
	return analyser
}

pub fn (analyser AnalyserNode) frequency_bin_count() u32 {
	return analyser.fft_size / 2
}

pub fn (analyser AnalyserNode) fft_size() u32 {
	return analyser.fft_size
}

pub fn (analyser AnalyserNode) min_decibels() f64 {
	return analyser.min_decibels
}

pub fn (analyser AnalyserNode) max_decibels() f64 {
	return analyser.max_decibels
}

pub fn (analyser AnalyserNode) smoothing_time_constant() f64 {
	return analyser.smoothing_time_constant
}

pub fn (mut analyser AnalyserNode) set_fft_size(size u32) ! {
	if size < 32 || size > 32768 || size & (size - 1) != 0 {
		return error('IndexSizeError: fftSize is not a power of 2 between 32 and 32768')
	}
	analyser.fft_size = size
	analyser.previous_block = []f32{len: int(size)}
}

pub fn (mut analyser AnalyserNode) set_min_decibels(value f64) ! {
	if value >= analyser.max_decibels {
		return error('IndexSizeError: minDecibels greater than maxDecibels')
	}
	analyser.min_decibels = value
}

pub fn (mut analyser AnalyserNode) set_max_decibels(value f64) ! {
	if analyser.min_decibels >= value {
		return error('IndexSizeError: minDecibels greater than maxDecibels')
	}
	analyser.max_decibels = value
}

pub fn (mut analyser AnalyserNode) set_smoothing_time_constant(value f64) ! {
	if value < 0 || value > 1 {
		return error('IndexSizeError: smoothingTimeConstant not between 0 and 1')
	}
	analyser.smoothing_time_constant = value
}

pub fn (analyser AnalyserNode) current_time_domain_data() []f32 {
	// Current upstream has no render graph signal plumbing and returns silence.
	return []f32{len: int(analyser.fft_size)}
}

pub fn (analyser AnalyserNode) apply_blackman_window(input []f32) []f32 {
	mut output := []f32{len: int(analyser.fft_size)}
	for index in 0 .. int(analyser.fft_size) {
		window := f32(0.42 - 0.5 * math.cos(2 * math.pi * f64(index) / f64(analyser.fft_size)) + 0.08 * math.cos(4 * math.pi * f64(index) / f64(analyser.fft_size)))
		output[index] = input[index] * window
	}
	return output
}

pub fn (mut analyser AnalyserNode) current_frequency_data() []f32 {
	current_time_domain_data := analyser.current_time_domain_data()
	blackman_windowed_input := analyser.apply_a_blackman_window(current_time_domain_data)
	frequency_domain_data := apply_a_fourier_transform(blackman_windowed_input)
	smoothed_data := analyser.smoothing_over_time(frequency_domain_data)
	return analyser.conversion_to_d_b(smoothed_data)
}

pub fn (mut analyser AnalyserNode) get_float_frequency_data(mut output []f32) {
	data := analyser.current_frequency_data()
	count := if output.len < int(analyser.frequency_bin_count()) {
		output.len
	} else {
		int(analyser.frequency_bin_count())
	}
	for index in 0 .. count {
		output[index] = data[index]
	}
}

pub fn (mut analyser AnalyserNode) get_byte_frequency_data(mut output []u8) {
	data := analyser.current_frequency_data()
	count := if output.len < int(analyser.frequency_bin_count()) {
		output.len
	} else {
		int(analyser.frequency_bin_count())
	}
	for index in 0 .. count {
		mut value := f64(data[index])
		if math.is_inf(value, -1) {
			value = analyser.min_decibels
		}
		if value < analyser.min_decibels {
			value = analyser.min_decibels
		}
		if value > analyser.max_decibels {
			value = analyser.max_decibels
		}
		output[index] = u8(255 * (value - analyser.min_decibels) / (analyser.max_decibels - analyser.min_decibels))
	}
}

pub fn (analyser AnalyserNode) get_float_time_domain_data(mut output []f32) {
	data := analyser.current_time_domain_data()
	count := if output.len < int(analyser.fft_size) {
		output.len
	} else {
		int(analyser.fft_size)
	}
	for index in 0 .. count {
		output[index] = data[index]
	}
}

pub fn (analyser AnalyserNode) get_byte_time_domain_data(mut output []u8) {
	data := analyser.current_time_domain_data()
	count := if output.len < int(analyser.fft_size) { output.len } else { int(analyser.fft_size) }
	for index in 0 .. count {
		mut value := 128 * (1 + data[index])
		if value < 0 {
			value = 0
		}
		if value > 255 {
			value = 255
		}
		output[index] = u8(value)
	}
}
