module webaudio

import math

fn test_factories_apply_node_specific_defaults_and_constraints() {
	mut context := new_audio_context(1, 48000, true) or { panic(err) }
	merger := context.base.create_channel_merger(6, AudioNodeOptions{}) or { panic(err) }
	assert merger.node.channel_count == 1
	assert merger.node.channel_count_mode == .explicit
	splitter := context.base.create_channel_splitter(4, AudioNodeOptions{}) or { panic(err) }
	assert splitter.node.channel_count == 4
	assert splitter.node.channel_interpretation == .discrete
	delay := context.base.create_delay(2, 0.5, AudioNodeOptions{}) or { panic(err) }
	assert delay.delay_time.value() == 0.5
	biquad := context.base.create_biquad_filter(BiquadFilterOptions{}) or { panic(err) }
	assert biquad.gain.max_value > 1541
	context.base.create_delay(180, 0, AudioNodeOptions{}) or {
		assert err.msg().contains('exclusive')
		return
	}
	assert false
}

fn test_delay_rejects_nan_max_delay_time() {
	mut context := new_audio_context(7, none, true) or { panic(err) }
	context.base.create_delay(math.nan(), 0, AudioNodeOptions{}) or {
		assert err.msg().contains('NotSupportedError')
		return
	}
	assert false
}

fn test_processor_and_compressor_restricted_mutators() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	automatic := context.base.create_script_processor(0, 2, 2) or { panic(err) }
	assert automatic.buffer_size == 1024
	output_only := context.base.create_script_processor(256, 0, 2) or { panic(err) }
	assert output_only.node.channel_count == 0
	mut processor := context.base.create_script_processor(1024, 2, 2) or { panic(err) }
	processor.set_buffer_size(300) or { assert err.msg().contains('Unsupported') }
	assert processor.buffer_size == 1024
	mut compressor := context.base.create_dynamics_compressor(DynamicsCompressorOptions{}) or {
		panic(err)
	}
	compressor.set_channel_count_mode(.max) or {
		assert err.msg().contains('does not support')
		return
	}
	assert false
}

fn test_compressor_constructor_applies_derived_channel_constraints() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	context.base.create_dynamics_compressor(DynamicsCompressorOptions{
		node: AudioNodeOptions{
			channel_count_mode: .max
		}
	}) or {
		assert err.msg().contains("does not support 'max'")
		return
	}
	assert false
}

fn test_merger_constructor_applies_fixed_channel_constraints() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	context.base.create_channel_merger(2, AudioNodeOptions{ channel_count: 2 }) or {
		assert err.msg().contains('Channel count cannot be changed')
		return
	}
	assert false
}

fn test_splitter_constructor_applies_fixed_interpretation_constraints() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	context.base.create_channel_splitter(2, AudioNodeOptions{
		channel_interpretation: .speakers
	}) or {
		assert err.msg().contains("must be 'discrete'")
		return
	}
	assert false
}

fn test_stereo_and_spatial_panners_apply_derived_channel_constraints() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	context.base.create_stereo_panner(0, AudioNodeOptions{ channel_count: 3 }) or {
		assert err.msg().contains('greater than 2')
		return
	}
	assert false
}

fn test_spatial_panner_constructor_rejects_max_channel_mode() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	context.base.create_panner(PannerOptions{
		node: AudioNodeOptions{
			channel_count_mode: .max
		}
	}) or {
		assert err.msg().contains("does not support 'max'")
		return
	}
	assert false
}

fn test_spatial_panner_rejects_non_positive_max_distance() {
	mut context := new_audio_context(1, 44_100, true) or { panic(err) }
	context.base.create_panner(PannerOptions{ max_distance: 0 }) or {
		assert err.msg().contains('must be positive')
		return
	}
	assert false
}

fn test_periodic_wave_distinguishes_absent_and_present_empty_arrays() {
	new_periodic_wave(PeriodicWaveOptions{ real: []f32{} }) or {
		assert err.msg().contains('at least 2')
		return
	}
	assert false
}

fn test_buffer_source_constructor_buffer_does_not_consume_first_set() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	first := new_audio_buffer(1, 1, 44100) or { panic(err) }
	second := new_audio_buffer(1, 2, 44100) or { panic(err) }
	mut source := context.base.create_buffer_source(AudioBufferSourceOptions{ buffer: first }) or {
		panic(err)
	}
	source.set_buffer(second) or { panic(err) }
	assert (source.buffer or { panic('missing buffer') }).length == 2
}

fn test_oscillator_periodic_wave_and_buffer_source_identity() {
	mut context := new_audio_context(1, 44100, true) or { panic(err) }
	context.base.create_oscillator(OscillatorOptions{ type_: .custom }) or {
		assert err.msg().contains('requires PeriodicWave')
	}
	wave := new_periodic_wave(PeriodicWaveOptions{}) or { panic(err) }
	mut oscillator := context.base.create_oscillator(OscillatorOptions{}) or { panic(err) }
	oscillator.set_periodic_wave(wave)
	assert oscillator.type_ == .custom
	mut source := context.base.create_buffer_source(AudioBufferSourceOptions{}) or { panic(err) }
	buffer := new_audio_buffer(1, 1, 44100) or { panic(err) }
	source.set_buffer(buffer) or { panic(err) }
	source.set_buffer(buffer) or {
		assert err.msg().contains('already been set')
		return
	}
	assert false
}
