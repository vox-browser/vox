module webaudio

import math

@[heap]
struct StereoPannerParamObservation {
mut:
	found bool
}

fn stereo_panner_test_source(left []f32, right ?[]f32) &RenderNode {
	mut source := RenderNode.create(1, 0, 1, left.len, 1)
	source.set_process_callback(fn [left, right] (mut node RenderNode, _ mut RenderGraph, _ RenderContext) {
		mut output := unsafe { &AudioBus(node.output(0)) }
		output.set_channel_count(if right != none { 2 } else { 1 })
		output.set_channel(0, left)
		if samples := right {
			output.set_channel(1, samples)
		}
	})
	return source
}

fn render_stereo_panner_fixture(left []f32, right ?[]f32, pan_value f32) &StereoPannerRenderNode {
	mut graph := RenderGraph.create()
	source := stereo_panner_test_source(left, right)
	pan := RenderAudioParam.create(AudioParamTimeline.create(pan_value), -1, 1, .a_rate)
	panner := StereoPannerRenderNode.create(2, left.len, pan)
	graph.apply_control_messages([
		ControlMessage{ kind: .add_node, render_node: source },
		ControlMessage{ kind: .add_node, render_node: panner.render_node() },
		ControlMessage{
			kind: .replace_connections
			node_id: 1
			node_connections: [OutgoingNodeConnection{
				destination: 2
			}]
		},
	])
	graph.set_destination(2)
	graph.render_quantum(RenderContext{
		sample_rate: 48_000
		quantum_size: left.len
	})
	return panner
}

fn test_equal_power_pan_gains_have_unit_power() {
	for position in [0.0, 0.25, 0.5, 0.75, 1.0] {
		gains := equal_power_pan_gains(position)
		assert math.abs(f64(gains.left * gains.left + gains.right * gains.right - 1)) < 0.00001
	}
}

fn test_stereo_panner_render_node_pans_mono_input() {
	panner := render_stereo_panner_fixture([f32(2), 2], none, 0)
	left := panner.render_node().output(0).channel(0)
	right := panner.render_node().output(0).channel(1)
	expected := f32(math.sqrt(2.0))
	for frame in 0 .. 2 {
		assert math.abs(f64(left[frame] - expected)) < 0.00001
		assert math.abs(f64(right[frame] - expected)) < 0.00001
	}
}

fn test_stereo_panner_render_node_pans_mono_input_fully_left() {
	panner := render_stereo_panner_fixture([f32(2), 4], none, -1)
	assert panner.render_node().output(0).channel(0) == [f32(2), 4]
	for sample in panner.render_node().output(0).channel(1) {
		assert math.abs(sample) < 0.00001
	}
}

fn test_stereo_panner_render_node_crossfeeds_stereo_input() {
	left_panner := render_stereo_panner_fixture([f32(1)], [f32(2)], -1)
	assert left_panner.render_node().output(0).channel(0) == [f32(3)]
	assert math.abs(left_panner.render_node().output(0).channel(1)[0]) < 0.00001
	right_panner := render_stereo_panner_fixture([f32(1)], [f32(2)], 1)
	assert math.abs(right_panner.render_node().output(0).channel(0)[0]) < 0.00001
	assert right_panner.render_node().output(0).channel(1) == [f32(3)]
}

fn test_stereo_panner_render_node_exposes_pan_parameter() {
	parameter := RenderAudioParam.create(AudioParamTimeline.create(0), -1, 1, .a_rate)
	mut panner := StereoPannerRenderNode.create(1, 4, parameter)
	mut observed := &StereoPannerParamObservation{}
	panner.for_each_param(fn [mut observed, parameter] (mut current RenderAudioParam) {
		observed.found = voidptr(&current) == voidptr(parameter)
	})
	assert observed.found
}
