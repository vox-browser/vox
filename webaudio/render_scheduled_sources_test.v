module webaudio

fn test_constant_source_renders_only_inside_scheduled_interval_and_ends() {
	mut graph := RenderGraph.create()
	offset := RenderAudioParam.create(AudioParamTimeline.create(2), -10, 10, .a_rate)
	constant := ConstantSourceRenderNode.create(1, 4, offset)
	graph.apply_control_messages([
		ControlMessage{ kind: .add_node, render_node: constant.render_node() },
		ControlMessage{
			kind: .node_message
			node_message: NodeMessage{
				node_id: 1
				kind: .start_source
				when: 0.5
			}
		},
		ControlMessage{
			kind: .node_message
			node_message: NodeMessage{
				node_id: 1
				kind: .stop_source
				when: 0.75
			}
		},
	])
	graph.render_quantum(RenderContext{
		sample_rate: 4
		quantum_size: 4
	})
	assert constant.render_node().output(0).channel(0) == [f32(0), 0, 2, 0]
	assert constant.scheduled_source().has_started()
	assert constant.scheduled_source().start_time() == 0.5
	assert constant.scheduled_source().stop_time() == 0.75
	assert graph.take_ended_nodes() == [u64(1)]
	assert graph.take_ended_nodes().len == 0
}

fn test_scheduled_source_clamps_past_start_to_current_quantum() {
	mut graph := RenderGraph.create()
	offset := RenderAudioParam.create(AudioParamTimeline.create(3), -10, 10, .k_rate)
	constant := ConstantSourceRenderNode.create(2, 4, offset)
	graph.apply_control_messages([
		ControlMessage{ kind: .add_node, render_node: constant.render_node() },
		ControlMessage{
			kind: .node_message
			node_message: NodeMessage{
				node_id: 2
				kind: .start_source
				when: 0
			}
		},
	])
	graph.render_quantum(RenderContext{
		sample_rate: 4
		quantum_size: 4
		quantum_start_frame: 8
	})
	assert constant.scheduled_source().start_time() == 2
	assert constant.render_node().output(0).channel(0) == [f32(3), 3, 3, 3]
}

fn test_scheduled_source_content_exhaustion_marks_node_ended() {
	mut graph := RenderGraph.create()
	mut scheduled := ScheduledSourceRenderNode.create(3, 1, 4)
	scheduled.handle_message(NodeMessage{
		node_id: 3
		kind: .start_source
	})
	scheduled.process(mut graph, RenderContext{
		sample_rate: 4
		quantum_size: 4
	})
	assert scheduled.is_active_at(0)
	scheduled.set_content_ended()
	assert scheduled.content_ended()
	scheduled.update_ended_state(RenderContext{
		sample_rate: 4
		quantum_size: 4
	})
	assert scheduled.take_ended_notification()
	assert !scheduled.take_ended_notification()
}
