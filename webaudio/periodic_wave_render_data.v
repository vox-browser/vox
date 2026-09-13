// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Rendering-side immutable PeriodicWave snapshot and constructor helpers.
module webaudio

@[heap]
pub struct PeriodicWaveData {
pub:
	real      []f32
	imag      []f32
	normalize bool = true
}

pub fn copy_float_vector(source []f32) []f32 {
	return source.clone()
}

pub fn zeroed_float_vector(size int) []f32 {
	return []f32{len: size}
}

pub fn PeriodicWave.create_for_constructor(_ &BaseAudioContext,
	options PeriodicWaveOptions) !PeriodicWave {
	return new_periodic_wave(options)
}

pub fn (wave PeriodicWave) render_data() &PeriodicWaveData {
	return &PeriodicWaveData{
		real: copy_float_vector(wave.real)
		imag: copy_float_vector(wave.imag)
		normalize: wave.normalize
	}
}

pub fn (wave PeriodicWave) external_memory_size() int {
	return (wave.real.len + wave.imag.len) * int(sizeof(f32))
}
