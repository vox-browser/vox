module webaudio

import math

@[heap]
struct PannerParamObservation {
mut:
	count int
}

fn panner_render_parameter(value f32) &RenderAudioParam {
	return RenderAudioParam.create(AudioParamTimeline.create(value), -100_000, 100_000, .a_rate)
}

fn panner_render_test_node(position AudioVector3, orientation AudioVector3,
	quantum_size int) &PannerRenderNode {
	return PannerRenderNode.create(2, quantum_size, PannerRenderParams{
		position_x: panner_render_parameter(f32(position.x))
		position_y: panner_render_parameter(f32(position.y))
		position_z: panner_render_parameter(f32(position.z))
		orientation_x: panner_render_parameter(f32(orientation.x))
		orientation_y: panner_render_parameter(f32(orientation.y))
		orientation_z: panner_render_parameter(f32(orientation.z))
	}, PannerListenerRenderParams{
		position_x: panner_render_parameter(0)
		position_y: panner_render_parameter(0)
		position_z: panner_render_parameter(0)
		forward_x: panner_render_parameter(0)
		forward_y: panner_render_parameter(0)
		forward_z: panner_render_parameter(-1)
		up_x: panner_render_parameter(0)
		up_y: panner_render_parameter(1)
		up_z: panner_render_parameter(0)
	})
}

fn panner_render_test_source(samples []f32) &RenderNode {
	mut source := RenderNode.create(1, 0, 1, samples.len, 1)
	source.set_process_callback(fn [samples] (mut node RenderNode, _ mut RenderGraph, _ RenderContext) {
		mut output := unsafe { &AudioBus(node.output(0)) }
		output.set_channel(0, samples)
	})
	return source
}

fn render_panner_test_quantum(panner &PannerRenderNode, samples []f32,
	config PannerRenderConfig) {
	mut graph := RenderGraph.create()
	source := panner_render_test_source(samples)
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
		ControlMessage{
			kind: .node_message
			node_message: NodeMessage{
				node_id: 2
				kind: .set_panner_parameters
				panning_model: config.panning_model
				distance_model: config.distance_model
				ref_distance: config.ref_distance
				max_distance: config.max_distance
				rolloff_factor: config.rolloff_factor
				cone_inner_angle: config.cone_inner_angle
				cone_outer_angle: config.cone_outer_angle
				cone_outer_gain: config.cone_outer_gain
			}
		},
	])
	graph.set_destination(2)
	graph.render_quantum(RenderContext{
		sample_rate: 48_000
		quantum_size: samples.len
	})
}

fn test_panner_spatial_helpers_cover_azimuth_distance_and_cones() {
	listener_forward := AudioVector3{0, 0, -1}
	listener_up := AudioVector3{0, 1, 0}
	assert math.abs(compute_azimuth(AudioVector3{1, 0, 0}, AudioVector3{}, listener_forward, listener_up) - 90) < 0.00001
	assert math.abs(compute_azimuth(AudioVector3{-1, 0, 0}, AudioVector3{}, listener_forward, listener_up) + 90) < 0.00001
	assert math.abs(compute_distance_gain(2, PannerRenderConfig{}) - 0.5) < 0.00001
	assert math.abs(compute_distance_gain(6, PannerRenderConfig{
		distance_model: .linear
		ref_distance: 1
		max_distance: 11
		rolloff_factor: 0.5
	}) - 0.75) < 0.00001
	assert math.abs(compute_cone_gain(AudioVector3{}, AudioVector3{1, 0, 0}, AudioVector3{-1, 0, 0}, PannerRenderConfig{
		cone_inner_angle: 90
		cone_outer_angle: 180
		cone_outer_gain: 0.25
	}) - 0.25) < 0.00001
}

fn test_panner_render_node_places_a_source_on_the_right() {
	panner := panner_render_test_node(AudioVector3{1, 0, 0}, AudioVector3{1, 0, 0}, 2)
	render_panner_test_quantum(panner, [f32(2), 4], PannerRenderConfig{})
	for sample in panner.render_node().output(0).channel(0) {
		assert math.abs(sample) < 0.00001
	}
	assert panner.render_node().output(0).channel(1) == [f32(2), 4]
}

fn test_panner_render_node_applies_inverse_distance_gain() {
	panner := panner_render_test_node(AudioVector3{0, 0, -2}, AudioVector3{1, 0, 0}, 1)
	render_panner_test_quantum(panner, [f32(2)], PannerRenderConfig{})
	expected := f32(math.sqrt(0.5))
	assert math.abs(panner.render_node().output(0).channel(0)[0] - expected) < 0.00001
	assert math.abs(panner.render_node().output(0).channel(1)[0] - expected) < 0.00001
}

fn test_panner_render_node_exposes_its_source_and_listener_parameters() {
	mut panner := panner_render_test_node(AudioVector3{}, AudioVector3{1, 0, 0}, 1)
	mut observation := &PannerParamObservation{}
	panner.for_each_param(fn [mut observation] (_ mut RenderAudioParam) {
		observation.count++
	})
	assert observation.count == 15
}

fn test_panner_distance_models_apply_their_distinct_bounds() {
	for model in [DistanceModelType.inverse, .exponential] {
		assert compute_distance_gain(100, PannerRenderConfig{distance_model: model, max_distance: 2}) == 0.01
		assert compute_distance_gain(0, PannerRenderConfig{distance_model: model, ref_distance: 0}) == 0
		assert compute_distance_gain(10, PannerRenderConfig{distance_model: model, ref_distance: 0}) == 0
	}
	config := PannerRenderConfig{distance_model: .linear, ref_distance: 10, max_distance: 2}
	assert compute_distance_gain(0, config) == 1
	assert compute_distance_gain(6, config) == 0.5
	assert compute_distance_gain(12, config) == 0
	assert compute_distance_gain(5, PannerRenderConfig{distance_model: .linear, ref_distance: 5, max_distance: 5, rolloff_factor: 0.25}) == 0.75
	panner := panner_render_test_node(AudioVector3{100, 0, 0}, AudioVector3{1, 0, 0}, 1)
	render_panner_test_quantum(panner, [f32(1)], PannerRenderConfig{max_distance: 2})
	assert math.abs(panner.render_node().output(0).channel(1)[0] - 0.01) < 0.000001
}

fn test_graph_rebuild_does_not_duplicate_audio_listener_connections() {
	mut graph := RenderGraph.create()
	panner := panner_render_test_node(AudioVector3{0, 0, -2}, AudioVector3{1, 0, 0}, 1)
	source := panner_render_test_source([f32(1)])
	parameter := panner.listener_params_.position_z
	graph.apply_control_messages([
		ControlMessage{kind: .add_node, render_node: source},
		ControlMessage{kind: .add_node, render_node: panner.render_node()},
		ControlMessage{kind: .replace_connections, node_id: 1,
			node_connections: [OutgoingNodeConnection{destination: 2}],
			param_connections: [OutgoingParamConnection{destination: parameter}]},
	])
	graph.set_destination(2)
	context := RenderContext{sample_rate: 48_000, quantum_size: 1}
	graph.render_quantum(context)
	assert parameter.inputs().len == 1
	before := panner.render_node().output(0).channel(0)[0]
	graph.apply_control_messages([ControlMessage{kind: .add_node, render_node: RenderNode.create(3, 0, 1, 1, 1)}])
	graph.render_quantum(context)
	assert parameter.inputs().len == 1
	assert panner.render_node().output(0).channel(0)[0] == before
}
