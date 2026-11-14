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
mut:
	contents_ ?&AudioBufferContents
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

pub fn AudioBuffer.create_for_constructor(options AudioBufferOptions) !AudioBuffer {
	return AudioBuffer.from_options(options)
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

pub fn (buffer &AudioBuffer) channel_data(channel u32) ![]f32 {
	if channel >= u32(buffer.channels.len) {
		return error('IndexSizeError: Channel index is out of range')
	}
	// Complete deferred acquisition before exposing fresh writable channels.
	mut mutable_buffer := unsafe { &AudioBuffer(buffer) }
	mutable_buffer.attach_acquired_channels()
	// Float32Array identity is SameObject upstream; V slices retain the backing array.
	return buffer.channels[channel]
}

pub fn (buffer &AudioBuffer) copy_from_channel(mut destination []f32, channel_number u32, buffer_offset u32) ! {
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
	buffer.attach_acquired_channels()
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

// https://webaudio.github.io/web-audio-api/#acquire-the-content
pub fn (mut buffer AudioBuffer) acquire_contents() &AudioBufferContents {
	if contents := buffer.contents_ {
		return contents
	}
	mut channels := [][]f32{cap: buffer.channels.len}
	for channel in buffer.channels {
		channels << channel.clone()
	}
	contents := &AudioBufferContents{
		channels: channels
		sample_rate: buffer.sample_rate
	}
	buffer.contents_ = contents
	return contents
}

// V slices do not expose JavaScript ArrayBuffer detachment. This explicit
// completion of acquisition still preserves the important copy-on-write
// boundary: subsequent channel writes cannot mutate the playback snapshot.
pub fn (mut buffer AudioBuffer) attach_acquired_channels() {
	contents := buffer.contents_ or { return }
	mut channels := [][]f32{cap: contents.channels.len}
	for channel in contents.channels {
		channels << channel.clone()
	}
	buffer.channels = channels
	buffer.contents_ = none
}

pub fn (buffer AudioBuffer) external_memory_size() int {
	mut size := 0
	for channel in buffer.channels {
		size += channel.cap * int(sizeof(f32))
	}
	return size
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
mut:
	fft_                       FFT
	time_domain_ring_          &MediaStreamAudioRing
	render_node_               &AnalyserRenderNode
	history_                   []f32
	history_write_index_       int
	history_valid_frames_      int
	cached_frequency_data_     []f32
	frequency_data_cache_time_ ?f64
}

pub fn AnalyserNode.validate_options(options AnalyserOptions) ! {
	if options.min_decibels >= options.max_decibels {
		return error('IndexSizeError: Analyser node minDecibels greater than maxDecibels')
	}
	if options.smoothing_time_constant < 0 || options.smoothing_time_constant > 1 {
		return error('IndexSizeError: smoothingTimeConstant not between 0 and 1')
	}
	if options.fft_size < 32 || options.fft_size > 32768
		|| options.fft_size & (options.fft_size - 1) != 0 {
		return error('IndexSizeError: fftSize is not a power of 2 between 32 and 32768')
	}
}

pub fn (mut context BaseAudioContext) create_analyser(options AnalyserOptions) !AnalyserNode {
	AnalyserNode.validate_options(options)!
	node := context.allocate_node(.analyser, 1, 1, options.node, 2, .max, .speakers)!
	mut time_domain_ring := new_media_stream_audio_ring(32768, 1)
	mut analyser := AnalyserNode{
		node: node
		max_decibels: options.max_decibels
		min_decibels: options.min_decibels
		smoothing_time_constant: options.smoothing_time_constant
		time_domain_ring_: time_domain_ring
		render_node_: AnalyserRenderNode.create(node.id, int(render_quantum_size), time_domain_ring)
		history_: []f32{len: 32768}
	}
	analyser.set_fft_size(options.fft_size)!
	node.queue_render_node_creation(analyser.render_node_.render_node())
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
	analyser.set_fft_size_without_validation(size)
}

pub fn (mut analyser AnalyserNode) set_fft_size_without_validation(size u32) {
	analyser.fft_size = size
	analyser.fft_ = FFT.create(int(size))
	analyser.previous_block = []f32{len: int(size / 2)}
	analyser.frequency_data_cache_time_ = none
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

pub fn (analyser &AnalyserNode) render_node() &AnalyserRenderNode {
	return analyser.render_node_
}

pub fn (mut analyser AnalyserNode) drain_time_domain_ring() {
	mut ring := unsafe { &MediaStreamAudioRing(analyser.time_domain_ring_) }
	for {
		chunk := ring.pop_frames(1024)
		if chunk.len == 0 {
			break
		}
		for sample in chunk {
			analyser.history_[analyser.history_write_index_] = sample
			analyser.history_write_index_ = (analyser.history_write_index_ + 1) % analyser.history_.len
		}
		analyser.history_valid_frames_ = min_int(analyser.history_.len, analyser.history_valid_frames_ + chunk.len)
	}
}

pub fn (mut analyser AnalyserNode) current_time_domain_data() []f32 {
	analyser.drain_time_domain_ring()
	mut result := []f32{len: int(analyser.fft_size)}
	frames_available := min_int(int(analyser.fft_size), analyser.history_valid_frames_)
	for frame in 0 .. frames_available {
		history_index := (analyser.history_write_index_ + analyser.history_.len - frames_available + frame) % analyser.history_.len
		result[int(analyser.fft_size) - frames_available + frame] = analyser.history_[history_index]
	}
	return result
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
	current_time := analyser.node.graph.current_time
	if cache_time := analyser.frequency_data_cache_time_ {
		if cache_time == current_time {
			return analyser.cached_frequency_data_.clone()
		}
	}
	current_time_domain_data := analyser.current_time_domain_data()
	blackman_windowed_input := analyser.apply_a_blackman_window(current_time_domain_data)
	frequency_domain_data := analyser.fft_.magnitudes(blackman_windowed_input)
	smoothed_data := analyser.smoothing_over_time(frequency_domain_data)
	result := analyser.conversion_to_d_b(smoothed_data)
	analyser.cached_frequency_data_ = result.clone()
	analyser.frequency_data_cache_time_ = current_time
	return result
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

pub fn (mut analyser AnalyserNode) get_float_time_domain_data(mut output []f32) {
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

pub fn (mut analyser AnalyserNode) get_byte_time_domain_data(mut output []u8) {
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
