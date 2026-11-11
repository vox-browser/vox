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
		if !all_finite(blocks.samples) { return error('Invalid JPEG XL EPF block sigma') }
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

// The mirror rule of reflected() for one coordinate in a dimension of n > 0 samples.
@[inline]
fn epf_reflect_index(v int, n int) int {
	mut p := v % (n * 2)
	if p < 0 { p += n * 2 }
	if p >= n { p = n * 2 - 1 - p }
	return p
}

// Copy a plane into a border of epf_pad samples filled by the same mirror rule
// as reflected(), so the filter reads neighbours without per-sample folding.
@[direct_array_access]
fn epf_padded(plane FloatPlane) []f32 {
	pw := plane.width + 2 * epf_pad
	ph := plane.height + 2 * epf_pad
	mut out := []f32{len: pw * ph}
	// An empty plane has no samples to filter, so its border is never read.
	if plane.width == 0 || plane.height == 0 { return out }
	if plane.samples.len < plane.width * plane.height { panic('Invalid JPEG XL EPF plane') }
	width := plane.width
	mut left := [epf_pad]int{}
	mut right := [epf_pad]int{}
	for i in 0 .. epf_pad {
		left[i] = epf_reflect_index(i - epf_pad, width)
		right[i] = epf_reflect_index(width + i, width)
	}
	src := unsafe { &f32(plane.samples.data) }
	dst := unsafe { &f32(out.data) }
	for y in 0 .. ph {
		row := unsafe { src + epf_reflect_index(y - epf_pad, plane.height) * width }
		line := unsafe { dst + y * pw }
		for i in 0 .. epf_pad {
			unsafe {
				line[i] = row[left[i]]
				line[epf_pad + width + i] = row[right[i]]
			}
		}
		unsafe { vmemcpy(line + epf_pad, row, width * int(sizeof(f32))) }
	}
	return out
}

// Channel-accumulated SADs of one offset for `count` consecutive pixels whose
// first padded index is `base`, in the source's channel-major order.
@[direct_array_access]
fn epf_offset_sads(out &f32, padded [3][]f32, base int, delta int, patch_deltas [5]int, channel_scale [3]f32, count int, pass int) {
	for x in 0 .. count { unsafe { out[x] = 0 } }
	for c in 0 .. 3 {
		src := unsafe { &f32(padded[c].data) }
		scale := channel_scale[c]
		for x in 0 .. count {
			b := base + x
			mut distance := f32(0)
			for k in 0 .. 5 {
				pd := patch_deltas[k]
				distance += unsafe { math.abs(src[b + pd] - src[b + delta + pd]) }
			}
			unsafe {
				out[x] = if pass == 0 {
					fused_f32(scale, distance, out[x])
				} else {
					fused_f32(distance, scale, out[x])
				}
			}
		}
	}
}

// The pass 2 SAD of one pixel: its three channel differences to the sample at
// `delta`, accumulated from the last channel as in the source.
@[inline]
fn epf_pixel_sad(p0 &f32, p1 &f32, p2 &f32, x int, delta int, cs0 f32, cs1 f32, cs2 f32) f32 {
	return unsafe {
		fused_f32(math.abs(p0[x + delta] - p0[x]), cs0, fused_f32(math.abs(p1[x + delta] - p1[x]), cs1,
			math.abs(p2[x + delta] - p2[x]) * cs2))
	}
}

// `kept` where mask is all ones and `filtered` where it is zero. The bitwise
// form lets the C compiler vectorize the output loops.
@[inline]
fn epf_select(mask u32, kept f32, filtered f32) f32 {
	return math.f32_from_bits((math.f32_bits(kept) & mask) | (math.f32_bits(filtered) & ~mask))
}

// out[i] = |src[start + i] - src[start + i + delta]| for i in 0 .. count: the
// per-sample terms of a SAD with offset delta, in the operand order of
// epf_offset_sads.
@[direct_array_access]
fn epf_abs_diff_row(out &f32, src &f32, start int, delta int, count int) {
	for i in 0 .. count {
		unsafe {
			out[i] = math.abs(src[start + i] - src[start + i + delta])
		}
	}
}

// The three channel rows in ring slot `slot` of a difference buffer holding
// three rows of `stride` samples per channel.
@[inline]
fn epf_ring_rows(base &f32, slot int, stride int) [3]&f32 {
	return unsafe { [base + slot * stride, base + (3 + slot) * stride, base + (6 + slot) * stride]! }
}

// Pass 1 SADs of `count` pixels from per-channel difference rows. For channel c,
// above, middle and below point at its difference rows for the pixel row
// before, at and after the SAD row, indexed from column -1. The five terms are
// added in the source's patch order (up, left, centre, right, down).
@[direct_array_access]
fn epf_cross_sads(out &f32, above [3]&f32, middle [3]&f32, below [3]&f32, channel_scale [3]f32, count int) {
	a0 := above[0]
	a1 := above[1]
	a2 := above[2]
	m0 := middle[0]
	m1 := middle[1]
	m2 := middle[2]
	b0 := below[0]
	b1 := below[1]
	b2 := below[2]
	cs0 := channel_scale[0]
	cs1 := channel_scale[1]
	cs2 := channel_scale[2]
	for x in 0 .. count {
		unsafe {
			d0 := f32(0) + a0[x + 1] + m0[x] + m0[x + 1] + m0[x + 2] + b0[x + 1]
			d1 := f32(0) + a1[x + 1] + m1[x] + m1[x + 1] + m1[x + 2] + b1[x + 1]
			d2 := f32(0) + a2[x + 1] + m2[x] + m2[x + 1] + m2[x + 2] + b2[x + 1]
			out[x] = fused_f32(d2, cs2, fused_f32(d1, cs1, fused_f32(d0, cs0, f32(0))))
		}
	}
}

// Each pass runs row by row with loops over x that the C compiler vectorizes.
// Every pixel keeps the source's operation order: channel-major SAD
// accumulation, weights summed in offset order and the same fused
// multiply-adds for the weighted sum. A SAD is symmetric in its two patches
// (|a - b| and |b - a| are bit-identical and summed in the same order), so for
// opposite offsets o and -o, sad(-o) at p equals sad(o) at p - o. Pass 1
// computes only its up and left SADs and reads down and right from the next
// row and column.
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
	mut block_data := unsafe { &f32(nil) }
	mut block_width := 0
	if blocks := sigma.blocks {
		block_data = unsafe { &f32(blocks.samples.data) }
		block_width = blocks.width
	}
	// Pass 0 keeps one SAD row per offset; pass 1 keeps up rows for y and y + 1
	// and a left row one sample wider than the plane.
	mut sads := []f32{len: if pass == 0 { n * width } else { 0 }}
	mut up_current := []f32{len: if pass == 1 { width } else { 0 }}
	mut up_next := []f32{len: if pass == 1 { width } else { 0 }}
	mut left := []f32{len: if pass == 1 { width + 1 } else { 0 }}
	mut weights := []f32{len: n * width}
	mut inner_sigma := []f32{len: width}
	mut border_sigma := []f32{len: width}
	mut cached_sigma_key := i64(-1)
	mut inverse_weight := []f32{len: width}
	// All ones where sigma is too small to filter.
	mut skip := []u32{len: width}
	mut acc := []f32{len: if pass == 0 { width } else { 0 }}
	// Pass 1 SAD terms are vertical (up) and horizontal (left) absolute
	// differences, each shared by five SADs. Three rows of each are kept per
	// channel, from column -1: vertical through column width and horizontal
	// through column width + 1. Row r lives in slot (r + 3) % 3.
	vw := width + 2
	hw := width + 3
	mut vertical := []f32{len: if pass == 1 { 9 * vw } else { 0 }}
	mut horizontal := []f32{len: if pass == 1 { 9 * hw } else { 0 }}
	if pass == 1 && height > 0 {
		epf_offset_sads(unsafe { &f32(up_current.data) }, padded, epf_pad * pw + epf_pad, offset_deltas[0],
			patch_deltas, parameters.channel_scale, width, pass)
		for c in 0 .. 3 {
			src := unsafe { &f32(padded[c].data) }
			for r in 0 .. 2 {
				epf_abs_diff_row(unsafe { &f32(vertical.data) + (c * 3 + (r + 3) % 3) * vw }, src,
					(r + epf_pad) * pw + epf_pad - 1, offset_deltas[0], vw)
				epf_abs_diff_row(unsafe { &f32(horizontal.data) + (c * 3 + (r - 1 + 3) % 3) * hw }, src,
					(r - 1 + epf_pad) * pw + epf_pad - 1, offset_deltas[1], hw)
			}
		}
	}
	for y in 0 .. height {
		gy := u64(origin_y) + u64(y)
		row_base := (y + epf_pad) * pw + epf_pad
		row_start := y * width
		border_row := gy % 8 == 0 || gy % 8 == 7
		block_row := int(gy / 8) * block_width
		// Sigma is constant within an 8x8 block, so both row variants of the scaled
		// inverse sigma and the skip flags change only with the block row.
		sigma_key := if block_width > 0 { i64(gy / 8) } else { i64(0) }
		if sigma_key != cached_sigma_key {
			cached_sigma_key = sigma_key
			for x in 0 .. width {
				gx := u64(origin_x) + u64(x)
				value := if block_width > 0 { unsafe { block_data[block_row + int(gx / 8)] } } else { sigma.inverse_sigma }
				skip[x] = if epf_min_sigma > value { u32(0xffffffff) } else { u32(0) }
				border_sigma[x] = value * border_scale
				inner_sigma[x] = value * if gx % 8 == 0 || gx % 8 == 7 { border_scale } else { scale }
			}
		}
		inverse_sigma := if border_row { unsafe { &f32(border_sigma.data) } } else { unsafe { &f32(inner_sigma.data) } }
		if pass == 0 {
			for i in 0 .. n {
				epf_offset_sads(unsafe { &f32(sads.data) + i * width }, padded, row_base, offset_deltas[i],
					patch_deltas, parameters.channel_scale, width, pass)
			}
		} else if pass == 1 {
			// Add vertical row y + 2 and horizontal row y + 1, then form the up SADs
			// of row y + 1 and the left SADs of row y.
			vbase := unsafe { &f32(vertical.data) }
			hbase := unsafe { &f32(horizontal.data) }
			v_above := epf_ring_rows(vbase, y % 3, vw)
			v_middle := epf_ring_rows(vbase, (y + 1) % 3, vw)
			v_below := epf_ring_rows(vbase, (y + 2) % 3, vw)
			h_above := epf_ring_rows(hbase, (y + 2) % 3, hw)
			h_middle := epf_ring_rows(hbase, y % 3, hw)
			h_below := epf_ring_rows(hbase, (y + 1) % 3, hw)
			for c in 0 .. 3 {
				src := unsafe { &f32(padded[c].data) }
				epf_abs_diff_row(v_below[c], src, row_base + 2 * pw - 1, offset_deltas[0], vw)
				epf_abs_diff_row(h_below[c], src, row_base + pw - 1, offset_deltas[1], hw)
			}
			epf_cross_sads(unsafe { &f32(up_next.data) }, v_above, v_middle, v_below, parameters.channel_scale, width)
			epf_cross_sads(unsafe { &f32(left.data) }, h_above, h_middle, h_below, parameters.channel_scale, width + 1)
		}
		if pass == 0 {
			for x in 0 .. width { inverse_weight[x] = 1 }
			for i in 0 .. n {
				wrow := unsafe { &f32(weights.data) + i * width }
				src := unsafe { &f32(sads.data) + i * width }
				for x in 0 .. width {
					weight := epf_weight(unsafe { src[x] }, unsafe { inverse_sigma[x] })
					unsafe { wrow[x] = weight }
					inverse_weight[x] += weight
				}
			}
			for x in 0 .. width { inverse_weight[x] = f32(1) / inverse_weight[x] }
			for c in 0 .. 3 {
				src := unsafe { &f32(padded[c].data) }
				inp := unsafe { &f32(input[c].samples.data) }
				out := unsafe { &f32(output[c].data) }
				for x in 0 .. width { acc[x] = unsafe { inp[row_start + x] } }
				for step in 0 .. n {
					i := n - 1 - step
					wrow := unsafe { &f32(weights.data) + i * width }
					base := row_base + offset_deltas[i]
					for x in 0 .. width { acc[x] = fused_f32(unsafe { src[base + x] }, unsafe { wrow[x] }, acc[x]) }
				}
				for x in 0 .. width {
					unsafe {
						kept := inp[row_start + x]
						filtered := acc[x] * inverse_weight[x]
						out[row_start + x] = epf_select(skip[x], kept, filtered)
					}
				}
			}
		} else {
			// The four cross offsets are up, left, right and down. Their weights
			// are summed in that order and kept for the three channels.
			w0 := unsafe { &f32(weights.data) }
			w1 := unsafe { w0 + width }
			w2 := unsafe { w1 + width }
			w3 := unsafe { w2 + width }
			if pass == 1 {
				s0 := unsafe { &f32(up_current.data) }
				s1 := unsafe { &f32(left.data) }
				s2 := unsafe { s1 + 1 }
				s3 := unsafe { &f32(up_next.data) }
				for x in 0 .. width {
					unsafe {
						a := epf_weight(s0[x], inverse_sigma[x])
						b := epf_weight(s1[x], inverse_sigma[x])
						c := epf_weight(s2[x], inverse_sigma[x])
						d := epf_weight(s3[x], inverse_sigma[x])
						w0[x] = a
						w1[x] = b
						w2[x] = c
						w3[x] = d
						inverse_weight[x] = f32(1) / ((((f32(1) + a) + b) + c) + d)
					}
				}
			} else {
				p0 := unsafe { &f32(padded[0].data) + row_base }
				p1 := unsafe { &f32(padded[1].data) + row_base }
				p2 := unsafe { &f32(padded[2].data) + row_base }
				cs0 := parameters.channel_scale[0]
				cs1 := parameters.channel_scale[1]
				cs2 := parameters.channel_scale[2]
				for x in 0 .. width {
					unsafe {
						a := epf_weight(epf_pixel_sad(p0, p1, p2, x, offset_deltas[0], cs0, cs1, cs2), inverse_sigma[x])
						b := epf_weight(epf_pixel_sad(p0, p1, p2, x, offset_deltas[1], cs0, cs1, cs2), inverse_sigma[x])
						c := epf_weight(epf_pixel_sad(p0, p1, p2, x, offset_deltas[2], cs0, cs1, cs2), inverse_sigma[x])
						d := epf_weight(epf_pixel_sad(p0, p1, p2, x, offset_deltas[3], cs0, cs1, cs2), inverse_sigma[x])
						w0[x] = a
						w1[x] = b
						w2[x] = c
						w3[x] = d
						inverse_weight[x] = f32(1) / ((((f32(1) + a) + b) + c) + d)
					}
				}
			}
			for c in 0 .. 3 {
				src := unsafe { &f32(padded[c].data) + row_base }
				inp := unsafe { &f32(input[c].samples.data) + row_start }
				out := unsafe { &f32(output[c].data) + row_start }
				// FastC types `pointer + fixed_array[i]` as the pointee; cast the offsets.
				up := unsafe { src + int(offset_deltas[0]) }
				lt := unsafe { src + int(offset_deltas[1]) }
				rt := unsafe { src + int(offset_deltas[2]) }
				dn := unsafe { src + int(offset_deltas[3]) }
				if pass == 2 {
					// Offset order with the weight as the first factor.
					for x in 0 .. width {
						unsafe {
							kept := inp[x]
							mut v := kept
							v = fused_f32(w0[x], up[x], v)
							v = fused_f32(w1[x], lt[x], v)
							v = fused_f32(w2[x], rt[x], v)
							v = fused_f32(w3[x], dn[x], v)
							filtered := v * inverse_weight[x]
							out[x] = epf_select(skip[x], kept, filtered)
						}
					}
				} else {
					// Reverse offset order with the sample as the first factor.
					for x in 0 .. width {
						unsafe {
							kept := inp[x]
							mut v := kept
							v = fused_f32(dn[x], w3[x], v)
							v = fused_f32(rt[x], w2[x], v)
							v = fused_f32(lt[x], w1[x], v)
							v = fused_f32(up[x], w0[x], v)
							filtered := v * inverse_weight[x]
							out[x] = epf_select(skip[x], kept, filtered)
						}
					}
				}
			}
		}
		if pass == 1 {
			// Swap the two row buffers; neither is shared outside this function.
			unsafe {
				up_current, up_next = up_next, up_current
			}
		}
	}
	return [FloatPlane{ width: width, height: height, samples: output[0] },
		FloatPlane{ width: width, height: height, samples: output[1] },
		FloatPlane{ width: width, height: height, samples: output[2] }]
}
