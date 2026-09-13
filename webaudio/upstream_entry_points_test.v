module webaudio

fn test_upstream_buffer_parameter_and_node_entry_points() {
	buffer := AudioBuffer.create(2, 4, 48_000)!
	assert buffer.sample_rate() == 48_000
	assert buffer.length() == 4
	assert buffer.get_channel_data(1)!.len == 4

	mut context := make_base_context(90, 48_000, 2, false)!
	parameter := AudioParam.create(mut context, 0.5, -1, 1, .a_rate, false)
	assert parameter.default_value() == 0.5
	assert parameter.min_value() == -1
	assert parameter.max_value() == 1
	assert parameter.context() == context.id
	assert parameter.automation_rate() == .a_rate

	mut source := context.allocate_node(.gain, 1, 1, AudioNodeOptions{}, 2, .max, .speakers)!
	mut destination := context.allocate_node(.gain, 1, 1, AudioNodeOptions{}, 2, .max, .speakers)!
	source.connect(mut destination, 0, 0)!
	assert source.output_connection_records().len == 1
	assert destination.input_connection_records().len == 1
	assert source.channel_count() == 2
	source.destination_output_input_disconnect(mut destination, 0, 0)!
	assert source.output_connection_records().len == 0
	assert destination.input_connection_records().len == 0
	assert source.context() == context.id
	assert source.node_id() != destination.node_id()
}

fn test_upstream_context_destination_and_scheduled_source_entry_points() {
	mut context := new_audio_context(91, f32(44_100), true)!
	assert context.base.destination().number_of_inputs() == 1
	assert context.base.destination().number_of_outputs() == 1
	assert context.base.destination().max_channel_count() == 2
	listener := AudioListener.create(mut context.base)
	assert listener.forward_x.id != listener.up_z.id
	next_parameter := AudioParam.create(mut context.base, 0, -1, 1, .a_rate, false)
	assert next_parameter.id > listener.up_z.id
	mut destination := context.base.destination()
	destination.set_channel_count(1)!
	assert destination.channel_count == 1
	assert context.get_output_timestamp() == AudioTimestamp{}
	assert context.start_rendering_audio_graph()

	mut source := context.base.allocate_node(.oscillator, 0, 1, AudioNodeOptions{}, 2, .max, .speakers)!
	assert !source.source_started()
	source.start(0)!
	assert source.source_started()
	source.set_onended(true)
	assert source.onended()
}

fn test_upstream_concrete_node_and_analyser_entry_points() {
	mut context := make_base_context(92, 44_100, 2, false)!
	gain := GainNode.construct_impl(mut context, GainOptions{})!
	assert gain.number_of_inputs() == 1
	assert gain.number_of_outputs() == 1
	assert gain.gain().default_value() == 1

	mut analyser := AnalyserNode.construct_impl(mut context, AnalyserOptions{ fft_size: 32 })!
	assert analyser.fft_size() == 32
	assert analyser.min_decibels() == -100
	assert analyser.max_decibels() == -30
	assert analyser.smoothing_time_constant() == 0.8
	windowed := analyser.apply_a_blackman_window([]f32{len: 32, init: 1})
	assert windowed.len == 32
	assert apply_a_fourier_transform(windowed).len == 16
	assert analyser.smoothing_over_time(apply_a_fourier_transform(windowed)).len == 16
	assert analyser.conversion_to_d_b([f32(1)])[0] == 0
	assert analyser.number_of_inputs() == 1
	assert analyser.number_of_outputs() == 1
}

fn test_static_script_processor_constructor_does_not_apply_base_context_default() {
	mut context := new_audio_context(96, none, true)!
	ScriptProcessorNode.create(mut context.base, 0, 2, 2) or {
		assert err.msg().contains('IndexSizeError')
		return
	}
	assert false
}

fn test_upstream_panner_and_offline_completion_entry_points() {
	mut base := make_base_context(93, 44_100, 2, false)!
	mut panner := PannerNode.construct_impl(mut base, PannerOptions{})!
	panner.set_panning_model(.hrtf)
	panner.set_distance_model(.linear)
	panner.set_cone_inner_angle(180)
	panner.set_cone_outer_angle(270)
	panner.set_ref_distance(2)!
	panner.set_max_distance(200)!
	panner.set_rolloff_factor(0.5)!
	panner.set_cone_outer_gain(0.25)!
	assert panner.panning_model() == .hrtf
	assert panner.distance_model() == .linear
	assert panner.cone_inner_angle() == 180
	assert panner.cone_outer_angle() == 270
	assert panner.ref_distance() == 2
	assert panner.max_distance() == 200
	assert panner.rolloff_factor() == 0.5
	assert panner.cone_outer_gain() == 0.25

	mut oscillator := OscillatorNode.construct_impl(mut base, OscillatorOptions{})!
	assert oscillator.type_() == .sine
	buffer := new_audio_buffer(1, 2, 44_100)!
	mut source := AudioBufferSourceNode.construct_impl(mut base, AudioBufferSourceOptions{})!
	source.set_buffer(buffer)!
	assert source.buffer()?.length == 2
	processor := ScriptProcessorNode.create(mut base, 256, 1, 1)!
	assert processor.buffer_size() == 256
	assert processor.channel_count() == 1

	mut offline := OfflineAudioContext.construct_impl(94, OfflineAudioContextOptions{
		number_of_channels: 2
		length: 8
		sample_rate: 44_100
	})!
	assert offline.base.destination().max_channel_count() == 2
	mut offline_destination := offline.base.destination()
	offline_destination.set_channel_count(1) or {
		assert err.msg().contains('OfflineAudioContext')
	}
	offline.set_oncomplete(true)
	assert offline.oncomplete()
	result := offline.begin_offline_rendering()
	assert result.promise.state == .fulfilled
	event := result.event or { panic('completion event is missing') }
	assert event.rendered_buffer() != none
}
