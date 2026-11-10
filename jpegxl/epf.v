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

@[direct_array_access]
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

// The widest EPF reach is a two-sample offset plus the one-sample SAD patch.
const epf_pad = 3

// Copy a plane into a border of epf_pad samples filled by the same mirror rule
// as reflected(), so the filter reads neighbours without per-sample folding.
@[direct_array_access]
fn epf_padded(plane FloatPlane) []f32 {
	pw := plane.width + 2 * epf_pad
	ph := plane.height + 2 * epf_pad
	mut out := []f32{len: pw * ph}
	// An empty plane has no samples to filter, so its border is never read.
	if plane.width == 0 || plane.height == 0 { return out }
	for y in 0 .. ph {
		sy := y - epf_pad
		inner := sy >= 0 && sy < plane.height
		for x in 0 .. pw {
			sx := x - epf_pad
			out[y * pw + x] = if inner && sx >= 0 && sx < plane.width {
				plane.samples[sy * plane.width + sx]
			} else {
				plane.reflected(sx, sy)
			}
		}
	}
	return out
}

// Each pass runs row by row: per-offset SADs, weights and the weighted sum are
// computed for a whole row in separate loops over x, which the C compiler can
// vectorize. Every pixel keeps the source's operation order: channel-major
// SAD accumulation, weights summed in offset order, and the same fused
// multiply-adds for the weighted sum.
@[direct_array_access]
fn epf_planes(input []FloatPlane, parameters EpfParameters, sigma EpfSigma, origin_x u32, origin_y u32, pass int) ![]FloatPlane {
	validate_epf(input, parameters, sigma, origin_x, origin_y)!
	if pass < 0 || pass > 2 { return error('Unsupported JPEG XL EPF pass') }
	offsets := if pass == 0 { epf_wide } else { epf_cross }
	n := offsets.len
	width := input[0].width
	height := input[0].height
	pw := width + 2 * epf_pad
	padded := [epf_padded(input[0]), epf_padded(input[1]), epf_padded(input[2])]!
	mut offset_deltas := [12]int{}
	for i in 0 .. n { offset_deltas[i] = offsets[i].y * pw + offsets[i].x }
	mut patch_deltas := [5]int{}
	for k in 0 .. 5 { patch_deltas[k] = epf_sad_patch[k].y * pw + epf_sad_patch[k].x }
	mut output := [3][]f32{}
	for c in 0 .. 3 { output[c] = []f32{len: input[0].samples.len} }
	scale := parameters.sigma_scale * f32(1.65)
	border_scale := scale * parameters.border_sad_multiplier
	mut sads := [][]f32{len: n, init: []f32{len: width}}
	mut weights := [][]f32{len: n, init: []f32{len: width}}
	mut inverse_sigma := []f32{len: width}
	mut inverse_weight := []f32{len: width}
	mut skip := []bool{len: width}
	for y in 0 .. height {
		gy := u64(origin_y) + u64(y)
		row_base := (y + epf_pad) * pw + epf_pad
		row_start := y * width
		for x in 0 .. width {
			gx := u64(origin_x) + u64(x)
			value := epf_sigma_value(sigma, gx, gy)
			skip[x] = epf_min_sigma > value
			inverse_sigma[x] = value * if gx % 8 in [u64(0), 7] || gy % 8 in [u64(0), 7] {
				border_scale
			} else {
				scale
			}
		}
		if pass != 2 {
			for i in 0 .. n {
				dst := unsafe { &f32(sads[i].data) }
				for x in 0 .. width { unsafe { dst[x] = 0 } }
			}
			for c in 0 .. 3 {
				src := unsafe { &f32(padded[c].data) }
				channel_scale := parameters.channel_scale[c]
				for i in 0 .. n {
					dst := unsafe { &f32(sads[i].data) }
					delta := offset_deltas[i]
					for x in 0 .. width {
						b := row_base + x
						mut distance := f32(0)
						for k in 0 .. 5 {
							pd := patch_deltas[k]
							distance += unsafe { math.abs(src[b + pd] - src[b + delta + pd]) }
						}
						unsafe {
							dst[x] = if pass == 0 {
								fused_f32(channel_scale, distance, dst[x])
							} else {
								fused_f32(distance, channel_scale, dst[x])
							}
						}
					}
				}
			}
		}
		for x in 0 .. width { inverse_weight[x] = 1 }
		for i in 0 .. n {
			delta := offset_deltas[i]
			wrow := unsafe { &f32(weights[i].data) }
			srow := unsafe { &f32(sads[i].data) }
			for x in 0 .. width {
				sad := if pass == 2 {
					b := row_base + x
					position := row_start + x
					first := math.abs(padded[0][b + delta] - input[0].samples[position])
					second := math.abs(padded[1][b + delta] - input[1].samples[position])
					third := math.abs(padded[2][b + delta] - input[2].samples[position])
					fused_f32(first, parameters.channel_scale[0], fused_f32(second, parameters.channel_scale[1], third * parameters.channel_scale[2]))
				} else {
					unsafe { srow[x] }
				}
				weight := epf_weight(sad, inverse_sigma[x])
				unsafe { wrow[x] = weight }
				// inverse_weight accumulates the total here and is inverted below.
				inverse_weight[x] += weight
			}
		}
		for x in 0 .. width { inverse_weight[x] = f32(1) / inverse_weight[x] }
		for c in 0 .. 3 {
			src := unsafe { &f32(padded[c].data) }
			inp := unsafe { &f32(input[c].samples.data) }
			out := unsafe { &f32(output[c].data) }
			for x in 0 .. width {
				position := row_start + x
				if skip[x] {
					unsafe { out[position] = inp[position] }
					continue
				}
				b := row_base + x
				mut sample := unsafe { inp[position] }
				for step in 0 .. n {
					i := if pass == 2 { step } else { n - 1 - step }
					weight := weights[i][x]
					sample = if pass == 2 {
						fused_f32(weight, unsafe { src[b + offset_deltas[i]] }, sample)
					} else {
						fused_f32(unsafe { src[b + offset_deltas[i]] }, weight, sample)
					}
				}
				unsafe { out[position] = sample * inverse_weight[x] }
			}
		}
	}
	return [FloatPlane{ width: width, height: height, samples: output[0] },
		FloatPlane{ width: width, height: height, samples: output[1] },
		FloatPlane{ width: width, height: height, samples: output[2] }]
}
