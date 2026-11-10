module webaudio

fn test_audio_param_cancellation_keeps_the_intrinsic_value_seen_by_both_sides() {
	for rate in [AutomationRate.a_rate, .k_rate] {
		mut graph := RenderGraph.create()
		mut parameter := new_audio_param(1, 1, &AudioGraphState{}, 1, -100, 100, rate, false)
		copy := parameter
		parameter.set_value(3) or { panic(err) }
		parameter.cancel_scheduled_values(0) or { panic(err) }
		mut output := []f32{len: 4}
		parameter.render_param_.compute(mut graph, RenderContext{sample_rate: 4, quantum_size: 4}, mut output)
		assert output == [f32(3), 3, 3, 3]
		assert copy.value() == 3

		parameter.set_value_at_time(3, 0) or { panic(err) }
		parameter.linear_ramp_to_value_at_time(11, 2) or { panic(err) }
		parameter.render_param_.compute(mut graph, RenderContext{sample_rate: 4, quantum_size: 4, quantum_start_frame: 4}, mut output)
		assert output[0] == 7
		assert copy.value() == 7
		parameter.cancel_scheduled_values(0) or { panic(err) }
		parameter.render_param_.compute(mut graph, RenderContext{sample_rate: 4, quantum_size: 4, quantum_start_frame: 8}, mut output)
		assert output == [f32(7), 7, 7, 7]
		assert parameter.value() == 7
	}
}

fn test_audio_worklet_sampling_updates_the_shared_intrinsic_value() {
	mut parameter := new_audio_param(1, 1, &AudioGraphState{}, 0, -100, 100, .a_rate, false)
	parameter.set_value_at_time(2, 0) or { panic(err) }
	parameter.linear_ramp_to_value_at_time(10, 2) or { panic(err) }
	assert audio_worklet_parameter_block(&parameter, 4, 4, 4) == [f32(6), 7, 8, 9]
	assert parameter.value() == 6
	parameter.cancel_scheduled_values(0) or { panic(err) }
	assert audio_worklet_parameter_block(&parameter, 8, 4, 4) == [f32(6), 6, 6, 6]
	mut empty := []f32{}
	parameter.timeline.sample(10, 1, mut empty)
	assert parameter.value() == 6
}
