module webaudio

import html
import math

fn audio_worklet_factory_fixture(_ AudioWorkletProcessorOptions,
	scope &AudioWorkletGlobalScope) !&AudioWorkletProcessor {
	return AudioWorkletProcessor.construct_impl(scope)
}

fn audio_worklet_process_fixture(_ [][][]f32, mut outputs [][][]f32,
	_ map[string][]f32) !bool {
	if outputs.len > 0 && outputs[0].len > 0 && outputs[0][0].len > 0 {
		outputs[0][0][0] = 42
	}
	return true
}

fn test_audio_worklet_is_lazy_and_owns_entangled_ports() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	first := context.base.audio_worklet()
	second := context.base.audio_worklet()
	assert voidptr(first) == voidptr(second)
	assert first.context_id == context.base.id
	assert first.worklet_destination() == .audio_worklet
	scope := first.audio_worklet_global_scope() or { panic('missing scope') }
	assert first.port().is_entangled()
	assert (scope.port() or { panic('missing port') }).is_entangled()
	assert scope.sample_rate() == 48_000
	assert scope.render_quantum_size() == 128
}

fn test_audio_worklet_registers_and_synchronizes_definitions() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut worklet := context.base.audio_worklet()
	mut scope := worklet.audio_worklet_global_scope() or { panic('missing scope') }
	descriptors := [
		AudioParamDescriptor{
			name: 'gain'
			default_value: 0.5
			min_value: 0
			max_value: 1
		},
		AudioParamDescriptor{
			name: 'frequency'
			default_value: 440
			min_value: 20
			max_value: 20_000
			automation_rate: .k_rate
		},
	]
	scope.register_processor('synth', audio_worklet_factory_fixture, descriptors) or { panic(err) }
	definition := scope.find_definition('synth') or { panic('missing processor') }
	assert definition.parameter_descriptors.map(it.name) == ['gain', 'frequency']
	assert definition.parameter_descriptors[1].automation_rate == .k_rate
	synced := worklet.find_definition('synth') or { panic('missing synchronized definition') }
	assert synced.parameter_descriptors.map(it.default_value) == [f32(0.5), 440]
	assert scope.find_definition('missing') == none
}

fn test_audio_worklet_rejects_invalid_registrations() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut scope := context.base.audio_worklet().audio_worklet_global_scope() or {
		panic('missing scope')
	}
	scope.register_processor('', audio_worklet_factory_fixture, []) or {
		assert err.msg().contains('must not be empty')
	}
	scope.register_processor('duplicate-params', audio_worklet_factory_fixture, [
		AudioParamDescriptor{ name: 'gain' },
		AudioParamDescriptor{ name: 'gain' },
	]) or {
		assert err.msg().contains('Duplicate parameter')
	}
	scope.register_processor('bad-range', audio_worklet_factory_fixture, [
		AudioParamDescriptor{
			name: 'gain'
			default_value: 2
			min_value: 0
			max_value: 1
		},
	]) or {
		assert err.msg().contains('outside')
	}
	scope.register_processor('not-finite', audio_worklet_factory_fixture, [
		AudioParamDescriptor{
			name: 'gain'
			default_value: f32(math.inf(1))
		},
	]) or {
		assert err.msg().contains('must be finite')
	}
	scope.register_processor('valid', audio_worklet_factory_fixture, []) or { panic(err) }
	scope.register_processor('valid', audio_worklet_factory_fixture, []) or {
		assert err.msg().contains('already registered')
		return
	}
	assert false
}

fn test_audio_worklet_processor_consumes_pending_construction_data() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut scope := context.base.audio_worklet().audio_worklet_global_scope() or {
		panic('missing scope')
	}
	port := html.MessagePort.create()
	scope.set_pending_processor_construction_data(PendingProcessorConstructionData{ port: port })
	mut processor := AudioWorkletProcessor.construct_impl(scope) or { panic(err) }
	assert processor.port() == port
	assert processor.relevant_global_impl() == scope
	processor.set_process_callback(audio_worklet_process_fixture)
	mut outputs := [[[]f32{len: 1}]]
	assert processor.process([], mut outputs, map[string][]f32{}) or { panic(err) }
	assert outputs[0][0][0] == 42
	AudioWorkletProcessor.construct_impl(scope) or {
		assert err.msg().contains('outside AudioWorkletNode construction')
		return
	}
	assert false
}

fn test_audio_worklet_tracks_render_time_and_shuts_down_with_context() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut scope := context.base.audio_worklet().audio_worklet_global_scope() or {
		panic('missing scope')
	}
	scope.set_current_frame_and_time(256, 256.0 / 48_000.0)
	assert scope.current_frame() == 256
	assert scope.current_time() == 256.0 / 48_000.0
	assert context.close().state == .fulfilled
	assert scope.shut_down_
}
