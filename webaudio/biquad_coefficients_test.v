module webaudio

import math

fn assert_biquad_close(actual f64, expected f64) {
	assert math.abs(actual - expected) < 0.00001
}

fn test_compute_biquad_coefficients_matches_reference_lowpass() {
	coefficients := compute_biquad_coefficients(.lowpass, 0.5, 0, 0)
	assert_biquad_close(coefficients.b0, 1.0 / 3.0)
	assert_biquad_close(coefficients.b1, 2.0 / 3.0)
	assert_biquad_close(coefficients.b2, 1.0 / 3.0)
	assert_biquad_close(coefficients.a1, 0)
	assert_biquad_close(coefficients.a2, 1.0 / 3.0)
}

fn test_compute_biquad_coefficients_covers_every_filter_type() {
	for type_ in [BiquadFilterType.lowpass, .highpass, .bandpass, .lowshelf, .highshelf, .peaking,
		.notch, .allpass] {
		coefficients := compute_biquad_coefficients(type_, 0.35, 1, 6)
		for value in [coefficients.b0, coefficients.b1, coefficients.b2, coefficients.a1,
			coefficients.a2] {
			assert !math.is_nan(value)
			assert !math.is_inf(value, 0)
		}
	}
}

fn test_biquad_frequency_response_evaluates_magnitude_and_phase() {
	coefficients := compute_biquad_coefficients(.lowpass, 0.5, 0, 0)
	dc_magnitude, dc_phase := biquad_frequency_response(coefficients, 0)
	assert_biquad_close(dc_magnitude, 1)
	assert_biquad_close(dc_phase, 0)
	cutoff_magnitude, cutoff_phase := biquad_frequency_response(coefficients, 0.5)
	assert_biquad_close(cutoff_magnitude, 1)
	assert cutoff_phase < 0
}

fn test_biquad_node_get_frequency_response_writes_results_and_nan_for_bad_frequency() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	node := context.base.create_biquad_filter(BiquadFilterOptions{
		frequency: 12_000
		q: 0
	}) or { panic(err) }
	mut magnitudes := []f32{len: 4}
	mut phases := []f32{len: 4}
	node.get_frequency_response([f32(0), 12_000, -1, 30_000], mut magnitudes, mut phases) or {
		panic(err)
	}
	assert_biquad_close(magnitudes[0], 1)
	assert_biquad_close(magnitudes[1], 1)
	assert math.is_nan(magnitudes[2])
	assert math.is_nan(phases[2])
	assert math.is_nan(magnitudes[3])
	assert math.is_nan(phases[3])
}

fn test_biquad_node_get_frequency_response_rejects_different_lengths() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	node := context.base.create_biquad_filter(BiquadFilterOptions{}) or { panic(err) }
	mut magnitudes := []f32{len: 1}
	mut phases := []f32{len: 2}
	if _ := node.get_frequency_response([f32(100), 200], mut magnitudes, mut phases) {
		assert false
	} else {
		assert err.msg().contains('InvalidAccessError')
	}
}
