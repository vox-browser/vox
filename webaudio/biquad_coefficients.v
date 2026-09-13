// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Rendering/BiquadCoefficients.
module webaudio

import math

// Normalized biquad transfer-function coefficients, with a0 divided out.
pub struct BiquadCoefficients {
pub:
	b0 f64
	b1 f64
	b2 f64
	a1 f64
	a2 f64
}

// frequency is a fraction of the Nyquist frequency in [0, 1].
pub fn compute_biquad_coefficients(type_ BiquadFilterType, normalized_frequency f64,
	q f64, gain_db f64) BiquadCoefficients {
	omega := math.pi * normalized_frequency
	sin_omega := math.sin(omega)
	cos_omega := math.cos(omega)
	a := math.pow(10.0, gain_db / 40.0)
	mut b0 := 1.0
	mut b1 := 0.0
	mut b2 := 0.0
	mut a0 := 1.0
	mut a1 := 0.0
	mut a2 := 0.0
	match type_ {
		.lowpass {
			alpha_q_db := sin_omega / (2.0 * math.pow(10.0, q / 20.0))
			b0 = (1.0 - cos_omega) / 2.0
			b1 = 1.0 - cos_omega
			b2 = b0
			a0 = 1.0 + alpha_q_db
			a1 = -2.0 * cos_omega
			a2 = 1.0 - alpha_q_db
		}
		.highpass {
			alpha_q_db := sin_omega / (2.0 * math.pow(10.0, q / 20.0))
			b0 = (1.0 + cos_omega) / 2.0
			b1 = -(1.0 + cos_omega)
			b2 = b0
			a0 = 1.0 + alpha_q_db
			a1 = -2.0 * cos_omega
			a2 = 1.0 - alpha_q_db
		}
		.bandpass {
			alpha_q := if q > 0 { sin_omega / (2.0 * q) } else { 1.0 }
			b0 = alpha_q
			b2 = -alpha_q
			a0 = 1.0 + alpha_q
			a1 = -2.0 * cos_omega
			a2 = 1.0 - alpha_q
		}
		.notch {
			alpha_q := if q > 0 { sin_omega / (2.0 * q) } else { 1.0 }
			b0 = 1.0
			b1 = -2.0 * cos_omega
			b2 = 1.0
			a0 = 1.0 + alpha_q
			a1 = b1
			a2 = 1.0 - alpha_q
		}
		.allpass {
			alpha_q := if q > 0 { sin_omega / (2.0 * q) } else { 1.0 }
			b0 = 1.0 - alpha_q
			b1 = -2.0 * cos_omega
			b2 = 1.0 + alpha_q
			a0 = 1.0 + alpha_q
			a1 = b1
			a2 = 1.0 - alpha_q
		}
		.peaking {
			alpha_q := if q > 0 { sin_omega / (2.0 * q) } else { 1.0 }
			b0 = 1.0 + alpha_q * a
			b1 = -2.0 * cos_omega
			b2 = 1.0 - alpha_q * a
			a0 = 1.0 + alpha_q / a
			a1 = b1
			a2 = 1.0 - alpha_q / a
		}
		.lowshelf {
			alpha_s := sin_omega / 2.0 * math.sqrt(2.0)
			two_sqrt_a_alpha_s := 2.0 * math.sqrt(a) * alpha_s
			b0 = a * ((a + 1.0) - (a - 1.0) * cos_omega + two_sqrt_a_alpha_s)
			b1 = 2.0 * a * ((a - 1.0) - (a + 1.0) * cos_omega)
			b2 = a * ((a + 1.0) - (a - 1.0) * cos_omega - two_sqrt_a_alpha_s)
			a0 = (a + 1.0) + (a - 1.0) * cos_omega + two_sqrt_a_alpha_s
			a1 = -2.0 * ((a - 1.0) + (a + 1.0) * cos_omega)
			a2 = (a + 1.0) + (a - 1.0) * cos_omega - two_sqrt_a_alpha_s
		}
		.highshelf {
			alpha_s := sin_omega / 2.0 * math.sqrt(2.0)
			two_sqrt_a_alpha_s := 2.0 * math.sqrt(a) * alpha_s
			b0 = a * ((a + 1.0) + (a - 1.0) * cos_omega + two_sqrt_a_alpha_s)
			b1 = -2.0 * a * ((a - 1.0) + (a + 1.0) * cos_omega)
			b2 = a * ((a + 1.0) + (a - 1.0) * cos_omega - two_sqrt_a_alpha_s)
			a0 = (a + 1.0) - (a - 1.0) * cos_omega + two_sqrt_a_alpha_s
			a1 = 2.0 * ((a - 1.0) - (a + 1.0) * cos_omega)
			a2 = (a + 1.0) - (a - 1.0) * cos_omega - two_sqrt_a_alpha_s
		}
	}
	return BiquadCoefficients{
		b0: b0 / a0
		b1: b1 / a0
		b2: b2 / a0
		a1: a1 / a0
		a2: a2 / a0
	}
}

// Evaluates magnitude and phase at a fraction of the Nyquist frequency.
pub fn biquad_frequency_response(coefficients BiquadCoefficients,
	normalized_frequency f64) (f32, f32) {
	omega := math.pi * normalized_frequency
	cos_omega := math.cos(omega)
	sin_omega := math.sin(omega)
	cos_2_omega := math.cos(2.0 * omega)
	sin_2_omega := math.sin(2.0 * omega)
	numerator_real := coefficients.b0 + coefficients.b1 * cos_omega + coefficients.b2 * cos_2_omega
	numerator_imaginary := -(coefficients.b1 * sin_omega + coefficients.b2 * sin_2_omega)
	denominator_real := 1.0 + coefficients.a1 * cos_omega + coefficients.a2 * cos_2_omega
	denominator_imaginary := -(coefficients.a1 * sin_omega + coefficients.a2 * sin_2_omega)
	denominator_magnitude_squared := denominator_real * denominator_real + denominator_imaginary * denominator_imaginary
	response_real := (numerator_real * denominator_real + numerator_imaginary * denominator_imaginary) / denominator_magnitude_squared
	response_imaginary := (numerator_imaginary * denominator_real - numerator_real * denominator_imaginary) / denominator_magnitude_squared
	return f32(math.sqrt(response_real * response_real + response_imaginary * response_imaginary)), f32(math.atan2(response_imaginary, response_real))
}
