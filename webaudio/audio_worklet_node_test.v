module webaudio

import html

@[heap]
struct AudioWorkletNodeErrorObservation {
mut:
	messages []string
}

fn drain_audio_worklet_node_tasks() {
	mut event_loop := html.main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
	}
}

fn audio_worklet_node_process(inputs [][][]f32, mut outputs [][][]f32,
	parameters map[string][]f32) !bool {
	if inputs.len == 0 || outputs.len == 0 {
		return false
	}
	gain := parameters['gain'] or { [f32(1)] }
	for channel in 0 .. min_int(inputs[0].len, outputs[0].len) {
		for frame in 0 .. min_int(inputs[0][channel].len, outputs[0][channel].len) {
			value := if gain.len == 1 { gain[0] } else { gain[frame] }
			outputs[0][channel][frame] = inputs[0][channel][frame] * value
		}
	}
	return false
}

fn audio_worklet_node_factory(options AudioWorkletProcessorOptions,
	scope &AudioWorkletGlobalScope) !&AudioWorkletProcessor {
	if options.number_of_inputs != 1 || options.number_of_outputs != 1 {
		return error('unexpected node shape')
	}
	if options.parameter_data['gain'] or { 0.0 } != 0.5 {
		return error('missing parameterData')
	}
	if options.processor_options['mode'] or { '' } != 'copy' {
		return error('missing processorOptions')
	}
	mut processor := AudioWorkletProcessor.construct_impl(scope)!
	processor.set_process_callback(audio_worklet_node_process)
	return processor
}

fn audio_worklet_missing_process_factory(_ AudioWorkletProcessorOptions,
	scope &AudioWorkletGlobalScope) !&AudioWorkletProcessor {
	return AudioWorkletProcessor.construct_impl(scope)
}

fn audio_worklet_throwing_factory(_ AudioWorkletProcessorOptions,
	_ &AudioWorkletGlobalScope) !&AudioWorkletProcessor {
	return error('processor constructor failed')
}

fn register_audio_worklet_node_fixture(mut context BaseAudioContext, name string,
	factory AudioWorkletProcessorFactory) &AudioWorkletGlobalScope {
	mut scope := context.audio_worklet().audio_worklet_global_scope() or {
		panic('missing scope')
	}
	scope.register_processor(name, factory, [
		AudioParamDescriptor{
			name: 'gain'
			default_value: 0.25
			min_value: 0
			max_value: 1
		},
	]) or { panic(err) }
	return scope
}

fn test_audio_worklet_node_validates_name_and_channel_configuration() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	AudioWorkletNode.create(mut context.base, 'missing', AudioWorkletNodeOptions{}) or {
		assert err.msg().contains('No AudioWorkletProcessor')
	}
	register_audio_worklet_node_fixture(mut context.base, 'valid', audio_worklet_node_factory)
	AudioWorkletNode.create(mut context.base, 'valid', AudioWorkletNodeOptions{
		number_of_inputs: 0
		number_of_outputs: 0
	}) or {
		assert err.msg().contains('at least one input or output')
	}
	AudioWorkletNode.create(mut context.base, 'valid', AudioWorkletNodeOptions{
		output_channel_count: [u32(1), 2]
	}) or {
		assert err.msg().contains('length must equal')
	}
	AudioWorkletNode.create(mut context.base, 'valid', AudioWorkletNodeOptions{
		output_channel_count: [u32(0)]
	}) or {
		assert err.msg().contains('between 1 and 32')
		return
	}
	assert false
}

fn test_audio_worklet_node_constructs_parameters_processor_and_pipe() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	scope := register_audio_worklet_node_fixture(mut context.base, 'copy', audio_worklet_node_factory)
	mut node := AudioWorkletNode.create(mut context.base, 'copy', AudioWorkletNodeOptions{
		parameter_data: {
			'gain': 0.5
		}
		processor_options: {
			'mode': 'copy'
		}
	}) or { panic(err) }
	assert node.processor() == none
	assert node.number_of_inputs() == 1
	assert node.number_of_outputs() == 1
	assert node.port().is_entangled()
	assert node.parameters().keys() == ['gain']
	gain := node.parameters().get('gain') or { panic('missing gain') }
	assert gain.value() == 0.5
	assert node.pipe().config().output_channel_count_matches_input
	assert node.pipe().config().ring_capacity == 64
	assert node.pipe().output_occupancy() == 48
	drain_audio_worklet_node_tasks()
	assert node.processor() != none
	assert scope.has_processor_slot(node.node.id)
	node.finalize()
	assert node.pipe().state() == .shut_down
	assert !scope.has_processor_slot(node.node.id)
}

fn test_audio_worklet_node_pumps_inputs_parameters_and_outputs() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut scope := register_audio_worklet_node_fixture(mut context.base, 'render', audio_worklet_node_factory)
	mut node := AudioWorkletNode.create(mut context.base, 'render', AudioWorkletNodeOptions{
		parameter_data: {
			'gain': 0.5
		}
		processor_options: {
			'mode': 'copy'
		}
	}) or { panic(err) }
	drain_audio_worklet_node_tasks()
	mut pipe := unsafe { &AudioWorkletPipe(node.pipe()) }
	pipe.discard_outputs_down_to(0)
	mut left := []f32{len: int(render_quantum_size)}
	mut right := []f32{len: int(render_quantum_size)}
	for frame in 0 .. int(render_quantum_size) {
		left[frame] = f32(frame)
		right[frame] = f32(frame + 100)
	}
	startup := node.render([[left, right]], 256)
	assert startup.len == 1
	assert startup[0].len == 1
	assert startup[0][0] == []f32{len: int(render_quantum_size)}
	drain_audio_worklet_node_tasks()
	assert scope.current_frame() == 256
	assert scope.current_time() == 256.0 / 48_000.0
	rendered := node.render([[][]f32{}], 384)
	assert rendered.len == 1
	assert rendered[0].len == 2
	assert rendered[0][0][8] == 4
	assert rendered[0][1][8] == 54
	assert !node.processor_errored()
	drain_audio_worklet_node_tasks()
	node.finalize()
}

fn test_audio_worklet_node_reports_constructor_and_process_errors() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut scope := context.base.audio_worklet().audio_worklet_global_scope() or {
		panic('missing scope')
	}
	scope.register_processor('broken-constructor', audio_worklet_throwing_factory, []) or {
		panic(err)
	}
	mut constructor_node := AudioWorkletNode.create(mut context.base, 'broken-constructor', AudioWorkletNodeOptions{}) or { panic(err) }
	mut observed := &AudioWorkletNodeErrorObservation{}
	constructor_node.set_onprocessorerror(fn [mut observed] (message string) {
		observed.messages << message
	})
	drain_audio_worklet_node_tasks()
	assert constructor_node.processor_errored()
	assert constructor_node.pipe().state() == .failed
	assert observed.messages == ['processor constructor failed']

	scope.register_processor('missing-process', audio_worklet_missing_process_factory, []) or {
		panic(err)
	}
	mut process_node := AudioWorkletNode.create(mut context.base, 'missing-process', AudioWorkletNodeOptions{}) or { panic(err) }
	drain_audio_worklet_node_tasks()
	mut process_pipe := unsafe { &AudioWorkletPipe(process_node.pipe()) }
	process_pipe.discard_outputs_down_to(0)
	process_node.render([[][]f32{}], 0)
	drain_audio_worklet_node_tasks()
	assert process_node.processor_errored()
	assert process_node.pipe().state() == .failed
	assert process_node.processor_error_messages()[0].contains('process must be a function')
	constructor_node.finalize()
	process_node.finalize()
}
