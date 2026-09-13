// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of OscillatorRenderNode.
module webaudio

import math

const max_oscillator_harmonics = 5000

@[heap]
pub struct OscillatorRenderNode {
mut:
	scheduled_           &ScheduledSourceRenderNode
	frequency_           &RenderAudioParam
	detune_              &RenderAudioParam
	frequency_values_    []f32
	detune_values_       []f32
	type_                OscillatorType = .sine
	periodic_wave_       ?&PeriodicWaveData
	periodic_wave_scale_ f32 = 1
	phase_               f64
}

pub fn OscillatorRenderNode.create(node_id u64, quantum_size int, frequency &RenderAudioParam,
	detune &RenderAudioParam) &OscillatorRenderNode {
	mut scheduled := ScheduledSourceRenderNode.create(node_id, 1, quantum_size)
	mut render_node := unsafe { &RenderNode(scheduled.render_node()) }
	render_node.add_param(frequency)
	render_node.add_param(detune)
	mut oscillator := &OscillatorRenderNode{
		scheduled_: scheduled
		frequency_: frequency
		detune_: detune
		frequency_values_: []f32{len: quantum_size}
		detune_values_: []f32{len: quantum_size}
	}
	oscillator_pointer := oscillator
	scheduled.set_process_source_callback(fn [oscillator_pointer] (mut graph RenderGraph, context RenderContext) {
		mut mutable_oscillator := unsafe { &OscillatorRenderNode(oscillator_pointer) }
		mutable_oscillator.process_source(mut graph, context)
	})
	render_node.set_message_callback(fn [oscillator_pointer] (_ mut RenderNode, message NodeMessage) {
		mut mutable_oscillator := unsafe { &OscillatorRenderNode(oscillator_pointer) }
		mutable_oscillator.handle_message(message)
	})
	return oscillator
}

pub fn (oscillator &OscillatorRenderNode) render_node() &RenderNode {
	return oscillator.scheduled_.render_node()
}

pub fn (oscillator &OscillatorRenderNode) scheduled_source() &ScheduledSourceRenderNode {
	return oscillator.scheduled_
}

pub fn (mut oscillator OscillatorRenderNode) for_each_param(
	callback RenderAudioParamCallback) {
	mut frequency := unsafe { &RenderAudioParam(oscillator.frequency_) }
	callback(mut frequency)
	mut detune := unsafe { &RenderAudioParam(oscillator.detune_) }
	callback(mut detune)
}

pub fn (mut oscillator OscillatorRenderNode) handle_message(message NodeMessage) {
	if message.kind != .set_oscillator_waveform {
		oscillator.scheduled_.handle_message(message)
		return
	}
	oscillator.type_ = message.oscillator_type
	oscillator.periodic_wave_ = message.periodic_wave
	oscillator.periodic_wave_scale_ = 1
	wave := oscillator.periodic_wave_ or { return }
	if !wave.normalize {
		return
	}
	mut maximum_amplitude := f32(0)
	for sample_index in 0 .. 4096 {
		phase := 2.0 * math.pi * f64(sample_index) / 4096.0
		mut amplitude := f32(0)
		for harmonic in 1 .. wave.real.len {
			amplitude += wave.real[harmonic] * f32(math.cos(f64(harmonic) * phase)) + wave.imag[harmonic] * f32(math.sin(f64(harmonic) * phase))
		}
		absolute_amplitude := f32(math.abs(f64(amplitude)))
		if absolute_amplitude > maximum_amplitude {
			maximum_amplitude = absolute_amplitude
		}
	}
	if maximum_amplitude > 0 {
		oscillator.periodic_wave_scale_ = 1.0 / maximum_amplitude
	}
}

// https://webaudio.github.io/web-audio-api/#oscillator-coefficients
pub fn (oscillator &OscillatorRenderNode) sample_waveform(phase f64, frequency f64,
	nyquist_frequency f64) f32 {
	match oscillator.type_ {
		.sine {
			return f32(math.sin(phase))
		}
		.square {
			mut harmonic_count := if frequency != 0 {
				int(nyquist_frequency / math.abs(frequency))
			} else {
				max_oscillator_harmonics
			}
			harmonic_count = min_int(harmonic_count, max_oscillator_harmonics)
			mut value := f64(0)
			for harmonic := 1; harmonic <= harmonic_count; harmonic += 2 {
				value += 4.0 / (f64(harmonic) * math.pi) * math.sin(f64(harmonic) * phase)
			}
			return f32(value)
		}
		.sawtooth {
			mut harmonic_count := if frequency != 0 {
				int(nyquist_frequency / math.abs(frequency))
			} else {
				max_oscillator_harmonics
			}
			harmonic_count = min_int(harmonic_count, max_oscillator_harmonics)
			mut value := f64(0)
			for harmonic in 1 .. harmonic_count + 1 {
				mut coefficient := 2.0 / (f64(harmonic) * math.pi)
				if harmonic % 2 == 0 {
					coefficient = -coefficient
				}
				value += coefficient * math.sin(f64(harmonic) * phase)
			}
			return f32(value)
		}
		.triangle {
			mut harmonic_count := if frequency != 0 {
				int(nyquist_frequency / math.abs(frequency))
			} else {
				max_oscillator_harmonics
			}
			harmonic_count = min_int(harmonic_count, max_oscillator_harmonics)
			mut value := f64(0)
			mut sign := f64(1)
			for harmonic := 1; harmonic <= harmonic_count; harmonic += 2 {
				coefficient := sign * 8.0 / (f64(harmonic * harmonic) * math.pi * math.pi)
				value += coefficient * math.sin(f64(harmonic) * phase)
				sign = -sign
			}
			return f32(value)
		}
		.custom {
			wave := oscillator.periodic_wave_ or { return 0 }
			mut value := f64(0)
			for harmonic in 1 .. wave.real.len {
				value += f64(wave.real[harmonic]) * math.cos(f64(harmonic) * phase) + f64(wave.imag[harmonic]) * math.sin(f64(harmonic) * phase)
			}
			return f32(value) * oscillator.periodic_wave_scale_
		}
	}
}

pub fn (mut oscillator OscillatorRenderNode) process_source(mut graph RenderGraph,
	context RenderContext) {
	mut frequency := unsafe { &RenderAudioParam(oscillator.frequency_) }
	frequency.compute(mut graph, context, mut oscillator.frequency_values_)
	mut detune := unsafe { &RenderAudioParam(oscillator.detune_) }
	detune.compute(mut graph, context, mut oscillator.detune_values_)
	nyquist_frequency := context.sample_rate / 2.0
	mut output := unsafe { &AudioBus(oscillator.render_node().output(0)) }
	mut samples := []f32{len: context.quantum_size}
	for frame in 0 .. context.quantum_size {
		if !oscillator.scheduled_.is_active_at(context.frame_time(frame)) {
			continue
		}
		mut computed_frequency := f64(oscillator.frequency_values_[frame]) * math.exp2(f64(oscillator.detune_values_[frame]) / 1200.0)
		if computed_frequency < -nyquist_frequency {
			computed_frequency = -nyquist_frequency
		}
		if computed_frequency > nyquist_frequency {
			computed_frequency = nyquist_frequency
		}
		samples[frame] = oscillator.sample_waveform(oscillator.phase_, computed_frequency, nyquist_frequency)
		oscillator.phase_ += 2.0 * math.pi * computed_frequency / context.sample_rate
		oscillator.phase_ = math.fmod(oscillator.phase_, 2.0 * math.pi)
		if oscillator.phase_ < 0 {
			oscillator.phase_ += 2.0 * math.pi
		}
	}
	output.set_channel(0, samples)
	oscillator.scheduled_.update_ended_state(context)
}
