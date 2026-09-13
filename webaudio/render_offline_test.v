module webaudio

struct OfflineRendererObservation {
mut:
	completion_count int
	suspend_times    []f64
	ended_nodes      []u64
}

fn test_offline_renderer_captures_every_destination_quantum() {
	mut context := new_offline_audio_context(1, 2, 130, 48_000) or { panic(err) }
	mut source := context.base.create_constant_source(0.25, AudioNodeOptions{}) or { panic(err) }
	mut destination := context.base.destination.AudioNode
	connect_nodes(mut source.node, mut destination, 0, 0) or { panic(err) }
	start_scheduled_source(mut context.base, mut source.node, 0) or { panic(err) }
	mut renderer := OfflineAudioRenderer.create(context.base.control_messages, destination.id, 2, 130, 48_000, int(render_quantum_size))
	mut observation := &OfflineRendererObservation{}
	renderer.set_on_complete(fn [mut observation] () {
		observation.completion_count++
	})
	renderer.start_rendering()
	assert renderer.is_rendering_started()
	assert renderer.is_complete()
	assert renderer.frames_rendered() == 256
	assert observation.completion_count == 1
	channels := renderer.rendered_channels()
	assert channels.len == 2
	assert channels[0] == []f32{len: 130, init: 0.25}
	assert channels[1] == []f32{len: 130, init: 0.25}
}

fn test_offline_renderer_suspends_and_resumes_at_quantum_boundaries() {
	mut context := new_offline_audio_context(1, 1, 256, 48_000) or { panic(err) }
	mut source := context.base.create_constant_source(0.5, AudioNodeOptions{}) or { panic(err) }
	mut destination := context.base.destination.AudioNode
	connect_nodes(mut source.node, mut destination, 0, 0) or { panic(err) }
	start_scheduled_source(mut context.base, mut source.node, 0) or { panic(err) }
	mut renderer := OfflineAudioRenderer.create(context.base.control_messages, destination.id, 1, 256, 48_000, int(render_quantum_size))
	mut observation := &OfflineRendererObservation{}
	renderer.set_on_suspended(fn [mut observation] (time f64) {
		observation.suspend_times << time
	})
	renderer.set_on_complete(fn [mut observation] () {
		observation.completion_count++
	})
	assert renderer.request_suspend(128)
	renderer.start_rendering()
	assert renderer.is_suspended()
	assert !renderer.is_complete()
	assert renderer.frames_rendered() == 128
	assert observation.suspend_times == [f64(128) / 48_000.0]
	assert !renderer.request_suspend(0)
	renderer.resume()
	assert renderer.is_complete()
	assert renderer.frames_rendered() == 256
	assert observation.completion_count == 1
	assert renderer.rendered_channels()[0] == []f32{len: 256, init: 0.5}
}

fn test_offline_renderer_stop_abandons_a_suspended_render() {
	mut context := new_offline_audio_context(1, 1, 256, 48_000) or { panic(err) }
	mut renderer := OfflineAudioRenderer.create(context.base.control_messages, context.base.destination.id, 1, 256, 48_000, int(render_quantum_size))
	assert renderer.request_suspend(0)
	renderer.start_rendering()
	assert renderer.is_suspended()
	renderer.stop()
	renderer.resume()
	assert !renderer.is_complete()
	assert renderer.frames_rendered() == 0
}

fn test_offline_renderer_reports_ended_sources() {
	mut context := new_offline_audio_context(1, 1, 256, 48_000) or { panic(err) }
	mut source := context.base.create_constant_source(1, AudioNodeOptions{}) or { panic(err) }
	mut destination := context.base.destination.AudioNode
	connect_nodes(mut source.node, mut destination, 0, 0) or { panic(err) }
	start_scheduled_source(mut context.base, mut source.node, 0) or { panic(err) }
	stop_scheduled_source(mut context.base, source.node, 0.001) or { panic(err) }
	mut renderer := OfflineAudioRenderer.create(context.base.control_messages, destination.id, 1, 256, 48_000, int(render_quantum_size))
	mut observation := &OfflineRendererObservation{}
	renderer.set_on_sources_ended(fn [mut observation] (node_ids []u64) {
		observation.ended_nodes << node_ids
	})
	renderer.start_rendering()
	assert observation.ended_nodes == [source.node.id]
	channel := renderer.rendered_channels()[0]
	assert channel[47] == 1
	assert channel[48] == 0
}
