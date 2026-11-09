// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub struct DequantMatrix {
pub:
	rows    int
	columns int
	// Three contiguous channels in the source's coefficient-table order.
	samples []f32
}

fn quant_band_multiplier(value f32) f32 {
	return if value > 0 { f32(1) + value } else { f32(1) / (f32(1) - value) }
}

fn quant_interpolate_position(position f32, bands []f32) !f32 {
	if !math.is_finite(position) || position < 0 {
		return error('Invalid JPEG XL quantization distance')
	}
	whole := math.floorf(position)
	index := int(whole)
	if index + 1 >= bands.len { return error('JPEG XL quantization distance exceeds bands') }
	fraction := position - whole
	ratio := bands[index + 1] / bands[index]
	power := math.powf(ratio, fraction)
	return power * bands[index]
}

fn quant_distance_weights(rows int, columns int, parameters DctQuantWeightParams) ![]f32 {
	count := parameters.parameters[0].len
	if rows < 2 || columns < 2 || count < 1 || count > 17 {
		return error('Invalid JPEG XL quantization band dimensions')
	}
	mut result := []f32{len: 3 * rows * columns}
	for c in 0 .. 3 {
		if parameters.parameters[c].len != count {
			return error('Incompatible JPEG XL quantization bands')
		}
		mut bands := []f32{len: 17}
		bands[0] = parameters.parameters[c][0]
		if bands[0] < f32(1e-8) { return error('Invalid JPEG XL initial distance band') }
		for i in 1 .. count {
			bands[i] = bands[i - 1] * quant_band_multiplier(parameters.parameters[c][i])
			if bands[i] < f32(1e-8) { return error('Invalid JPEG XL distance band') }
		}
		sqrt_two := f32(1.4142135623730951)
		denominator := sqrt_two + f32(1e-6)
		scale := f32(count - 1) / denominator
		rcp_column := scale / f32(columns - 1)
		rcp_row := scale / f32(rows - 1)
		for y in 0 .. rows {
			dy := f32(y) * rcp_row
			dy_squared := dy * dy
			for x in 0 .. columns {
				dx := f32(x) * rcp_column
				dx_squared := dx * dx
				distance_squared := dx_squared + dy_squared
				distance := math.sqrtf(distance_squared)
				weight := if count == 1 {
					bands[0]
				} else {
					quant_interpolate_position(distance, bands)!
				}
				result[c * rows * columns + y * columns + x] = weight
			}
		}
	}
	return result
}

fn validate_quant_rows(rows [3][]f32, count int) ! {
	for row in rows {
		if row.len != count { return error('Invalid JPEG XL quantization weight storage') }
	}
}

fn finalize_quant_matrix(rows int, columns int, mut weights []f32) !DequantMatrix {
	for i, weight in weights {
		if !(weight >= f32(1e-8) && weight <= f32(1) / f32(1e-8)) {
			return error('Invalid JPEG XL quantization table weight')
		}
		weights[i] = f32(1) / weight
	}
	return DequantMatrix{ rows: rows, columns: columns, samples: weights }
}

pub fn raw_quant_matrix(table_index int, values []i32, denominator f32) !DequantMatrix {
	blocks := quant_table_blocks(table_index)!
	rows := blocks[0] * 8
	columns := blocks[1] * 8
	if values.len != 3 * rows * columns {
		return error('Invalid JPEG XL raw quantization table size')
	}
	mut weights := []f32{len: values.len}
	for i, value in values {
		product := denominator * f32(value)
		weights[i] = f32(1) / product
	}
	return finalize_quant_matrix(rows, columns, mut weights)
}

pub fn compute_quant_matrix(encoding NonRawQuantEncoding, table_index int) !DequantMatrix {
	blocks := quant_table_blocks(table_index)!
	rows := blocks[0] * 8
	columns := blocks[1] * 8
	num := rows * columns
	if encoding is LibraryQuantEncoding {
		return compute_quant_matrix(library_quant_encoding(table_index)!, table_index)
	}
	if encoding !is DctQuantEncoding && num != 64 {
		return error('Invalid JPEG XL quantization encoding dimensions')
	}
	mut weights := []f32{len: 3 * num}
	match encoding {
		LibraryQuantEncoding { return error('Unresolved JPEG XL library quantization encoding') }
		IdentityQuantEncoding {
			validate_quant_rows(encoding.weights, 3)!
			for c in 0 .. 3 {
				for i in 0 .. 64 { weights[c * 64 + i] = encoding.weights[c][0] }
				weights[c * 64 + 1] = encoding.weights[c][1]
				weights[c * 64 + 8] = encoding.weights[c][1]
				weights[c * 64 + 9] = encoding.weights[c][2]
			}
		}
		Dct2QuantEncoding {
			validate_quant_rows(encoding.weights, 6)!
			for c in 0 .. 3 {
				start := c * 64
				weights[start] = f32(0xbad)
				weights[start + 1] = encoding.weights[c][0]
				weights[start + 8] = encoding.weights[c][0]
				weights[start + 9] = encoding.weights[c][1]
				for y in 0 .. 2 {
					for x in 0 .. 2 {
						weights[start + y * 8 + x + 2] = encoding.weights[c][2]
						weights[start + (y + 2) * 8 + x] = encoding.weights[c][2]
						weights[start + (y + 2) * 8 + x + 2] = encoding.weights[c][3]
					}
				}
				for y in 0 .. 4 {
					for x in 0 .. 4 {
						weights[start + y * 8 + x + 4] = encoding.weights[c][4]
						weights[start + (y + 4) * 8 + x] = encoding.weights[c][4]
						weights[start + (y + 4) * 8 + x + 4] = encoding.weights[c][5]
					}
				}
			}
		}
		Dct4QuantEncoding {
			validate_quant_rows(encoding.multipliers, 2)!
			small := quant_distance_weights(4, 4, encoding.parameters)!
			for c in 0 .. 3 {
				for y in 0 .. 8 {
					for x in 0 .. 8 {
						weights[c * num + y * 8 + x] = small[c * 16 + (y / 2) * 4 + x / 2]
					}
				}
				weights[c * num + 1] /= encoding.multipliers[c][0]
				weights[c * num + 8] /= encoding.multipliers[c][0]
				weights[c * num + 9] /= encoding.multipliers[c][1]
			}
		}
		Dct4x8QuantEncoding {
			validate_quant_rows(encoding.multipliers, 1)!
			small := quant_distance_weights(4, 8, encoding.parameters)!
			for c in 0 .. 3 {
				for y in 0 .. 8 {
					for x in 0 .. 8 {
						weights[c * num + y * 8 + x] = small[c * 32 + (y / 2) * 8 + x]
					}
				}
				weights[c * num + 8] /= encoding.multipliers[c][0]
			}
		}
		DctQuantEncoding { weights = quant_distance_weights(rows, columns, encoding.parameters)! }
		AfvQuantEncoding {
			validate_quant_rows(encoding.weights, 9)!
			small4x8 := quant_distance_weights(4, 8, encoding.parameters4x8)!
			small4x4 := quant_distance_weights(4, 4, encoding.parameters4x4)!
			frequencies := [f32(0xbad), f32(0xbad), 0.8517778890324296, 5.37778436506804, f32(0xbad),
				f32(0xbad), 4.734747904497923, 5.449245381693219, 1.6598270267479331, 4,
				7.275749096817861, 10.423227632456525, 2.662932286148962, 7.630657783650829,
				8.962388608184032, 12.97166202570235]!
			lo := f32(0.8517778890324296)
			hi_difference := f32(12.97166202570235) - lo
			hi := hi_difference + f32(1e-6)
			for c in 0 .. 3 {
				mut bands := []f32{len: 4}
				bands[0] = encoding.weights[c][5]
				if bands[0] < f32(1e-8) { return error('Invalid JPEG XL AFV initial band') }
				for i in 1 .. 4 {
					bands[i] = bands[i - 1] * quant_band_multiplier(encoding.weights[c][i + 5])
					if bands[i] < f32(1e-8) { return error('Invalid JPEG XL AFV distance band') }
				}
				start := c * 64
				weights[start] = 1
				for i, index in [8, 1, 16, 2, 18] {
					weights[start + index] = encoding.weights[c][i]
				}
				for y in 0 .. 4 {
					for x in 0 .. 4 {
						if x < 2 && y < 2 { continue }
						position := frequencies[y * 4 + x] - lo
						numerator := position * f32(3)
						scaled := numerator / hi
						weights[start + 2 * y * 8 + 2 * x] = quant_interpolate_position(scaled, bands)!
					}
				}
				for y in 0 .. 4 {
					for x in 0 .. 8 {
						if x == 0 && y == 0 { continue }
						weights[start + (2 * y + 1) * 8 + x] = small4x8[c * 32 + y * 8 + x]
					}
					for x in 0 .. 4 {
						if x == 0 && y == 0 { continue }
						weights[start + 2 * y * 8 + 2 * x + 1] = small4x4[c * 16 + y * 4 + x]
					}
				}
			}
		}
	}
	return finalize_quant_matrix(rows, columns, mut weights)
}
