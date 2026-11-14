// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the public and internal entry points in the upstream WebAudio
// implementation. V has no function overloading, so overloads after the first
// use a descriptive prefix while retaining the complete upstream method name.
module webaudio

import math

// AudioBuffer
pub fn AudioBuffer.create(number_of_channels u32, length u32, sample_rate f32) !AudioBuffer {
	return new_audio_buffer(number_of_channels, length, sample_rate)
}

pub fn AudioBuffer.construct_impl(options AudioBufferOptions) !AudioBuffer {
	return AudioBuffer.from_options(options)
}

pub fn (buffer AudioBuffer) sample_rate() f32 {
	return buffer.sample_rate
}

pub fn (buffer AudioBuffer) length() u32 {
	return buffer.length
}

pub fn (buffer &AudioBuffer) get_channel_data(channel u32) ![]f32 {
	return buffer.channel_data(channel)
}

// AudioParam
pub fn AudioParam.create(mut context BaseAudioContext, default_value f32, min_value f32,
	max_value f32, rate AutomationRate, fixed bool) AudioParam {
	return context.allocate_param(default_value, min_value, max_value, rate, fixed)
}

pub fn (parameter AudioParam) default_value() f32 {
	return parameter.default_value
}

pub fn (parameter AudioParam) min_value() f32 {
	return parameter.min_value
}

pub fn (parameter AudioParam) max_value() f32 {
	return parameter.max_value
}

pub fn (parameter AudioParam) context() u64 {
	return parameter.context_id
}

// AudioNode and AudioScheduledSourceNode's consolidated base representation.
pub fn (mut node AudioNode) initialize_audio_node_options(options AudioNodeOptions,
	defaults AudioNodeOptions) ! {
	node.initialize_options(options, defaults.channel_count or { u32(2) }, defaults.channel_count_mode or { ChannelCountMode.max }, defaults.channel_interpretation or { ChannelInterpretation.speakers })!
}

pub fn (mut source AudioNode) connect(mut destination AudioNode, output u32, input u32) ! {
	connect_nodes(mut source, mut destination, output, input)!
}

pub fn (mut source AudioNode) audio_param_connect(parameter AudioParam, output u32) ! {
	connect_param(mut source, parameter, output)!
}

pub fn (mut node AudioNode) disconnect() {
	node.disconnect_all()
}

pub fn (mut node AudioNode) output_disconnect(output u32) ! {
	node.disconnect_output(output)!
}

pub fn (mut source AudioNode) destination_disconnect(mut destination AudioNode) ! {
	disconnect_nodes(mut source, mut destination, none, none)!
}

pub fn (mut source AudioNode) destination_output_disconnect(mut destination AudioNode,
	output u32) ! {
	disconnect_nodes(mut source, mut destination, output, none)!
}

pub fn (mut source AudioNode) destination_output_input_disconnect(mut destination AudioNode,
	output u32, input u32) ! {
	disconnect_nodes(mut source, mut destination, output, input)!
}

pub fn (mut source AudioNode) parameter_disconnect(parameter AudioParam) ! {
	source.disconnect_parameter(parameter.id, none)!
}

pub fn (mut source AudioNode) parameter_output_disconnect(parameter AudioParam, output u32) ! {
	source.disconnect_parameter(parameter.id, output)!
}

pub fn (mut node AudioNode) set_channel_count_mode(mode ChannelCountMode) ! {
	node.channel_count_mode = mode
	node.queue_channel_config_update()
}

pub fn (node AudioNode) channel_count_mode() ChannelCountMode {
	return node.channel_count_mode
}

pub fn (mut node AudioNode) set_channel_interpretation(value ChannelInterpretation) ! {
	node.channel_interpretation = value
	node.queue_channel_config_update()
}

pub fn (node AudioNode) channel_interpretation() ChannelInterpretation {
	return node.channel_interpretation
}

pub fn (node AudioNode) context() u64 {
	return node.context_id
}

pub fn (node AudioNode) node_id() u64 {
	return node.id
}

pub fn (node AudioNode) onended() bool {
	return node.graph.onended_handlers[node.id] or { node.onended }
}

pub fn (mut node AudioNode) set_onended(value bool) {
	node.onended = value
	node.graph.onended_handlers[node.id] = value
}

pub fn (node AudioNode) ended_event_count() u32 {
	return node.graph.ended_event_counts[node.id] or { 0 }
}

pub fn (node AudioNode) source_started() bool {
	return node.source_started
}

pub fn (mut node AudioNode) set_source_started(value bool) {
	node.source_started = value
}

// BaseAudioContext and AudioContext
pub fn (mut context BaseAudioContext) set_onstatechange(value bool) {
	context.onstatechange = value
}

pub fn (context BaseAudioContext) onstatechange() bool {
	return context.onstatechange
}

pub fn (mut context BaseAudioContext) create_periodic_wave(real []f32, imag []f32,
	disable_normalization bool) !PeriodicWave {
	return new_periodic_wave(PeriodicWaveOptions{
		real: real
		imag: imag
		disable_normalization: disable_normalization
	})
}

pub fn BaseAudioContext.verify_audio_options_inside_nominal_range(sample_rate f32) ! {
	verify_sample_rate(sample_rate)!
}

pub fn BaseAudioContext.buffer_verify_audio_options_inside_nominal_range(number_of_channels u32,
	length u32, sample_rate f32) ! {
	verify_audio_options(number_of_channels, length, sample_rate)!
}

pub fn (mut context BaseAudioContext) queue_a_media_element_task(task fn ()) {
	context.media_element_tasks++
	task()
}

pub fn (mut context BaseAudioContext) queue_control_message(message ControlMessage) {
	context.control_messages.enqueue(message)
}

pub fn (mut context BaseAudioContext) add_playing_source(node AudioNode) {
	context.graph.playing_sources[node.id] = true
}

pub fn (mut context BaseAudioContext) handle_ended_sources(ended_nodes []u64) {
	context.media_element_tasks += u32(context.graph.handle_ended_sources(ended_nodes))
}

fn (mut graph AudioGraphState) handle_ended_sources(ended_nodes []u64) int {
	mut handled := 0
	for node_id in ended_nodes {
		if node_id !in graph.playing_sources {
			continue
		}
		graph.playing_sources.delete(node_id)
		graph.ended_event_counts[node_id] = (graph.ended_event_counts[node_id] or { 0 }) + 1
		handled++
	}
	return handled
}

pub fn (mut context BaseAudioContext) queue_a_decoding_operation(audio_data []u8,
	fully_active bool) DecodeResult {
	return context.decode_audio_data(audio_data, fully_active)
}

pub fn (context BaseAudioContext) destination() AudioDestinationNode {
	return context.destination
}

pub fn (context BaseAudioContext) sample_rate() f32 {
	return context.sample_rate
}

pub fn (context BaseAudioContext) current_time() f64 {
	return context.graph.current_time
}

pub fn (mut context BaseAudioContext) set_current_time(value f64) {
	context.graph.current_time = value
}

pub fn (context BaseAudioContext) listener() AudioListener {
	return context.listener
}

pub fn (context BaseAudioContext) state() AudioContextState {
	return context.state
}

pub fn (mut context BaseAudioContext) set_sample_rate(value f32) {
	context.sample_rate = value
	context.graph.sample_rate = value
}

pub fn (mut context BaseAudioContext) set_control_state(value AudioContextState) {
	context.state = value
}

pub fn (mut context BaseAudioContext) set_rendering_state(value AudioContextState) {
	context.rendering_state = value
}

pub fn (mut context BaseAudioContext) next_node_id() u64 {
	context.next_id++
	return context.next_id
}

pub fn AudioContext.construct_impl(id u64, options AudioContextOptions, fully_active bool) !AudioContext {
	return AudioContext.create_for_constructor(id, options, fully_active)
}

pub fn AudioContext.create_for_constructor(id u64, options AudioContextOptions,
	fully_active bool) !AudioContext {
	return new_audio_context_with_options(id, options, fully_active)
}

pub fn (context AudioContext) get_output_timestamp() AudioTimestamp {
	return context.output_timestamp()
}

pub fn (mut context AudioContext) start_rendering_audio_graph() bool {
	if !context.allowed_to_start {
		return false
	}
	if mut renderer := context.renderer {
		renderer.resume()
	}
	return true
}

pub fn (context AudioContext) base_latency() f64 {
	return context.base_latency
}

pub fn (context AudioContext) output_latency() f64 {
	return context.output_latency
}

// AudioListener
pub fn AudioListener.create(mut context BaseAudioContext) AudioListener {
	listener := new_audio_listener(context.id, context.next_id, context.graph)
	context.next_id += 9
	return listener
}

pub fn (listener AudioListener) forward_x() AudioParam {
	return listener.forward_x
}

pub fn (listener AudioListener) forward_y() AudioParam {
	return listener.forward_y
}

pub fn (listener AudioListener) forward_z() AudioParam {
	return listener.forward_z
}

pub fn (listener AudioListener) position_x() AudioParam {
	return listener.position_x
}

pub fn (listener AudioListener) position_y() AudioParam {
	return listener.position_y
}

pub fn (listener AudioListener) position_z() AudioParam {
	return listener.position_z
}

pub fn (listener AudioListener) up_x() AudioParam {
	return listener.up_x
}

pub fn (listener AudioListener) up_y() AudioParam {
	return listener.up_y
}

pub fn (listener AudioListener) up_z() AudioParam {
	return listener.up_z
}

// AnalyserNode
pub fn AnalyserNode.create(mut context BaseAudioContext, options AnalyserOptions) !AnalyserNode {
	return context.create_analyser(options)
}

pub fn AnalyserNode.construct_impl(mut context BaseAudioContext,
	options AnalyserOptions) !AnalyserNode {
	return AnalyserNode.create_for_constructor(mut context, options)
}

pub fn AnalyserNode.create_for_constructor(mut context BaseAudioContext,
	options AnalyserOptions) !AnalyserNode {
	AnalyserNode.validate_options(options)!
	return context.create_analyser(options)
}

pub fn (analyser AnalyserNode) apply_a_blackman_window(input []f32) []f32 {
	return analyser.apply_blackman_window(input)
}

pub fn apply_a_fourier_transform(input []f32) []f32 {
	if input.len == 0 {
		return []f32{}
	}
	return FFT.create(input.len).magnitudes(input)
}

// Keep the existing helper for callers that do not retain a fixed-size FFT.
pub fn radix2_fft(mut real []f32, mut imaginary []f32) {
	FFT.create(real.len).transform(mut real, mut imaginary, .forward)
}

pub fn (mut analyser AnalyserNode) smoothing_over_time(current_block []f32) []f32 {
	if analyser.previous_block.len != current_block.len {
		analyser.previous_block = []f32{len: current_block.len}
	}
	mut result := []f32{len: current_block.len}
	tau := f32(analyser.smoothing_time_constant)
	for index in 0 .. current_block.len {
		mut smoothed := tau * analyser.previous_block[index] + (1 - tau) * f32(math.abs(f64(current_block[index])))
		if math.is_nan(smoothed) || math.is_inf(smoothed, 0) {
			smoothed = 0
		}
		result[index] = smoothed
	}
	analyser.previous_block = result.clone()
	return result
}

pub fn (analyser AnalyserNode) conversion_to_d_b(input []f32) []f32 {
	mut result := []f32{cap: input.len}
	for value in input {
		result << if value > 0 { f32(20 * math.log10(f64(value))) } else { f32(math.inf(-1)) }
	}
	return result
}

pub fn (_ AnalyserNode) number_of_inputs() u32 {
	return 1
}

pub fn (_ AnalyserNode) number_of_outputs() u32 {
	return 1
}

// Concrete signal-processing nodes.
pub fn GainNode.create(mut context BaseAudioContext, options GainOptions) !GainNode {
	return context.construct_gain(options)
}

pub fn GainNode.construct_impl(mut context BaseAudioContext, options GainOptions) !GainNode {
	return GainNode.create_for_constructor(mut context, options)
}

pub fn GainNode.create_for_constructor(mut context BaseAudioContext,
	options GainOptions) !GainNode {
	return context.construct_gain(options)
}

pub fn (_ GainNode) number_of_inputs() u32 {
	return 1
}

pub fn (_ GainNode) number_of_outputs() u32 {
	return 1
}

pub fn (node GainNode) gain() AudioParam {
	return node.gain
}

pub fn ConstantSourceNode.create(mut context BaseAudioContext,
	options ConstantSourceOptions) !ConstantSourceNode {
	return context.construct_constant_source(options)
}

pub fn ConstantSourceNode.construct_impl(mut context BaseAudioContext,
	options ConstantSourceOptions) !ConstantSourceNode {
	return ConstantSourceNode.create_for_constructor(mut context, options)
}

pub fn ConstantSourceNode.create_for_constructor(mut context BaseAudioContext,
	options ConstantSourceOptions) !ConstantSourceNode {
	return context.construct_constant_source(options)
}

pub fn (_ ConstantSourceNode) number_of_inputs() u32 {
	return 0
}

pub fn (_ ConstantSourceNode) number_of_outputs() u32 {
	return 1
}

pub fn (node ConstantSourceNode) offset() AudioParam {
	return node.offset
}

pub fn DelayNode.create(mut context BaseAudioContext, options DelayOptions) !DelayNode {
	return context.construct_delay(options)
}

pub fn DelayNode.construct_impl(mut context BaseAudioContext, options DelayOptions) !DelayNode {
	return DelayNode.create_for_constructor(mut context, options)
}

pub fn DelayNode.create_for_constructor(mut context BaseAudioContext,
	options DelayOptions) !DelayNode {
	DelayNode.validate_options(options)!
	return context.construct_delay(options)
}

pub fn (_ DelayNode) number_of_inputs() u32 {
	return 1
}

pub fn (_ DelayNode) number_of_outputs() u32 {
	return 1
}

pub fn (node DelayNode) delay_time() AudioParam {
	return node.delay_time
}

pub fn DynamicsCompressorNode.create(mut context BaseAudioContext,
	options DynamicsCompressorOptions) !DynamicsCompressorNode {
	return context.create_dynamics_compressor(options)
}

pub fn DynamicsCompressorNode.construct_impl(mut context BaseAudioContext,
	options DynamicsCompressorOptions) !DynamicsCompressorNode {
	return DynamicsCompressorNode.create_for_constructor(mut context, options)
}

pub fn DynamicsCompressorNode.create_for_constructor(mut context BaseAudioContext,
	options DynamicsCompressorOptions) !DynamicsCompressorNode {
	return context.create_dynamics_compressor(options)
}

pub fn (_ DynamicsCompressorNode) number_of_inputs() u32 {
	return 1
}

pub fn (_ DynamicsCompressorNode) number_of_outputs() u32 {
	return 1
}

pub fn (node DynamicsCompressorNode) threshold() AudioParam {
	return node.threshold
}

pub fn (node DynamicsCompressorNode) knee() AudioParam {
	return node.knee
}

pub fn (node DynamicsCompressorNode) ratio() AudioParam {
	return node.ratio
}

pub fn (node DynamicsCompressorNode) attack() AudioParam {
	return node.attack
}

pub fn (node DynamicsCompressorNode) release() AudioParam {
	return node.release
}

pub fn (node DynamicsCompressorNode) reduction() f32 {
	return node.reduction
}

pub fn BiquadFilterNode.create(mut context BaseAudioContext,
	options BiquadFilterOptions) !BiquadFilterNode {
	return context.create_biquad_filter(options)
}

pub fn BiquadFilterNode.construct_impl(mut context BaseAudioContext,
	options BiquadFilterOptions) !BiquadFilterNode {
	return BiquadFilterNode.create_for_constructor(mut context, options)
}

pub fn BiquadFilterNode.create_for_constructor(mut context BaseAudioContext,
	options BiquadFilterOptions) !BiquadFilterNode {
	return context.create_biquad_filter(options)
}

pub fn (mut node BiquadFilterNode) set_type(value BiquadFilterType) {
	node.type_ = value
	node.node.enqueue_control_message(ControlMessage{
		kind: .node_message
		node_message: NodeMessage{
			node_id: node.node.id
			kind: .set_biquad_filter_type
			biquad_type: value
		}
	})
}

pub fn (node BiquadFilterNode) type_() BiquadFilterType {
	return node.type_
}

pub fn (node BiquadFilterNode) frequency() AudioParam {
	return node.frequency
}

pub fn (node BiquadFilterNode) detune() AudioParam {
	return node.detune
}

pub fn (node BiquadFilterNode) q() AudioParam {
	return node.q
}

pub fn (node BiquadFilterNode) gain() AudioParam {
	return node.gain
}

pub fn (_ BiquadFilterNode) number_of_inputs() u32 {
	return 1
}

pub fn (_ BiquadFilterNode) number_of_outputs() u32 {
	return 1
}

pub fn ChannelMergerNode.create(mut context BaseAudioContext,
	options ChannelMergerOptions) !ChannelMergerNode {
	return context.create_channel_merger(options.number_of_inputs, options.node)
}

pub fn ChannelMergerNode.construct_impl(mut context BaseAudioContext,
	options ChannelMergerOptions) !ChannelMergerNode {
	return ChannelMergerNode.create_for_constructor(mut context, options)
}

pub fn ChannelMergerNode.create_for_constructor(mut context BaseAudioContext,
	options ChannelMergerOptions) !ChannelMergerNode {
	ChannelMergerNode.validate_options(options)!
	return context.create_channel_merger(options.number_of_inputs, options.node)
}

pub fn (node ChannelMergerNode) number_of_inputs() u32 {
	return node.number_of_inputs
}

pub fn (_ ChannelMergerNode) number_of_outputs() u32 {
	return 1
}

pub fn ChannelSplitterNode.create(mut context BaseAudioContext,
	options ChannelSplitterOptions) !ChannelSplitterNode {
	return context.create_channel_splitter(options.number_of_outputs, options.node)
}

pub fn ChannelSplitterNode.construct_impl(mut context BaseAudioContext,
	options ChannelSplitterOptions) !ChannelSplitterNode {
	return ChannelSplitterNode.create_for_constructor(mut context, options)
}

pub fn ChannelSplitterNode.create_for_constructor(mut context BaseAudioContext,
	options ChannelSplitterOptions) !ChannelSplitterNode {
	ChannelSplitterNode.validate_options(options)!
	return context.create_channel_splitter(options.number_of_outputs, options.node)
}

pub fn (_ ChannelSplitterNode) number_of_inputs() u32 {
	return 1
}

pub fn (node ChannelSplitterNode) number_of_outputs() u32 {
	return node.number_of_outputs
}

pub fn StereoPannerNode.create(mut context BaseAudioContext,
	options StereoPannerOptions) !StereoPannerNode {
	return context.create_stereo_panner(options.pan, options.node)
}

pub fn StereoPannerNode.construct_impl(mut context BaseAudioContext,
	options StereoPannerOptions) !StereoPannerNode {
	return StereoPannerNode.create_for_constructor(mut context, options)
}

pub fn StereoPannerNode.create_for_constructor(mut context BaseAudioContext,
	options StereoPannerOptions) !StereoPannerNode {
	return context.create_stereo_panner(options.pan, options.node)
}

pub fn (_ StereoPannerNode) number_of_inputs() u32 {
	return 1
}

pub fn (_ StereoPannerNode) number_of_outputs() u32 {
	return 1
}

pub fn (node StereoPannerNode) pan() AudioParam {
	return node.pan
}

pub fn OscillatorNode.create(mut context BaseAudioContext,
	options OscillatorOptions) !OscillatorNode {
	return context.create_oscillator(options)
}

pub fn OscillatorNode.construct_impl(mut context BaseAudioContext,
	options OscillatorOptions) !OscillatorNode {
	return OscillatorNode.create_for_constructor(mut context, options)
}

pub fn OscillatorNode.create_for_constructor(mut context BaseAudioContext,
	options OscillatorOptions) !OscillatorNode {
	OscillatorNode.validate_options(options)!
	return context.create_oscillator(options)
}

pub fn (node OscillatorNode) frequency() AudioParam {
	return node.frequency
}

pub fn (node OscillatorNode) detune() AudioParam {
	return node.detune
}

pub fn (node OscillatorNode) type_() OscillatorType {
	return node.type_
}

pub fn (_ OscillatorNode) number_of_inputs() u32 {
	return 0
}

pub fn (_ OscillatorNode) number_of_outputs() u32 {
	return 1
}

pub fn PeriodicWave.construct_impl(_ BaseAudioContext,
	options PeriodicWaveOptions) !PeriodicWave {
	return new_periodic_wave(options)
}

pub fn AudioBufferSourceNode.create(mut context BaseAudioContext,
	options AudioBufferSourceOptions) !AudioBufferSourceNode {
	return context.create_buffer_source(options)
}

pub fn AudioBufferSourceNode.construct_impl(mut context BaseAudioContext,
	options AudioBufferSourceOptions) !AudioBufferSourceNode {
	return AudioBufferSourceNode.create_for_constructor(mut context, options)
}

pub fn AudioBufferSourceNode.create_for_constructor(mut context BaseAudioContext,
	options AudioBufferSourceOptions) !AudioBufferSourceNode {
	return context.create_buffer_source(options)
}

pub fn (source AudioBufferSourceNode) playback_rate() AudioParam {
	return source.playback_rate
}

pub fn (source AudioBufferSourceNode) detune() AudioParam {
	return source.detune
}

pub fn (source AudioBufferSourceNode) buffer() ?AudioBuffer {
	return source.buffer
}

pub fn (mut source AudioBufferSourceNode) set_loop(value bool) {
	source.loop_ = value
	source.queue_parameters_update(none, false)
}

pub fn (source AudioBufferSourceNode) loop() bool {
	return source.loop_
}

pub fn (mut source AudioBufferSourceNode) set_loop_start(value f64) {
	source.loop_start = value
	source.queue_parameters_update(none, false)
}

pub fn (source AudioBufferSourceNode) loop_start() f64 {
	return source.loop_start
}

pub fn (mut source AudioBufferSourceNode) set_loop_end(value f64) {
	source.loop_end = value
	source.queue_parameters_update(none, false)
}

pub fn (source AudioBufferSourceNode) loop_end() f64 {
	return source.loop_end
}

pub fn (_ AudioBufferSourceNode) number_of_inputs() u32 {
	return 0
}

pub fn (_ AudioBufferSourceNode) number_of_outputs() u32 {
	return 1
}

pub fn ScriptProcessorNode.create(mut context BaseAudioContext, buffer_size i32,
	input_channels u32, output_channels u32) !ScriptProcessorNode {
	// BaseAudioContext::create_script_processor performs the zero-to-default
	// conversion before entering this static constructor. A direct invocation
	// of the upstream constructor rejects zero in set_buffer_size().
	if buffer_size == 0 {
		return error('IndexSizeError: Unsupported buffer size')
	}
	ScriptProcessorNode.validate_options(buffer_size, input_channels, output_channels)!
	return context.create_script_processor(buffer_size, input_channels, output_channels)
}

pub fn (processor ScriptProcessorNode) onaudioprocess() bool {
	return processor.onaudioprocess
}

pub fn (processor ScriptProcessorNode) buffer_size() i32 {
	return processor.buffer_size
}

pub fn (processor ScriptProcessorNode) channel_count() u32 {
	return processor.input_channels
}

pub fn (mut processor ScriptProcessorNode) set_onaudioprocess(value bool) {
	processor.onaudioprocess = value
}

pub fn (_ ScriptProcessorNode) number_of_inputs() u32 {
	return 1
}

pub fn (_ ScriptProcessorNode) number_of_outputs() u32 {
	return 1
}

// AudioDestinationNode and MediaElementAudioSourceNode
pub fn AudioDestinationNode.construct_impl(context_id u64, channel_count u32,
	offline bool) !AudioDestinationNode {
	return AudioDestinationNode.create(context_id, &AudioGraphState{}, channel_count, offline)
}

pub fn (destination AudioDestinationNode) max_channel_count() u32 {
	return destination.max_channel_count
}

pub fn (mut destination AudioDestinationNode) set_channel_count(count u32) ! {
	if count == destination.channel_count {
		return
	}
	if destination.offline {
		return error('InvalidStateError: Cannot change channel count in an OfflineAudioContext')
	}
	if count < 1 || count > destination.max_channel_count {
		return error('IndexSizeError: Channel index is out of range')
	}
	destination.AudioNode.set_channel_count(count)!
}

pub fn (_ AudioDestinationNode) number_of_inputs() u32 {
	return 1
}

pub fn (_ AudioDestinationNode) number_of_outputs() u32 {
	return 1
}

pub fn MediaElementAudioSourceNode.create(mut context AudioContext,
	media_element_id string) !MediaElementAudioSourceNode {
	return context.create_media_element_source(media_element_id)
}

pub fn MediaElementAudioSourceNode.construct_impl(mut context AudioContext,
	media_element_id string) !MediaElementAudioSourceNode {
	return MediaElementAudioSourceNode.create_for_constructor(mut context, media_element_id)
}

pub fn MediaElementAudioSourceNode.create_for_constructor(mut context AudioContext,
	media_element_id string) !MediaElementAudioSourceNode {
	return context.create_media_element_source(media_element_id)
}

pub fn (_ MediaElementAudioSourceNode) number_of_inputs() u32 {
	return 0
}

pub fn (_ MediaElementAudioSourceNode) number_of_outputs() u32 {
	return 1
}

pub fn (source MediaElementAudioSourceNode) media_element() string {
	return source.media_element_id
}

// PannerNode
pub fn PannerNode.create(mut context BaseAudioContext, options PannerOptions) !PannerNode {
	return context.create_panner(options)
}

pub fn PannerNode.construct_impl(mut context BaseAudioContext,
	options PannerOptions) !PannerNode {
	return PannerNode.create_for_constructor(mut context, options)
}

pub fn PannerNode.create_for_constructor(mut context BaseAudioContext,
	options PannerOptions) !PannerNode {
	PannerNode.validate_options(options)!
	return context.create_panner(options)
}

pub fn (_ PannerNode) number_of_inputs() u32 {
	return 1
}

pub fn (_ PannerNode) number_of_outputs() u32 {
	return 1
}

pub fn (node PannerNode) position_x() AudioParam {
	return node.position_x
}

pub fn (node PannerNode) position_y() AudioParam {
	return node.position_y
}

pub fn (node PannerNode) position_z() AudioParam {
	return node.position_z
}

pub fn (node PannerNode) orientation_x() AudioParam {
	return node.orientation_x
}

pub fn (node PannerNode) orientation_y() AudioParam {
	return node.orientation_y
}

pub fn (node PannerNode) orientation_z() AudioParam {
	return node.orientation_z
}

pub fn (node PannerNode) panning_model() PanningModelType {
	return node.panning_model
}

pub fn (mut node PannerNode) set_panning_model(value PanningModelType) {
	node.panning_model = value
	node.queue_panner_parameters_update()
}

pub fn (node PannerNode) distance_model() DistanceModelType {
	return node.distance_model
}

pub fn (mut node PannerNode) set_distance_model(value DistanceModelType) {
	node.distance_model = value
	node.queue_panner_parameters_update()
}

pub fn (node PannerNode) cone_inner_angle() f64 {
	return node.cone_inner_angle
}

pub fn (mut node PannerNode) set_cone_inner_angle(value f64) {
	node.cone_inner_angle = value
	node.queue_panner_parameters_update()
}

pub fn (node PannerNode) cone_outer_angle() f64 {
	return node.cone_outer_angle
}

pub fn (mut node PannerNode) set_cone_outer_angle(value f64) {
	node.cone_outer_angle = value
	node.queue_panner_parameters_update()
}

pub fn (node PannerNode) ref_distance() f64 {
	return node.ref_distance
}

pub fn (node PannerNode) max_distance() f64 {
	return node.max_distance
}

pub fn (node PannerNode) rolloff_factor() f64 {
	return node.rolloff_factor
}

pub fn (node PannerNode) cone_outer_gain() f64 {
	return node.cone_outer_gain
}

// OfflineAudioContext and its completion event.
pub fn OfflineAudioContext.construct_impl(id u64,
	options OfflineAudioContextOptions) !OfflineAudioContext {
	return OfflineAudioContext.create_for_constructor(id, options)
}

pub fn OfflineAudioContext.create_for_constructor(id u64,
	options OfflineAudioContextOptions) !OfflineAudioContext {
	return new_offline_audio_context_with_options(id, options)
}

pub fn OfflineAudioContext.positional_construct_impl(id u64, number_of_channels u32,
	length u32, sample_rate f32) !OfflineAudioContext {
	return new_offline_audio_context(id, number_of_channels, length, sample_rate)
}

pub fn (mut context OfflineAudioContext) begin_offline_rendering() OfflineRenderResult {
	return context.start_rendering()
}

pub fn (context OfflineAudioContext) length() u32 {
	return context.length
}

pub fn (context OfflineAudioContext) oncomplete() bool {
	return context.oncomplete
}

pub fn (mut context OfflineAudioContext) set_oncomplete(value bool) {
	context.oncomplete = value
}

pub fn OfflineAudioCompletionEvent.construct_impl(event_type string,
	rendered_buffer ?AudioBuffer) OfflineAudioCompletionEvent {
	return OfflineAudioCompletionEvent.create(event_type, rendered_buffer)
}

pub fn OfflineAudioCompletionEvent.create(event_type string,
	rendered_buffer ?AudioBuffer) OfflineAudioCompletionEvent {
	return OfflineAudioCompletionEvent{
		event_type: event_type
		rendered_buffer: rendered_buffer
	}
}

pub fn (event OfflineAudioCompletionEvent) rendered_buffer() ?AudioBuffer {
	return event.rendered_buffer
}
