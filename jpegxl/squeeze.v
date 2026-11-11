// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

fn modular_smooth_tendency(previous i64, average i64, next i64) i64 {
	mut difference := i64(0)
	if previous >= average && average >= next {
		difference = (4 * previous - 3 * next - average + 6) / 12
		if difference - (difference & 1) > 2 * (previous - average) {
			difference = 2 * (previous - average) + 1
		}
		if difference + (difference & 1) > 2 * (average - next) {
			difference = 2 * (average - next)
		}
	} else if previous <= average && average <= next {
		difference = (4 * previous - 3 * next - average - 6) / 12
		if difference + (difference & 1) < 2 * (previous - average) {
			difference = 2 * (previous - average) - 1
		}
		if difference - (difference & 1) < 2 * (average - next) {
			difference = 2 * (average - next)
		}
	}
	return difference
}

pub fn modular_squeeze_pair(average i32, residual i32, next_average i32, previous i32) [2]i32 {
	tendency := modular_smooth_tendency(previous, average, next_average)
	difference := i64(residual) + tendency
	first := i64(average) + difference / 2
	return [i32(first), i32(first - difference)]!
}

// Scalar whole-plane inverse. Transform scheduling supplies the output shift;
// neighboring tiles and border continuation are separate operations.
@[direct_array_access]
pub fn inverse_modular_squeeze(average ModularChannel, residual ModularChannel, horizontal bool, storage ModularStorage, output_shift ?ModularShift) !ModularChannel {
	average.validate()!
	residual.validate()!
	if horizontal {
		if average.height != residual.height || average.width < residual.width || average.width - residual.width > 1 {
			return error('Invalid JPEG XL horizontal squeeze dimensions')
		}
	} else {
		if average.width != residual.width || average.height < residual.height || average.height - residual.height > 1 {
			return error('Invalid JPEG XL vertical squeeze dimensions')
		}
	}
	width := if horizontal { average.width + residual.width } else { average.width }
	height := if horizontal { average.height } else { average.height + residual.height }
	mut output := ModularChannel.new(width, height, output_shift)!
	if output.samples.len == 0 { return output }
	// Indexing is direct: validate() and ModularChannel.new give every channel
	// width * height samples, and the dimension checks above bound each index.
	if horizontal {
		for y in 0 .. residual.height {
			average_row := y * average.width
			residual_row := y * residual.width
			output_row := y * width
			for x in 0 .. residual.width {
				value := modular_storage_value(average.samples[average_row + x], storage)
				remainder := modular_storage_value(residual.samples[residual_row + x], storage)
				next_x := if x + 1 < average.width { x + 1 } else { x }
				next := modular_storage_value(average.samples[average_row + next_x], storage)
				previous := if x > 0 { output.samples[output_row + 2 * x - 1] } else { value }
				pair := modular_squeeze_pair(value, remainder, next, previous)
				output.samples[output_row + 2 * x] = modular_storage_value(pair[0], storage)
				output.samples[output_row + 2 * x + 1] = modular_storage_value(pair[1], storage)
			}
		}
	} else {
		for y in 0 .. residual.height {
			average_row := y * average.width
			next_row := if y + 1 < average.height { (y + 1) * average.width } else { average_row }
			residual_row := y * residual.width
			first_row := 2 * y * width
			for x in 0 .. residual.width {
				value := modular_storage_value(average.samples[average_row + x], storage)
				remainder := modular_storage_value(residual.samples[residual_row + x], storage)
				next := modular_storage_value(average.samples[next_row + x], storage)
				previous := if y > 0 { output.samples[first_row - width + x] } else { value }
				pair := modular_squeeze_pair(value, remainder, next, previous)
				output.samples[first_row + x] = modular_storage_value(pair[0], storage)
				output.samples[first_row + width + x] = modular_storage_value(pair[1], storage)
			}
		}
	}
	if horizontal && average.width > residual.width {
		for y in 0 .. height {
			output.samples[y * width + width - 1] = modular_storage_value(average.samples[y * average.width + average.width - 1], storage)
		}
	} else if !horizontal && average.height > residual.height {
		for x in 0 .. width {
			output.samples[(height - 1) * width + x] = modular_storage_value(average.samples[(average.height - 1) * average.width + x], storage)
		}
	}
	return output
}
