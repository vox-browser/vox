// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebAudio/Rendering/FFT.{h,cpp}.
module webaudio

import math

pub enum FFTDirection {
	forward
	inverse
}

// A fixed-size radix-2 transform retains its twiddle factors so every update
// uses directly computed values instead of accumulating a running product.
pub struct FFT {
	size_              int
	twiddle_real_      []f32
	twiddle_imaginary_ []f32
}

pub fn FFT.create(size int) FFT {
	assert size > 0 && size & (size - 1) == 0
	mut real := []f32{len: size / 2}
	mut imaginary := []f32{len: size / 2}
	for index in 0 .. size / 2 {
		angle := -2.0 * math.pi * f64(index) / f64(size)
		real[index] = f32(math.cos(angle))
		imaginary[index] = f32(math.sin(angle))
	}
	return FFT{
		size_: size
		twiddle_real_: real
		twiddle_imaginary_: imaginary
	}
}

pub fn (fft FFT) size() int {
	return fft.size_
}

// Both arrays contain exactly size() samples. Inverse transforms include 1/N
// scaling, whereas forward transforms leave normalization to the caller.
pub fn (fft FFT) transform(mut real []f32, mut imaginary []f32, direction FFTDirection) {
	assert real.len == fft.size_ && imaginary.len == fft.size_
	mut j := 0
	for i := 1; i < fft.size_; i++ {
		mut bit := fft.size_ >> 1
		for j & bit != 0 {
			j ^= bit
			bit >>= 1
		}
		j ^= bit
		if i < j {
			real[i], real[j] = real[j], real[i]
			imaginary[i], imaginary[j] = imaginary[j], imaginary[i]
		}
	}
	twiddle_sign := if direction == .forward { f32(1) } else { f32(-1) }
	mut length := 2
	for length <= fft.size_ {
		half := length >> 1
		stride := fft.size_ / length
		for start := 0; start < fft.size_; start += length {
			for offset in 0 .. half {
				weight_real := fft.twiddle_real_[offset * stride]
				weight_imaginary := fft.twiddle_imaginary_[offset * stride] * twiddle_sign
				upper_real := real[start + offset]
				upper_imaginary := imaginary[start + offset]
				lower_real := real[start + offset + half] * weight_real - imaginary[start + offset + half] * weight_imaginary
				lower_imaginary := real[start + offset + half] * weight_imaginary + imaginary[start + offset + half] * weight_real
				real[start + offset] = upper_real + lower_real
				imaginary[start + offset] = upper_imaginary + lower_imaginary
				real[start + offset + half] = upper_real - lower_real
				imaginary[start + offset + half] = upper_imaginary - lower_imaginary
			}
		}
		length <<= 1
	}
	if direction == .inverse {
		inverse_size := f32(1.0 / f64(fft.size_))
		for index in 0 .. fft.size_ {
			real[index] *= inverse_size
			imaginary[index] *= inverse_size
		}
	}
}

fn (fft FFT) magnitudes(input []f32) []f32 {
	mut real := input.clone()
	mut imaginary := []f32{len: input.len}
	fft.transform(mut real, mut imaginary, .forward)
	mut result := []f32{len: fft.size_ / 2}
	inverse_length := f32(1.0 / f64(fft.size_))
	for index in 0 .. result.len {
		result[index] = f32(math.sqrt(f64(real[index] * real[index] + imaginary[index] * imaginary[index]))) * inverse_length
	}
	return result
}
