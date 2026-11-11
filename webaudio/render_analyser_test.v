module webaudio

import math

fn test_analyser_uses_speaker_downmix_without_changing_its_output() {
	for channels in [[f32(2), 4], [f32(2), 4, 6, 8], [f32(2), 4, 6, 100, 8, 10]] {
		mut graph := RenderGraph.create()
		mut source := RenderNode.create(1, 0, 1, 2, channels.len)
		source.set_process_callback(fn [channels] (mut node RenderNode, _ mut RenderGraph, _ RenderContext) {
			mut output := unsafe { &AudioBus(node.output(0)) }
			for index, value in channels { output.set_channel(index, [value, value]) }
		})
		mut ring := new_media_stream_audio_ring(16, 1)
		analyser := AnalyserRenderNode.create(2, 2, ring)
		graph.apply_control_messages([
			ControlMessage{kind: .add_node, render_node: source},
			ControlMessage{kind: .add_node, render_node: analyser.render_node()},
			ControlMessage{kind: .replace_connections, node_id: 1, node_connections: [OutgoingNodeConnection{destination: 2}]},
		])
		graph.set_destination(2)
		graph.render_quantum(RenderContext{sample_rate: 48_000, quantum_size: 2})
		samples := ring.pop_frames(2)
		expected := match channels.len {
			2 { f32(3) }
			4 { f32(5) }
			else { f32(6 * math.sqrt(0.5) + 15) }
		}
		assert samples.len == 2
		assert math.abs(samples[0] - expected) < 0.00001
		assert samples[1] == samples[0]
		assert analyser.render_node().output(0).channel_count() == channels.len
		assert analyser.render_node().output(0).channel(channels.len - 1)[0] == channels.last()
	}
}
