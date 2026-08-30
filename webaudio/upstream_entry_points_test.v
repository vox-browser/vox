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

	mut source := context.allocate_node(.gain, 1, 1, AudioNodeOptions{}, 2, .max,
		.speakers)!
	mut destination := context.allocate_node(.gain, 1, 1, AudioNodeOptions{}, 2, .max,
		.speakers)!
	source.connect(mut destination, 0, 0)!
	assert source.output_connections.len == 1
	assert destination.input_connections.len == 1
	source.destination_output_input_disconnect(mut destination, 0, 0)!
	assert source.output_connections.len == 0
	assert destination.input_connections.len == 0
	assert source.context() == context.id
	assert source.node_id() != destination.node_id()
}

fn test_upstream_context_destination_and_scheduled_source_entry_points() {
	mut context := new_audio_context(91, f32(44_100), true)!
	assert context.base.destination().number_of_inputs() == 1
	assert context.base.destination().number_of_outputs() == 1
	assert context.base.destination().max_channel_count() == 2
	mut destination := context.base.destination()
	destination.set_channel_count(1)!
	assert destination.channel_count == 1
	assert context.get_output_timestamp() == AudioTimestamp{}
	assert context.start_rendering_audio_graph()

	mut source := context.base.allocate_node(.oscillator, 0, 1, AudioNodeOptions{}, 2,
		.max, .speakers)!
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

	mut analyser := AnalyserNode.construct_impl(mut context, AnalyserOptions{fft_size: 32})!
	windowed := analyser.apply_a_blackman_window([]f32{len: 32, init: 1})
	assert windowed.len == 32
	assert apply_a_fourier_transform(windowed) == []f32{len: 32}
	assert analyser.smoothing_over_time(windowed).len == 32
	assert analyser.conversion_to_d_b([f32(1)])[0] == 0
	assert analyser.number_of_inputs() == 1
	assert analyser.number_of_outputs() == 1
}

fn test_upstream_panner_and_offline_completion_entry_points() {
	mut base := make_base_context(93, 44_100, 2, false)!
	mut panner := PannerNode.construct_impl(mut base, PannerOptions{})!
	panner.set_panning_model(.hrtf)
	panner.set_distance_model(.linear)
	panner.set_cone_inner_angle(180)
	panner.set_cone_outer_angle(270)
	assert panner.panning_model() == .hrtf
	assert panner.distance_model() == .linear
	assert panner.cone_inner_angle() == 180
	assert panner.cone_outer_angle() == 270

	mut offline := OfflineAudioContext.construct_impl(94, OfflineAudioContextOptions{
		number_of_channels: 2
		length:             8
		sample_rate:        44_100
	})!
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
