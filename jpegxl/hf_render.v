// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct HfGroupColorMap {
pub:
	y_to_x []i32
	y_to_b []i32
}

pub struct HfGroupRendering {
pub:
	storage           ModularStorage
	quantizer         QuantizerParams
	x_qm_scale        u32
	b_qm_scale        u32
	color_correlation ColorCorrelationParams
	biases            [4]f32
}

// Reconstruct one group's padded component planes before chroma upsampling and
// restoration. LF planes use local, already subsampled coordinates. Coefficient
// slots have the same sequential transform ordering as decode_hf_group.
pub fn render_hf_group(maps HfGroupMaps, params HfGroupParameters, context BlockContextMap, colors HfGroupColorMap, lf [3]FloatPlane, coefficients [3][]i32, matrices DequantMatrices, rendering HfGroupRendering) ![3]FloatPlane {
	blocks := maps.blocks(params, context)!
	color_width := (maps.width + 7) / 8
	color_height := (maps.height + 7) / 8
	if colors.y_to_x.len != color_width * color_height || colors.y_to_b.len != colors.y_to_x.len {
		return error('Invalid JPEG XL HF color map storage')
	}
	for factor in colors.y_to_x { if factor < -128 || factor > 127 { return error('Invalid JPEG XL HF color map factor') } }
	for factor in colors.y_to_b { if factor < -128 || factor > 127 { return error('Invalid JPEG XL HF color map factor') } }
	mut output := [3]FloatPlane{}
	mut samples := [3][]f32{}
	for c in 0 .. 3 {
		lf[c].validate()!
		if coefficients[c].len != maps.width * maps.height * 64
			|| lf[c].width != maps.width >> params.horizontal_shift[c]
			|| lf[c].height != maps.height >> params.vertical_shift[c] {
			return error('Invalid JPEG XL HF render component geometry')
		}
		samples[c] = []f32{len: lf[c].width * lf[c].height * 64}
	}
	for block in blocks {
		dims := block.transform.covered_blocks()
		count := dims[0] * dims[1] * 64
		color_index := (block.y / 8) * color_width + block.x / 8
		quantized := [coefficients[0][block.offset..block.offset + count],
			coefficients[1][block.offset..block.offset + count], coefficients[2][block.offset..block.offset + count]]!
		dequantized := dequantize_hf_block(quantized, matrices, HfDequantParameters{
			transform: block.transform
			storage: rendering.storage
			quantizer: rendering.quantizer
			raw_quant: u32(maps.raw_quant[block.y * maps.width + block.x])
			x_qm_scale: rendering.x_qm_scale
			b_qm_scale: rendering.b_qm_scale
			color_correlation: rendering.color_correlation
			x_color_factor: colors.y_to_x[color_index]
			b_color_factor: colors.y_to_b[color_index]
			biases: rendering.biases
		})!
		for c in [1, 0, 2] {
			h := params.horizontal_shift[c]
			v := params.vertical_shift[c]
			x := block.x >> h
			y := block.y >> v
			if (x << h) != block.x || (y << v) != block.y { continue }
			mut low := []f32{len: dims[0] * dims[1]}
			for iy in 0 .. dims[1] {
				for ix in 0 .. dims[0] { low[iy * dims[0] + ix] = lf[c].samples[(y + iy) * lf[c].width + x + ix] }
			}
			plane := inverse_hf_transform(block.transform, low, dequantized[c])!
			stride := lf[c].width * 8
			for iy in 0 .. plane.height {
				destination := (y * 8 + iy) * stride + x * 8
				for ix in 0 .. plane.width { samples[c][destination + ix] = plane.samples[iy * plane.width + ix] }
			}
		}
	}
	for c in 0 .. 3 { output[c] = FloatPlane{ width: lf[c].width * 8, height: lf[c].height * 8, samples: samples[c] } }
	return output
}
