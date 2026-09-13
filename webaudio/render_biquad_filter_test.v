module webaudio

import math

@[heap]
struct BiquadParamObservation {
mut:
	count int
}

fn biquad_render_test_source(samples []f32) &RenderNode {
	mut source := RenderNode.create(1, 0, 1, samples.len, 1)
	source.set_process_callback(fn [samples] (mut node RenderNode, _ mut RenderGraph, _ RenderContext) {
		mut output := unsafe { &AudioBus(node.output(0)) }
		output.set_channel(0, samples)
	})
	return source
}

fn create_biquad_render_test_node(quantum_size int) &BiquadFilterRenderNode {
	frequency := RenderAudioParam.create(AudioParamTimeline.create(12_000), 0, 24_000, .a_rate)
	detune := RenderAudioParam.create(AudioParamTimeline.create(0), -10_000, 10_000, .a_rate)
	q := RenderAudioParam.create(AudioParamTimeline.create(0), -1_000, 1_000, .a_rate)
	gain := RenderAudioParam.create(AudioParamTimeline.create(0), -1_000, 1_000, .a_rate)
	return BiquadFilterRenderNode.create(2, quantum_size, frequency, detune, q, gain)
}

fn render_biquad_test_quantum(filter &BiquadFilterRenderNode, samples []f32,
	filter_type BiquadFilterType) {
	mut graph := RenderGraph.create()
	source := biquad_render_test_source(samples)
	graph.apply_control_messages([
		ControlMessage{ kind: .add_node, render_node: source },
		ControlMessage{ kind: .add_node, render_node: filter.render_node() },
		ControlMessage{
			kind: .replace_connections
			node_id: 1
			node_connections: [OutgoingNodeConnection{
				destination: 2
			}]
		},
		ControlMessage{
			kind: .node_message
			node_message: NodeMessage{
				node_id: 2
				kind: .set_biquad_filter_type
				biquad_type: filter_type
			}
		},
	])
	graph.set_destination(2)
	graph.render_quantum(RenderContext{
		sample_rate: 48_000
		quantum_size: samples.len
	})
}

fn test_biquad_filter_render_node_filters_an_impulse() {
	filter := create_biquad_render_test_node(4)
	render_biquad_test_quantum(filter, [f32(1), 0, 0, 0], .lowpass)
	actual := filter.render_node().output(0).channel(0)
	expected := [f32(1.0 / 3.0), f32(2.0 / 3.0), f32(2.0 / 9.0), f32(-2.0 / 9.0)]
	for frame in 0 .. actual.len {
		assert math.abs(actual[frame] - expected[frame]) < 0.00001
	}
}

fn test_biquad_filter_render_node_handles_filter_type_messages() {
	filter := create_biquad_render_test_node(2)
	render_biquad_test_quantum(filter, [f32(1), 0], .highpass)
	assert filter.filter_type() == .highpass
	actual := filter.render_node().output(0).channel(0)
	assert math.abs(actual[0] - f32(1.0 / 3.0)) < 0.00001
	assert math.abs(actual[1] - f32(-2.0 / 3.0)) < 0.00001
}

fn test_biquad_filter_render_node_exposes_all_parameters() {
	mut filter := create_biquad_render_test_node(4)
	mut observation := &BiquadParamObservation{}
	filter.for_each_param(fn [mut observation] (_ mut RenderAudioParam) {
		observation.count++
	})
	assert observation.count == 4
}
