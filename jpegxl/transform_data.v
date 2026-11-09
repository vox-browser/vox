// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct OpsinInverseMatrix {
pub:
	inverse_matrix [9]f32
	opsin_biases   [3]f32
	quant_biases   [4]f32
}

pub struct CustomTransformData {
pub:
	opsin    OpsinInverseMatrix
	weights2 [15]f32
	weights4 [55]f32
	weights8 [210]f32
}

fn default_opsin() OpsinInverseMatrix {
	return OpsinInverseMatrix{
		inverse_matrix: [f32(11.031566901960783), -9.866943921568629, -0.16462299647058826,
			-3.254147380392157, 4.418770392156863, -0.16462299647058826, -3.6588512862745097,
			2.7129230470588235, 1.9459282392156863]!
		opsin_biases:   [f32(-0.0037930732552754493), -0.0037930732552754493, -0.0037930732552754493]!
		quant_biases:   [f32(1) - f32(0.05465007330715401), f32(1) - f32(0.07005449891748593),
			f32(1) - f32(0.049935103337343655), f32(0.145)]!
	}
}

fn (mut reader BitReader) read_opsin_matrix() !OpsinInverseMatrix {
	if reader.read(1)! != 0 { return default_opsin() }
	mut matrix := [9]f32{}
	mut biases := [3]f32{}
	mut quant := [4]f32{}
	for i in 0 .. 9 { matrix[i] = reader.read_f16()! }
	for i in 0 .. 3 { biases[i] = reader.read_f16()! }
	for i in 0 .. 4 { quant[i] = reader.read_f16()! }
	return OpsinInverseMatrix{ inverse_matrix: matrix, opsin_biases: biases, quant_biases: quant }
}

pub fn (mut reader BitReader) read_transform_data(xyb_encoded bool) !CustomTransformData {
	all_default := reader.read(1)! != 0
	opsin := if !all_default && xyb_encoded { reader.read_opsin_matrix()! } else { default_opsin() }
	mask := if all_default { u64(0) } else { reader.read(3)! }
	mut weights2 := [15]f32{}
	mut weights4 := [55]f32{}
	mut weights8 := [210]f32{}
	for i, value in default_kernel_2 { weights2[i] = value }
	for i, value in default_kernel_4 { weights4[i] = value }
	for i, value in default_kernel_8 { weights8[i] = value }
	if mask & 1 != 0 {
		for i in 0 .. 15 { weights2[i] = reader.read_f16()! }
	}
	if mask & 2 != 0 {
		for i in 0 .. 55 { weights4[i] = reader.read_f16()! }
	}
	if mask & 4 != 0 {
		for i in 0 .. 210 { weights8[i] = reader.read_f16()! }
	}
	return CustomTransformData{ opsin: opsin, weights2: weights2, weights4: weights4, weights8: weights8 }
}
