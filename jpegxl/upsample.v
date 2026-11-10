// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

fn upsample_kernels(factor int, weights []f32) ![][25]f32 {
	if factor !in [2,4,8] { return error('Invalid JPEG XL upsampling factor') }
	n := factor / 2
	count := 5*n * (5*n+1) / 2
	if weights.len != count { return error('Invalid JPEG XL upsampling weight count') }
	for weight in weights {
		if !math.is_finite(weight) { return error('Invalid JPEG XL upsampling weight') }
	}
	mut kernels := [][25]f32{len: factor*factor}
	for i in 0 .. 5*n {
		for j in 0 .. 5*n {
			y := math.min(i,j)
			x := math.max(i,j)
			weight := weights[5*n*y - y*(y-1)/2 + x-y]
			oy := j/5
			ox := i/5
			ky := j%5
			kx := i%5
			kernels[oy*factor+ox][ky*5+kx] = weight
			kernels[(factor-1-oy)*factor+ox][(4-ky)*5+kx] = weight
			kernels[oy*factor+factor-1-ox][ky*5+4-kx] = weight
			kernels[(factor-1-oy)*factor+factor-1-ox][(4-ky)*5+4-kx] = weight
		}
	}
	return kernels
}

// Expand each sample through the source's symmetric 5x5 polyphase kernels.
// The final row/column may be cropped when the encoded dimensions were rounded
// up. Mirrored source borders and neighborhood min/max clamping are retained.
@[direct_array_access]
pub fn upsample_plane(input FloatPlane, factor int, weights []f32, width int, height int) !FloatPlane {
	input.validate()!
	kernels := upsample_kernels(factor, weights)!
	if width <= 0 || height <= 0 || width > 1048576 || height > 1048576
		|| input.width != (width+factor-1)/factor || input.height != (height+factor-1)/factor
		|| u64(width)*u64(height) > 67108864 {
		return error('Invalid JPEG XL upsampled plane geometry')
	}
	mut samples := []f32{len: width*height}
	for y in 0 .. input.height {
		for x in 0 .. input.width {
			mut values := [25]f32{}
			for dy in 0 .. 5 {
				for dx in 0 .. 5 { values[dy*5+dx] = input.reflected(x+dx-2,y+dy-2) }
			}
			mut minimum := values[0]
			mut maximum := values[0]
			for value in values {
				minimum = math.min(minimum,value)
				maximum = math.max(maximum,value)
			}
			for oy in 0 .. factor {
				py := y*factor+oy
				if py >= height { continue }
				for ox in 0 .. factor {
					px := x*factor+ox
					if px >= width { continue }
					kernel := kernels[oy*factor+ox]
					mut accumulators := [values[0]*kernel[0],values[1]*kernel[1],values[2]*kernel[2]]!
					for i in 3 .. 25 { accumulators[i%3] = fused_f32(values[i],kernel[i],accumulators[i%3]) }
					partial := accumulators[0]+accumulators[1]
					value := partial+accumulators[2]
					samples[py*width+px] = math.min(math.max(value,minimum),maximum)
				}
			}
		}
	}
	return FloatPlane{ width: width, height: height, samples: samples }
}
