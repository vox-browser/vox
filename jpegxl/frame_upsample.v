// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Filtering is performed at coded resolution before image upsampling.
fn frame_filter_geometry(frame FrameHeader) FrameHeader {
	size := frame.size()
	return FrameHeader{ ...frame, width: size.width, height: size.height, lf_level: 0, upsampling: 1 }
}

fn upsample_frame_planes(input [3]FloatPlane, frame FrameHeader, transform CustomTransformData) ![3]FloatPlane {
	if frame.upsampling == 1 { return input }
	weights := match frame.upsampling {
		2 { transform.weights2[..] }
		4 { transform.weights4[..] }
		8 { transform.weights8[..] }
		else { return error('Invalid JPEG XL frame upsampling factor') }
	}
	size := frame.size_upsampled()
	if u64(size.width) * u64(size.height) > 67108864 / 3 { return error('JPEG XL frame upsampling sample budget exceeded') }
	mut output := [3]FloatPlane{}
	for c in 0 .. 3 { output[c] = upsample_plane(input[c], int(frame.upsampling), weights, int(size.width), int(size.height))! }
	return output
}

// Draw cached spline segments into the three restored color planes. As in the
// source pipeline, this runs after Gaborish/EPF and before image upsampling,
// so the cache uses coded frame coordinates. Extra channels are unchanged.
fn draw_frame_splines(input [3]FloatPlane, cache SplineDrawCache) ![3]FloatPlane {
	if cache.segments.len == 0 { return input }
	width := input[0].width
	height := input[0].height
	for c in 0 .. 3 {
		input[c].validate()!
		if input[c].width != width || input[c].height != height {
			return error('Invalid JPEG XL spline plane geometry')
		}
	}
	if cache.width != width || cache.height != height {
		return error('JPEG XL spline cache does not match the frame')
	}
	mut samples := [3][]f32{}
	for c in 0 .. 3 { samples[c] = input[c].samples.clone() }
	mut row := [][]f32{len: 3}
	for y in 0 .. height {
		start := y * width
		for c in 0 .. 3 { row[c] = samples[c][start..start + width].clone() }
		cache.draw_row(mut row, 0, y)!
		for c in 0 .. 3 {
			for x in 0 .. width { samples[c][start + x] = row[c][x] }
		}
	}
	return [FloatPlane{ width: width, height: height, samples: samples[0] },
		FloatPlane{ width: width, height: height, samples: samples[1] },
		FloatPlane{ width: width, height: height, samples: samples[2] }]!
}

fn render_vardct_frame(raw VarDctFramePlanes, frame FrameHeader, transform CustomTransformData, patch_refs []PatchFrameReference) ![3]FloatPlane {
	if frame.has_patches() != (raw.patches != none) { return error('JPEG XL patch dictionary disagrees with the frame') }
	mut restored := restore_vardct_frame(raw, frame_filter_geometry(frame))!
	if patches := raw.patches {
		restored = apply_frame_patches(restored, patches, patch_refs)!
	}
	if cache := raw.spline_cache {
		restored = draw_frame_splines(restored, cache)!
	}
	upsampled := upsample_frame_planes(restored, frame, transform)!
	return apply_frame_noise(upsampled, raw.noise, frame, raw.color_correlation)
}

// Noise follows image upsampling. The single visible still frame uses the
// source's (visible index 1, non-visible index 0) seeds. Modular frames pass
// the default color correlation, as the source does.
fn apply_frame_noise(input [3]FloatPlane, params ?NoiseParams, frame FrameHeader, correlation ColorCorrelationParams) ![3]FloatPlane {
	noise := params or { return input }
	if noise.lut == [8]f32{} { return input }
	size := frame.size_upsampled()
	random := generate_noise_fields(int(size.width), int(size.height), 1, 0)!
	mut convolved := [3]FloatPlane{}
	for c in 0 .. 3 { convolved[c] = convolve_noise_plane(random[c])! }
	// Fix the verified reference profile across hosts. The explicit full
	// precision color-stage API remains available for other source profiles.
	return add_noise_planes(input, convolved, noise, correlation, .bfloat16)
}
