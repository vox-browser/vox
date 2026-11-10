module webaudio

import math

fn test_silent_gain_input_advances_and_retains_automated_value() {
	for rate in [AutomationRate.a_rate, .k_rate] {
		mut context := make_base_context(1, 48_000, 1, false) or { panic(err) }
		mut source := context.create_constant_source(0, AudioNodeOptions{}) or { panic(err) }
		mut gain := context.create_gain(1, AudioNodeOptions{}) or { panic(err) }
		mut destination := context.destination.AudioNode
		connect_nodes(mut source.node, mut gain.node, 0, 0) or { panic(err) }
		connect_nodes(mut gain.node, mut destination, 0, 0) or { panic(err) }
		start_scheduled_source(mut context, mut source.node, 0) or { panic(err) }
		quantum_time := f64(render_quantum_size) / 48_000.0
		time_constant := f32(quantum_time)
		gain.gain.set_automation_rate(rate) or { panic(err) }
		gain.gain.set_target_at_time(9, 0, time_constant) or { panic(err) }

		mut graph := RenderGraph.create()
		graph.apply_control_messages(context.control_messages.drain())
		graph.set_destination(destination.id)
		for quantum in 0 .. 2 {
			context.set_current_time(f64(quantum) * quantum_time)
			graph.render_quantum(RenderContext{
				sample_rate: 48_000
				quantum_size: int(render_quantum_size)
				quantum_start_frame: u64(quantum) * u64(render_quantum_size)
			})
		}
		expected := f32(9.0 - 8.0 * math.exp(-quantum_time / f64(time_constant)))
		assert math.abs(gain.gain.value() - expected) < 0.00001
		output := (graph.destination() or { panic('missing destination') }).output(0)
		assert output.channel(0) == []f32{len: int(render_quantum_size)}

		// Removing the active target must retain the value sampled during silence.
		// Making the source audible then verifies that rendering uses that value too.
		context.set_current_time(2 * quantum_time)
		gain.gain.cancel_scheduled_values(context.current_time()) or { panic(err) }
		source.offset.set_value(1) or { panic(err) }
		graph.render_quantum(RenderContext{
			sample_rate: 48_000
			quantum_size: int(render_quantum_size)
			quantum_start_frame: 2 * u64(render_quantum_size)
		})
		assert math.abs(gain.gain.value() - expected) < 0.00001
		for sample in output.channel(0) {
			assert math.abs(sample - expected) < 0.00001
		}
	}
}

fn test_silent_panner_input_advances_source_and_listener_automation() {
	for rate in [AutomationRate.a_rate, .k_rate] {
		mut context := make_base_context(1, 48_000, 2, false) or { panic(err) }
		mut source := context.create_constant_source(0, AudioNodeOptions{}) or { panic(err) }
		mut panner := context.create_panner(PannerOptions{position_z: -1}) or { panic(err) }
		mut destination := context.destination.AudioNode
		connect_nodes(mut source.node, mut panner.node, 0, 0) or { panic(err) }
		connect_nodes(mut panner.node, mut destination, 0, 0) or { panic(err) }
		start_scheduled_source(mut context, mut source.node, 0) or { panic(err) }
		quantum_time := f64(render_quantum_size) / 48_000.0
		time_constant := f32(quantum_time)
		panner.position_z.set_automation_rate(rate) or { panic(err) }
		context.listener.position_z.set_automation_rate(rate) or { panic(err) }
		panner.position_z.set_target_at_time(-5, 0, time_constant) or { panic(err) }
		context.listener.position_z.set_target_at_time(3, 0, time_constant) or { panic(err) }

		mut graph := RenderGraph.create()
		graph.apply_control_messages(context.control_messages.drain())
		graph.set_destination(destination.id)
		for quantum in 0 .. 2 {
			context.set_current_time(f64(quantum) * quantum_time)
			graph.render_quantum(RenderContext{
				sample_rate: 48_000
				quantum_size: int(render_quantum_size)
				quantum_start_frame: u64(quantum) * u64(render_quantum_size)
			})
		}
		decay := math.exp(-quantum_time / f64(time_constant))
		expected_position := f32(-5.0 + 4.0 * decay)
		expected_listener := f32(3.0 - 3.0 * decay)
		assert math.abs(panner.position_z.value() - expected_position) < 0.00001
		assert math.abs(context.listener.position_z.value() - expected_listener) < 0.00001
		output := (graph.destination() or { panic('missing destination') }).output(0)
		assert output.channel_count() == 2
		for channel in 0 .. 2 {
			assert output.channel(channel) == []f32{len: int(render_quantum_size)}
		}

		context.set_current_time(2 * quantum_time)
		panner.position_z.cancel_scheduled_values(context.current_time()) or { panic(err) }
		context.listener.position_z.cancel_scheduled_values(context.current_time()) or { panic(err) }
		source.offset.set_value(1) or { panic(err) }
		graph.render_quantum(RenderContext{
			sample_rate: 48_000
			quantum_size: int(render_quantum_size)
			quantum_start_frame: 2 * u64(render_quantum_size)
		})
		assert math.abs(panner.position_z.value() - expected_position) < 0.00001
		assert math.abs(context.listener.position_z.value() - expected_listener) < 0.00001
		expected_sample := f32(math.sqrt(0.5) / f64(expected_listener - expected_position))
		for channel in 0 .. 2 {
			for sample in output.channel(channel) {
				assert math.abs(sample - expected_sample) < 0.00001
			}
		}
	}
}
