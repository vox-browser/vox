module webaudio

import math

fn test_oscillator_render_node_generates_sine_and_tracks_phase() {
	mut graph := RenderGraph.create()
	frequency := RenderAudioParam.create(AudioParamTimeline.create(1), -2, 2, .a_rate)
	detune := RenderAudioParam.create(AudioParamTimeline.create(0), -1200, 1200, .a_rate)
	oscillator := OscillatorRenderNode.create(1, 4, frequency, detune)
	graph.apply_control_messages([
		ControlMessage{ kind: .add_node, render_node: oscillator.render_node() },
		ControlMessage{
			kind: .node_message
			node_message: NodeMessage{ node_id: 1, kind: .start_source }
		},
	])
	graph.render_quantum(RenderContext{
		sample_rate: 4
		quantum_size: 4
	})
	samples := oscillator.render_node().output(0).channel(0)
	assert math.abs(samples[0]) < 0.00001
	assert math.abs(samples[1] - 1) < 0.00001
	assert math.abs(samples[2]) < 0.00001
	assert math.abs(samples[3] + 1) < 0.00001
}

fn test_oscillator_render_node_band_limits_builtin_waveforms() {
	frequency := RenderAudioParam.create(AudioParamTimeline.create(1), -10, 10, .a_rate)
	detune := RenderAudioParam.create(AudioParamTimeline.create(0), -1200, 1200, .a_rate)
	mut oscillator := OscillatorRenderNode.create(1, 1, frequency, detune)
	oscillator.handle_message(NodeMessage{
		node_id: 1
		kind: .set_oscillator_waveform
		oscillator_type: .square
	})
	assert math.abs(oscillator.sample_waveform(math.pi / 2.0, 100, 100) - f32(4.0 / math.pi)) < 0.00001
	oscillator.handle_message(NodeMessage{
		node_id: 1
		kind: .set_oscillator_waveform
		oscillator_type: .triangle
	})
	assert math.abs(oscillator.sample_waveform(math.pi / 2.0, 100, 100) - f32(8.0 / (math.pi * math.pi))) < 0.00001
}

fn test_oscillator_render_node_normalizes_custom_periodic_wave() {
	frequency := RenderAudioParam.create(AudioParamTimeline.create(1), -10, 10, .a_rate)
	detune := RenderAudioParam.create(AudioParamTimeline.create(0), -1200, 1200, .a_rate)
	mut oscillator := OscillatorRenderNode.create(1, 1, frequency, detune)
	wave := &PeriodicWaveData{
		real: [f32(0), 0]
		imag: [f32(0), 2]
	}
	oscillator.handle_message(NodeMessage{
		node_id: 1
		kind: .set_oscillator_waveform
		oscillator_type: .custom
		periodic_wave: wave
	})
	assert math.abs(oscillator.sample_waveform(math.pi / 2.0, 1, 2) - 1) < 0.00001
	oscillator.handle_message(NodeMessage{
		node_id: 1
		kind: .start_source
		when: 0.25
	})
	assert oscillator.scheduled_source().has_started()
	assert oscillator.scheduled_source().start_time() == 0.25
}
