// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// The visible owner currently accepts one final image. Its source frame
// counters are therefore (1,0), after any non-visible LF dependencies.
fn generate_noise_fields(width int, height int, visible u32, nonvisible u32) ![3]FloatPlane {
	if width <= 0 || height <= 0 { return error('JPEG XL random fields require positive dimensions') }
	count := modular_sample_count(width, height)!
	if u64(count) * 3 > 67108864 { return error('JPEG XL random fields exceed the sample budget') }
	mut samples := [3][]f32{}
	for c in 0 .. 3 { samples[c] = []f32{len: count} }
	for y0 := 0; y0 < height; y0 += 256 {
		for x0 := 0; x0 < width; x0 += 256 {
			w := if width - x0 < 256 { width - x0 } else { 256 }
			h := if height - y0 < 256 { height - y0 } else { 256 }
			mut rng := new_noise_rng(visible, nonvisible, u32(x0), u32(y0))
			// One RNG is shared by the three channels within each subregion.
			// Partial rows still consume a full batch before the next row.
			for c in 0 .. 3 {
				for y in 0 .. h {
					for x := 0; x < w; x += 16 {
						bits := rng.next_block()
						n := if w - x < 16 { w - x } else { 16 }
						for i in 0 .. n {
							shift := if i % 2 == 0 { 16 } else { 48 }
							samples[c][(y0 + y) * width + x0 + x + i] = f32(u16(bits[i / 2] >> shift))
						}
					}
				}
			}
		}
	}
	mut output := [3]FloatPlane{}
	for c in 0 .. 3 { output[c] = FloatPlane{ width: width, height: height, samples: samples[c] } }
	return output
}

fn convolve_noise_plane(input FloatPlane) !FloatPlane {
	input.validate()!
	mut samples := []f32{len: input.samples.len}
	for y in 0 .. input.height {
		for x in 0 .. input.width {
			mut sum := u32(0)
			for dy in -2 .. 3 { for dx in -2 .. 3 { sum += u32(input.reflected(x + dx, y + dy)) } }
			center := input.samples[y * input.width + x] * (f32(-4) / f32(65536))
			samples[y * input.width + x] = fused_f32(f32(sum), f32(0.16) / f32(65536), center)
		}
	}
	return FloatPlane{ width: input.width, height: input.height, samples: samples }
}
