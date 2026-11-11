// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the WebAudio concrete signal-processing node units.
module webaudio

import math

const float_lowest = f32(-3.402823e38)
const float_highest = f32(3.402823e38)

fn detune_limit() f32 {
	return f32(1200 * math.log2(f64(float_highest)))
}

fn biquad_gain_limit() f32 {
	return f32(40 * math.log10(f64(float_highest)))
}

pub struct GainOptions {
pub:
	gain f32 = 1
	node AudioNodeOptions
}

pub struct ConstantSourceOptions {
pub:
	offset f32 = 1
	node   AudioNodeOptions
}

pub struct DelayOptions {
pub:
	max_delay_time f64 = 1
	delay_time     f64
	node           AudioNodeOptions
}

pub struct ChannelMergerOptions {
pub:
	number_of_inputs u32 = 6
	node             AudioNodeOptions
}

pub struct ChannelSplitterOptions {
pub:
	number_of_outputs u32 = 6
	node              AudioNodeOptions
}

pub struct StereoPannerOptions {
pub:
	pan  f32
	node AudioNodeOptions
}

pub struct GainNode {
pub mut:
	node AudioNode
	gain AudioParam
}

pub fn (mut context BaseAudioContext) create_gain(value f32, options AudioNodeOptions) !GainNode {
	node := context.allocate_node(.gain, 1, 1, options, 2, .max, .speakers)!
	gain := context.allocate_param(value, float_lowest, float_highest, .a_rate, false)
	node.queue_render_node_creation(GainRenderNode.create(node.id, int(render_quantum_size), gain.render_param()).render_node())
	return GainNode{
		node: node
		gain: gain
	}
}

pub fn (mut context BaseAudioContext) construct_gain(options GainOptions) !GainNode {
	return context.create_gain(options.gain, options.node)
}

pub struct ConstantSourceNode {
pub mut:
	node   AudioNode
	offset AudioParam
}

pub fn (mut context BaseAudioContext) create_constant_source(value f32, _ AudioNodeOptions) !ConstantSourceNode {
	// ConstantSourceNode::construct_impl currently does not initialize the
	// inherited AudioNodeOptions, leaving the AudioNode defaults intact.
	context.next_id++
	node := AudioNode{
		id: context.next_id
		context_id: context.id
		kind: .constant_source
		number_of_inputs: 0
		number_of_outputs: 1
		graph: context.graph
	}
	offset := context.allocate_param(value, float_lowest, float_highest, .a_rate, false)
	node.queue_render_node_creation(ConstantSourceRenderNode.create(node.id, int(render_quantum_size), offset.render_param()).render_node())
	return ConstantSourceNode{
		node: node
		offset: offset
	}
}

pub fn (mut context BaseAudioContext) construct_constant_source(options ConstantSourceOptions) !ConstantSourceNode {
	return context.create_constant_source(options.offset, options.node)
}

pub struct DelayNode {
pub mut:
	node       AudioNode
	delay_time AudioParam
pub:
	max_delay_time f64
}

pub fn (mut context BaseAudioContext) create_delay(max_delay_time f64, delay_time f64, options AudioNodeOptions) !DelayNode {
	DelayNode.validate_options(DelayOptions{
		max_delay_time: max_delay_time
		delay_time: delay_time
		node: options
	})!
	node := context.allocate_node(.delay, 1, 1, options, 2, .max, .speakers)!
	delay_parameter := context.allocate_param(f32(delay_time), 0, f32(max_delay_time), .a_rate, false)
	node.queue_render_node_creation(DelayRenderNode.create(node.id, int(render_quantum_size), delay_parameter.render_param(), max_delay_time).render_node())
	return DelayNode{
		node: node
		max_delay_time: max_delay_time
		delay_time: delay_parameter
	}
}

pub fn (mut context BaseAudioContext) construct_delay(options DelayOptions) !DelayNode {
	return context.create_delay(options.max_delay_time, options.delay_time, options.node)
}

pub fn DelayNode.validate_options(options DelayOptions) ! {
	if options.max_delay_time <= 0 || options.max_delay_time >= 180
		|| math.is_nan(options.max_delay_time) {
		return error('NotSupportedError: Max delay time must be between 0 and 180 seconds exclusive')
	}
}

pub struct DynamicsCompressorOptions {
pub:
	attack    f32 = 0.003
	knee      f32 = 30
	ratio     f32 = 12
	release   f32 = 0.25
	threshold f32 = -24
	node      AudioNodeOptions
}

pub struct DynamicsCompressorNode {
pub mut:
	node      AudioNode
	threshold AudioParam
	knee      AudioParam
	ratio     AudioParam
	attack    AudioParam
	release   AudioParam
pub:
	reduction f32
}

pub fn (mut context BaseAudioContext) create_dynamics_compressor(options DynamicsCompressorOptions) !DynamicsCompressorNode {
	node := context.allocate_node(.compressor, 1, 1, options.node, 2, .clamped_max, .speakers)!
	mut compressor := DynamicsCompressorNode{
		node: node
		threshold: context.allocate_param(options.threshold, -100, 0, .k_rate, true)
		knee: context.allocate_param(options.knee, 0, 40, .k_rate, true)
		ratio: context.allocate_param(options.ratio, 1, 20, .k_rate, true)
		attack: context.allocate_param(options.attack, 0, 1, .k_rate, true)
		release: context.allocate_param(options.release, 0, 1, .k_rate, true)
	}
	if count := options.node.channel_count { compressor.set_channel_count(count)! }
	if mode := options.node.channel_count_mode { compressor.set_channel_count_mode(mode)! }
	compressor.node.queue_render_node_creation(PassthroughRenderNode.create(node.id,
		int(render_quantum_size)).render_node())
	return compressor
}

pub fn (mut compressor DynamicsCompressorNode) set_channel_count_mode(mode ChannelCountMode) ! {
	if mode == .max {
		return error("NotSupportedError: DynamicsCompressorNode does not support 'max'")
	}
	compressor.node.set_channel_count_mode(mode)!
}

pub fn (mut compressor DynamicsCompressorNode) set_channel_count(count u32) ! {
	if count > 2 {
		return error('NotSupportedError: channel count greater than 2')
	}
	compressor.node.set_channel_count(count)!
}

pub struct BiquadFilterOptions {
pub:
	type_     BiquadFilterType = .lowpass
	q         f32 = 1
	detune    f32
	frequency f32 = 350
	gain      f32
	node      AudioNodeOptions
}

pub struct BiquadFilterNode {
pub mut:
	node      AudioNode
	type_     BiquadFilterType
	frequency AudioParam
	detune    AudioParam
	q         AudioParam
	gain      AudioParam
}

pub fn (mut context BaseAudioContext) create_biquad_filter(options BiquadFilterOptions) !BiquadFilterNode {
	node := context.allocate_node(.biquad, 1, 1, options.node, 2, .max, .speakers)!
	frequency := context.allocate_param(options.frequency, 0, context.nyquist_frequency(), .a_rate, false)
	detune := context.allocate_param(options.detune, -detune_limit(), detune_limit(), .a_rate, false)
	q := context.allocate_param(options.q, float_lowest, float_highest, .a_rate, false)
	gain := context.allocate_param(options.gain, float_lowest, biquad_gain_limit(), .a_rate, false)
	node.queue_render_node_creation(BiquadFilterRenderNode.create(node.id, int(render_quantum_size), frequency.render_param(), detune.render_param(), q.render_param(), gain.render_param()).render_node())
	if options.type_ != .lowpass {
		node.enqueue_control_message(ControlMessage{
			kind: .node_message
			node_message: NodeMessage{
				node_id: node.id
				kind: .set_biquad_filter_type
				biquad_type: options.type_
			}
		})
	}
	return BiquadFilterNode{
		node: node
		type_: options.type_
		frequency: frequency
		detune: detune
		q: q
		gain: gain
	}
}

pub fn (node BiquadFilterNode) get_frequency_response(frequency_hz []f32,
	mut magnitude_response []f32, mut phase_response []f32) ! {
	if magnitude_response.len != frequency_hz.len || phase_response.len != frequency_hz.len {
		return error('InvalidAccessError: Arrays must have the same length')
	}
	current_time := node.node.graph.current_time
	nyquist_frequency := node.node.graph.sample_rate / 2.0
	frequency := node.frequency.intrinsic_value_at_time(current_time)
	detune := node.detune.intrinsic_value_at_time(current_time)
	computed_frequency := f64(frequency) * math.exp2(f64(detune) / 1200.0)
	normalized_frequency := if computed_frequency < 0 {
		0.0
	} else if computed_frequency > f64(nyquist_frequency) {
		1.0
	} else {
		computed_frequency / f64(nyquist_frequency)
	}
	coefficients := compute_biquad_coefficients(node.type_, normalized_frequency, f64(node.q.intrinsic_value_at_time(current_time)), f64(node.gain.intrinsic_value_at_time(current_time)))
	for index, response_frequency in frequency_hz {
		if math.is_nan(response_frequency) || response_frequency < 0
			|| response_frequency > nyquist_frequency {
			magnitude_response[index] = f32(math.nan())
			phase_response[index] = f32(math.nan())
			continue
		}
		magnitude, phase := biquad_frequency_response(coefficients, f64(response_frequency / nyquist_frequency))
		magnitude_response[index] = magnitude
		phase_response[index] = phase
	}
}

pub struct ChannelMergerNode {
pub mut:
	node AudioNode
pub:
	number_of_inputs u32
}

pub fn (mut context BaseAudioContext) create_channel_merger(number_of_inputs u32, options AudioNodeOptions) !ChannelMergerNode {
	ChannelMergerNode.validate_options(ChannelMergerOptions{
		number_of_inputs: number_of_inputs
		node: options
	})!
	node := context.allocate_node(.channel_merger, number_of_inputs, 1, options, 1, .explicit, .speakers)!
	mut merger := ChannelMergerNode{
		node: node
		number_of_inputs: number_of_inputs
	}
	if count := options.channel_count { merger.set_channel_count(count)! }
	if mode := options.channel_count_mode { merger.set_channel_count_mode(mode)! }
	node.queue_render_node_creation(ChannelMergerRenderNode.create(node.id, int(render_quantum_size), int(number_of_inputs)).render_node())
	return merger
}

pub fn ChannelMergerNode.validate_options(options ChannelMergerOptions) ! {
	if options.number_of_inputs < 1 || options.number_of_inputs > max_number_of_channels {
		return error('IndexSizeError: Invalid number of inputs')
	}
}

pub fn (mut merger ChannelMergerNode) set_channel_count(count u32) ! {
	if count != 1 {
		return error('InvalidStateError: Channel count cannot be changed')
	}
	merger.node.set_channel_count(count)!
}

pub fn (mut merger ChannelMergerNode) set_channel_count_mode(mode ChannelCountMode) ! {
	if mode != .explicit {
		return error('InvalidStateError: Channel count mode cannot be changed')
	}
	merger.node.channel_count_mode = mode
	merger.node.queue_channel_config_update()
}

pub struct ChannelSplitterNode {
pub mut:
	node AudioNode
pub:
	number_of_outputs u32
}

pub fn (mut context BaseAudioContext) create_channel_splitter(number_of_outputs u32, options AudioNodeOptions) !ChannelSplitterNode {
	ChannelSplitterNode.validate_options(ChannelSplitterOptions{
		number_of_outputs: number_of_outputs
		node: options
	})!
	node := context.allocate_node(.channel_splitter, 1, number_of_outputs, options, number_of_outputs, .explicit, .discrete)!
	mut splitter := ChannelSplitterNode{
		node: node
		number_of_outputs: number_of_outputs
	}
	if count := options.channel_count { splitter.set_channel_count(count)! }
	if mode := options.channel_count_mode { splitter.set_channel_count_mode(mode)! }
	if interpretation := options.channel_interpretation {
		splitter.set_channel_interpretation(interpretation)!
	}
	node.queue_render_node_creation(ChannelSplitterRenderNode.create(node.id, int(render_quantum_size), int(number_of_outputs)).render_node())
	return splitter
}

pub fn ChannelSplitterNode.validate_options(options ChannelSplitterOptions) ! {
	if options.number_of_outputs < 1 || options.number_of_outputs > max_number_of_channels {
		return error('IndexSizeError: Invalid number of outputs')
	}
}

pub fn (mut splitter ChannelSplitterNode) set_channel_count(count u32) ! {
	if count != splitter.number_of_outputs {
		return error('InvalidStateError: Channel count must equal number of outputs')
	}
	splitter.node.set_channel_count(count)!
}

pub fn (mut splitter ChannelSplitterNode) set_channel_count_mode(mode ChannelCountMode) ! {
	if mode != .explicit {
		return error("InvalidStateError: Channel count mode must be 'explicit'")
	}
	splitter.node.channel_count_mode = mode
	splitter.node.queue_channel_config_update()
}

pub fn (mut splitter ChannelSplitterNode) set_channel_interpretation(value ChannelInterpretation) ! {
	if value != .discrete {
		return error("InvalidStateError: Channel interpretation must be 'discrete'")
	}
	splitter.node.channel_interpretation = value
	splitter.node.queue_channel_config_update()
}

pub struct StereoPannerNode {
pub mut:
	node AudioNode
	pan  AudioParam
}

pub fn (mut context BaseAudioContext) create_stereo_panner(pan f32, options AudioNodeOptions) !StereoPannerNode {
	node := context.allocate_node(.stereo_panner, 1, 1, options, 2, .clamped_max, .speakers)!
	pan_parameter := context.allocate_param(pan, -1, 1, .a_rate, false)
	node.queue_render_node_creation(StereoPannerRenderNode.create(node.id, int(render_quantum_size), pan_parameter.render_param()).render_node())
	mut panner := StereoPannerNode{
		node: node
		pan: pan_parameter
	}
	if count := options.channel_count { panner.set_channel_count(count)! }
	if mode := options.channel_count_mode { panner.set_channel_count_mode(mode)! }
	return panner
}

pub fn (mut panner StereoPannerNode) set_channel_count_mode(mode ChannelCountMode) ! {
	if mode == .max {
		return error("NotSupportedError: StereoPannerNode does not support 'max'")
	}
	panner.node.channel_count_mode = mode
	panner.node.queue_channel_config_update()
}

pub fn (mut panner StereoPannerNode) set_channel_count(count u32) ! {
	if count > 2 {
		return error('NotSupportedError: channel count greater than 2')
	}
	panner.node.set_channel_count(count)!
}

pub struct PeriodicWaveOptions {
pub:
	real                  ?[]f32
	imag                  ?[]f32
	disable_normalization bool
}

pub struct PeriodicWave {
pub:
	real      []f32
	imag      []f32
	normalize bool
}

pub fn new_periodic_wave(options PeriodicWaveOptions) !PeriodicWave {
	has_real := options.real != none
	has_imag := options.imag != none
	mut real := if actual := options.real { actual.clone() } else { []f32{} }
	mut imag := if actual := options.imag { actual.clone() } else { []f32{} }
	if has_real && has_imag && (real.len != imag.len || real.len < 2) {
		return error('IndexSizeError: Real and imaginary arrays must have equal length of at least 2')
	}
	if has_real && !has_imag && real.len < 2 {
		return error('IndexSizeError: Real array must contain at least 2 elements')
	}
	if has_imag && !has_real && imag.len < 2 {
		return error('IndexSizeError: Imaginary array must contain at least 2 elements')
	}
	if !has_real && !has_imag {
		real = []f32{len: 2}
		imag = [f32(0), 1]
	} else if !has_real {
		real = []f32{len: imag.len}
	} else if !has_imag {
		imag = []f32{len: real.len}
	}
	real[0] = 0
	imag[0] = 0
	return PeriodicWave{
		real: real.clone()
		imag: imag.clone()
		normalize: !options.disable_normalization
	}
}

pub struct OscillatorOptions {
pub:
	type_         OscillatorType = .sine
	frequency     f32 = 440
	detune        f32
	periodic_wave ?PeriodicWave
	node          AudioNodeOptions
}

pub struct OscillatorNode {
pub mut:
	node          AudioNode
	type_         OscillatorType
	frequency     AudioParam
	detune        AudioParam
	periodic_wave ?PeriodicWave
}

pub fn (mut context BaseAudioContext) create_oscillator(options OscillatorOptions) !OscillatorNode {
	OscillatorNode.validate_options(options)!
	node := context.allocate_node(.oscillator, 0, 1, options.node, 2, .max, .speakers)!
	frequency := context.allocate_param(options.frequency, -context.nyquist_frequency(), context.nyquist_frequency(), .a_rate, false)
	detune := context.allocate_param(options.detune, -detune_limit(), detune_limit(), .a_rate, false)
	node.queue_render_node_creation(OscillatorRenderNode.create(node.id, int(render_quantum_size), frequency.render_param(), detune.render_param()).render_node())
	mut oscillator := OscillatorNode{
		node: node
		type_: options.type_
		frequency: frequency
		detune: detune
		periodic_wave: options.periodic_wave
	}
	oscillator.queue_waveform_update()
	return oscillator
}

pub fn OscillatorNode.validate_options(options OscillatorOptions) ! {
	if options.type_ == .custom && options.periodic_wave == none {
		return error("InvalidStateError: Oscillator type 'custom' requires PeriodicWave")
	}
}

pub fn (oscillator OscillatorNode) queue_waveform_update() {
	mut periodic_wave := ?&PeriodicWaveData(none)
	if wave := oscillator.periodic_wave {
		periodic_wave = wave.render_data()
	}
	oscillator.node.enqueue_control_message(ControlMessage{
		kind: .node_message
		node_message: NodeMessage{
			node_id: oscillator.node.id
			kind: .set_oscillator_waveform
			oscillator_type: oscillator.type_
			periodic_wave: periodic_wave
		}
	})
}

pub fn (mut oscillator OscillatorNode) set_type(value OscillatorType) ! {
	if value == .custom && oscillator.type_ != .custom {
		return error("InvalidStateError: Oscillator type cannot be changed to 'custom'")
	}
	oscillator.type_ = value
	oscillator.periodic_wave = none
	oscillator.queue_waveform_update()
}

pub fn (mut oscillator OscillatorNode) set_periodic_wave(wave PeriodicWave) {
	oscillator.periodic_wave = wave
	oscillator.type_ = .custom
	oscillator.queue_waveform_update()
}

pub struct AudioBufferSourceOptions {
pub:
	buffer        ?AudioBuffer
	detune        f32
	loop_         bool
	loop_end      f64
	loop_start    f64
	playback_rate f32 = 1
	node          AudioNodeOptions
}

pub struct AudioBufferSourceNode {
pub mut:
	node          AudioNode
	buffer        ?AudioBuffer
	playback_rate AudioParam
	detune        AudioParam
	loop_         bool
	loop_start    f64
	loop_end      f64
	buffer_set    bool
}

pub fn (mut context BaseAudioContext) create_buffer_source(options AudioBufferSourceOptions) !AudioBufferSourceNode {
	node := context.allocate_node(.buffer_source, 0, 1, AudioNodeOptions{}, 2, .max, .speakers)!
	playback_rate := context.allocate_param(options.playback_rate, float_lowest, float_highest, .k_rate, true)
	detune := context.allocate_param(options.detune, float_lowest, float_highest, .k_rate, true)
	node.queue_render_node_creation(AudioBufferSourceRenderNode.create(node.id, int(render_quantum_size), playback_rate.render_param(), detune.render_param()).render_node())
	mut source := AudioBufferSourceNode{
		node: node
		playback_rate: playback_rate
		detune: detune
		loop_: options.loop_
		loop_start: options.loop_start
		loop_end: options.loop_end
	}
	source.set_buffer(options.buffer)!
	source.queue_parameters_update(none, false)
	return source
}

pub fn (source AudioBufferSourceNode) queue_parameters_update(buffer ?&AudioBufferContents,
	update_buffer bool) {
	source.node.enqueue_control_message(ControlMessage{
		kind: .node_message
		node_message: NodeMessage{
			node_id: source.node.id
			kind: .set_buffer_source_parameters
			loop_: source.loop_
			loop_start: source.loop_start
			loop_end: source.loop_end
			buffer: buffer
			update_buffer: update_buffer
		}
	})
}

fn (mut source AudioBufferSourceNode) acquire_buffer_contents() ?&AudioBufferContents {
	buffer := source.buffer or { return none }
	mut mutable_buffer := buffer
	contents := mutable_buffer.acquire_contents()
	source.buffer = mutable_buffer
	return contents
}

pub fn (mut source AudioBufferSourceNode) set_buffer(buffer ?AudioBuffer) ! {
	if buffer != none && source.buffer_set {
		return error('InvalidStateError: Buffer has already been set')
	}
	if buffer != none {
		source.buffer_set = true
	}
	source.buffer = buffer
	if source.node.source_started {
		source.queue_parameters_update(source.acquire_buffer_contents(), true)
	}
}

pub fn (mut source AudioBufferSourceNode) start(when ?f64, offset ?f64, duration ?f64) ! {
	if source.node.source_started {
		return error('InvalidStateError: AudioBufferSourceNode has already been started')
	}
	for value in [when or { 0 }, offset or { 0 }, duration or { 0 }] {
		if value < 0 {
			return error('RangeError: start arguments must not be negative')
		}
	}
	source.node.source_started = true
	source.node.graph.playing_sources[source.node.id] = true
	source.node.enqueue_control_message(ControlMessage{
		kind: .node_message
		node_message: NodeMessage{
			node_id: source.node.id
			kind: .start_buffer_source
			when: when or { 0 }
			offset: offset or { 0 }
			duration: duration
			buffer: source.acquire_buffer_contents()
		}
	})
}

pub struct ScriptProcessorNode {
pub mut:
	node           AudioNode
	buffer_size    i32
	onaudioprocess bool
pub:
	input_channels  u32
	output_channels u32
}

pub fn (mut context BaseAudioContext) create_script_processor(buffer_size i32, input_channels u32, output_channels u32) !ScriptProcessorNode {
	actual_buffer_size := if buffer_size == 0 { 1024 } else { buffer_size }
	ScriptProcessorNode.validate_options(actual_buffer_size, input_channels, output_channels)!
	// ScriptProcessorNode overrides channelCount and permits zero input channels
	// when it has outputs, so construction must bypass AudioNode's generic
	// non-zero channel-count setter.
	context.next_id++
	node := AudioNode{
		id: context.next_id
		context_id: context.id
		kind: .script_processor
		number_of_inputs: 1
		number_of_outputs: 1
		graph: context.graph
		channel_count: input_channels
		channel_count_mode: .explicit
		channel_interpretation: .speakers
	}
	return ScriptProcessorNode{
		node: node
		buffer_size: actual_buffer_size
		input_channels: input_channels
		output_channels: output_channels
	}
}

pub fn ScriptProcessorNode.validate_options(buffer_size i32, input_channels u32,
	output_channels u32) ! {
	if input_channels == 0 && output_channels == 0 {
		return error('IndexSizeError: Input and output channels cannot both be zero')
	}
	if input_channels > max_number_of_channels {
		return error('NotSupportedError: Invalid number of input channels')
	}
	if output_channels > max_number_of_channels {
		return error('NotSupportedError: Invalid number of output channels')
	}
	if buffer_size !in [256, 512, 1024, 2048, 4096, 8192, 16384] {
		return error('IndexSizeError: Unsupported buffer size')
	}
}

pub fn (mut processor ScriptProcessorNode) set_buffer_size_without_validation(size i32) {
	processor.buffer_size = size
}

pub fn (_ ScriptProcessorNode) set_channel_count(_ u32) ! {
	return error('InvalidStateError: Cannot modify ScriptProcessorNode channel count')
}

pub fn (mut processor ScriptProcessorNode) set_channel_count_mode(mode ChannelCountMode) ! {
	if mode != .explicit {
		return error("InvalidStateError: channel count mode must be 'explicit'")
	}
	processor.node.channel_count_mode = mode
}

pub fn (mut processor ScriptProcessorNode) set_buffer_size(size i32) ! {
	if size !in [256, 512, 1024, 2048, 4096, 8192, 16384] {
		return error('IndexSizeError: Unsupported buffer size')
	}
	processor.set_buffer_size_without_validation(size)
}
