module webaudio

import math

fn test_analyser_validates_fft_and_preserves_current_silence_boundary() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	mut analyser := context.base.create_analyser(AnalyserOptions{ fft_size: 32 }) or { panic(err) }
	assert analyser.frequency_bin_count() == 16
	mut time_bytes := []u8{len: 40, init: 255}
	analyser.get_byte_time_domain_data(mut time_bytes)
	assert time_bytes[..32] == []u8{len: 32, init: 128}
	assert time_bytes[32] == 255
	mut time_floats := []f32{len: 40, init: 1}
	analyser.get_float_time_domain_data(mut time_floats)
	assert time_floats[..32] == []f32{len: 32}
	assert time_floats[32] == 1
	mut frequency_bytes := []u8{len: 16, init: 99}
	analyser.get_byte_frequency_data(mut frequency_bytes)
	assert frequency_bytes == []u8{len: 16}
	analyser.set_fft_size(30) or {
		assert err.msg().contains('power of 2')
		return
	}
	assert false
}

fn test_analyser_decibel_and_smoothing_setters_are_transactional() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	mut analyser := context.base.create_analyser(AnalyserOptions{}) or { panic(err) }
	analyser.set_min_decibels(-20) or { assert err.msg().contains('greater') }
	assert analyser.min_decibels == -100
	analyser.set_smoothing_time_constant(1.1) or {
		assert err.msg().contains('between')
		return
	}
	assert false
}

fn test_analyser_fft_uses_radix_two_transform_and_db_conversion() {
	mut impulse := []f32{len: 32}
	impulse[0] = 1
	magnitudes := apply_a_fourier_transform(impulse)
	assert magnitudes.len == 16
	for magnitude in magnitudes {
		assert math.abs(magnitude - f32(1.0 / 32.0)) < 0.00001
	}
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut analyser := context.base.create_analyser(AnalyserOptions{
		fft_size: 32
		smoothing_time_constant: 0
	}) or { panic(err) }
	decibels := analyser.conversion_to_d_b([f32(1), 0.1, 0])
	assert decibels[0] == 0
	assert math.abs(decibels[1] + 20) < 0.00001
	assert math.is_inf(decibels[2], -1)
}

fn analyser_render_test_source(mut node RenderNode, _ mut RenderGraph,
	context RenderContext) {
	mut output := unsafe { &AudioBus(node.output(0)) }
	output.set_channel_count(2)
	output.set_channel(0, []f32{len: context.quantum_size, init: f32(2 * (index + 1))})
	output.set_channel(1, []f32{len: context.quantum_size, init: f32(4 * (index + 1))})
}

fn test_analyser_render_node_passes_through_and_records_recent_mono_input() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut analyser := context.base.create_analyser(AnalyserOptions{ fft_size: 32 }) or {
		panic(err)
	}
	mut graph := RenderGraph.create()
	mut source := RenderNode.create(1, 0, 1, int(render_quantum_size), 1)
	source.set_process_callback(analyser_render_test_source)
	graph.apply_control_messages([
		ControlMessage{ kind: .add_node, render_node: source },
		ControlMessage{ kind: .add_node, render_node: analyser.render_node().render_node() },
		ControlMessage{
			kind: .replace_connections
			node_id: 1
			node_connections: [OutgoingNodeConnection{
				destination: analyser.node.id
			}]
		},
	])
	graph.set_destination(analyser.node.id)
	graph.render_quantum(RenderContext{
		sample_rate: 48_000
		quantum_size: int(render_quantum_size)
	})
	output := analyser.render_node().render_node().output(0)
	assert output.channel_count() == 2
	assert output.channel(0)[0] == 2
	assert output.channel(0)[127] == 256
	assert output.channel(1)[0] == 4
	assert output.channel(1)[127] == 512
	history := analyser.current_time_domain_data()
	assert history.len == 32
	assert history[0] == 291
	assert history[31] == 384
}
