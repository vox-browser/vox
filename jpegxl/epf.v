// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

const epf_min_sigma = f32(-3.90524291751269967465540850526868)
const epf_inverse_sigma_numerator = f32(-1.1715728752538099024)

pub struct EpfParameters {
pub:
	sigma_scale           f32 = 1
	border_sad_multiplier f32 = f32(2) / f32(3)
	channel_scale         [3]f32
}

pub fn EpfParameters.default(sigma_scale f32) EpfParameters {
	return EpfParameters{ sigma_scale: sigma_scale, channel_scale: [f32(40), 5, 3.5]! }
}

// Values are the source's inverse sigma, not the positive metadata sigma.
// A block plane, when supplied, is indexed at global image coordinates / 8.
pub struct EpfSigma {
pub:
	inverse_sigma f32 = epf_inverse_sigma_numerator / f32(2)
	blocks        ?FloatPlane
}

pub fn EpfSigma.modular(sigma f32) !EpfSigma {
	if !math.is_finite(sigma) || sigma <= 0 { return error('Invalid JPEG XL modular EPF sigma') }
	value := epf_inverse_sigma_numerator / sigma
	if !math.is_finite(value) { return error('JPEG XL modular EPF sigma overflow') }
	return EpfSigma{ inverse_sigma: value }
}

struct EpfOffset {
	x int
	y int
}

const epf_cross = [EpfOffset{ y: -1 }, EpfOffset{ x: -1 }, EpfOffset{ x: 1 }, EpfOffset{ y: 1 }]
const epf_wide = [EpfOffset{ y: -2 }, EpfOffset{ x: -1, y: -1 }, EpfOffset{ y: -1 },
	EpfOffset{ x: 1, y: -1 }, EpfOffset{ x: -2 }, EpfOffset{ x: -1 }, EpfOffset{ x: 1 },
	EpfOffset{ x: 2 }, EpfOffset{ x: -1, y: 1 }, EpfOffset{ y: 1 }, EpfOffset{ x: 1, y: 1 },
	EpfOffset{ y: 2 }]
const epf_sad_patch = [EpfOffset{ y: -1 }, EpfOffset{ x: -1 }, EpfOffset{}, EpfOffset{ x: 1 },
	EpfOffset{ y: 1 }]

fn (plane FloatPlane) reflected(x int, y int) f32 {
	mut px := x % (plane.width * 2)
	mut py := y % (plane.height * 2)
	if px < 0 { px += plane.width * 2 }
	if py < 0 { py += plane.height * 2 }
	if px >= plane.width { px = plane.width * 2 - 1 - px }
	if py >= plane.height { py = plane.height * 2 - 1 - py }
	return plane.samples[py * plane.width + px]
}

fn validate_epf(input []FloatPlane, parameters EpfParameters, sigma EpfSigma, origin_x u32, origin_y u32) ! {
	if input.len != 3 { return error('JPEG XL EPF requires three planes') }
	for plane in input {
		plane.validate()!
		if plane.width != input[0].width || plane.height != input[0].height {
			return error('Incompatible JPEG XL EPF planes')
		}
	}
	if u64(input[0].samples.len) * 3 > 67108864 {
		return error('JPEG XL EPF sample limit exceeded')
	}
	scale := parameters.sigma_scale * f32(1.65)
	if !math.is_finite(scale) || !math.is_finite(parameters.border_sad_multiplier) || !math.is_finite(scale * parameters.border_sad_multiplier) {
		return error('Invalid JPEG XL EPF scale')
	}
	for value in parameters.channel_scale {
		if !math.is_finite(value) { return error('Invalid JPEG XL EPF channel scale') }
	}
	if blocks := sigma.blocks {
		blocks.validate()!
		columns := (u64(origin_x) + u64(input[0].width) + 7) / 8
		rows := (u64(origin_y) + u64(input[0].height) + 7) / 8
		if u64(blocks.width) < columns || u64(blocks.height) < rows {
			return error('JPEG XL EPF sigma map does not cover the plane')
		}
		for value in blocks.samples {
			if !math.is_finite(value) { return error('Invalid JPEG XL EPF block sigma') }
		}
	} else if !math.is_finite(sigma.inverse_sigma) {
		return error('Invalid JPEG XL EPF constant sigma')
	}
}

fn epf_sigma_value(sigma EpfSigma, x u64, y u64) f32 {
	if blocks := sigma.blocks { return blocks.samples[int(y / 8) * blocks.width + int(x / 8)] }
	return sigma.inverse_sigma
}

fn epf_weight(sad f32, inverse_sigma f32) f32 {
	value := fused_f32(sad, inverse_sigma, f32(1))
	return if value < 0 { f32(0) } else { value }
}

fn epf_planes(input []FloatPlane, parameters EpfParameters, sigma EpfSigma, origin_x u32, origin_y u32, pass int) ![]FloatPlane {
	validate_epf(input, parameters, sigma, origin_x, origin_y)!
	if pass < 0 || pass > 2 { return error('Unsupported JPEG XL EPF pass') }
	offsets := if pass == 0 { epf_wide } else { epf_cross }
	width := input[0].width
	height := input[0].height
	mut output := [][]f32{cap: 3}
	for _ in 0 .. 3 { output << []f32{len: input[0].samples.len} }
	scale := parameters.sigma_scale * f32(1.65)
	border_scale := scale * parameters.border_sad_multiplier
	for y in 0 .. height {
		for x in 0 .. width {
			position := y * width + x
			gx := u64(origin_x) + u64(x)
			gy := u64(origin_y) + u64(y)
			value := epf_sigma_value(sigma, gx, gy)
			if epf_min_sigma > value {
				for c in 0 .. 3 { output[c][position] = input[c].samples[position] }
				continue
			}
			inverse_sigma := value * if gx % 8 in [u64(0), 7] || gy % 8 in [u64(0), 7] {
				border_scale
			} else {
				scale
			}
			mut weights := [12]f32{}
			mut total := f32(1)
			mut sads := [12]f32{}
			if pass != 2 {
				for c in 0 .. 3 {
					for i, offset in offsets {
						mut distance := f32(0)
						for patch in epf_sad_patch {
							first := input[c].reflected(x + patch.x, y + patch.y)
							second := input[c].reflected(x + offset.x + patch.x, y + offset.y + patch.y)
							distance += math.abs(first - second)
						}
						sads[i] = if pass == 0 {
							fused_f32(parameters.channel_scale[c], distance, sads[i])
						} else {
							fused_f32(distance, parameters.channel_scale[c], sads[i])
						}
					}
				}
			}
			for i, offset in offsets {
				sad := if pass == 2 {
					first := math.abs(input[0].reflected(x + offset.x, y + offset.y) - input[0].samples[position])
					second := math.abs(input[1].reflected(x + offset.x, y + offset.y) - input[1].samples[position])
					third := math.abs(input[2].reflected(x + offset.x, y + offset.y) - input[2].samples[position])
					fused_f32(first, parameters.channel_scale[0], fused_f32(second, parameters.channel_scale[1], third * parameters.channel_scale[2]))
				} else {
					sads[i]
				}
				weights[i] = epf_weight(sad, inverse_sigma)
				total += weights[i]
			}
			inverse_weight := f32(1) / total
			for c in 0 .. 3 {
				mut sample := input[c].samples[position]
				for step in 0 .. offsets.len {
					i := if pass == 2 { step } else { offsets.len - 1 - step }
					offset := offsets[i]
					sample = if pass == 2 {
						fused_f32(weights[i], input[c].reflected(x + offset.x, y + offset.y), sample)
					} else {
						fused_f32(input[c].reflected(x + offset.x, y + offset.y), weights[i], sample)
					}
				}
				output[c][position] = sample * inverse_weight
			}
		}
	}
	return output.map(FloatPlane{ width: width, height: height, samples: it })
}
