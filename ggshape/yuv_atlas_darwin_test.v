// vtest build: macos
module ggshape

import platform
import yuv

fn test_near_half_yuv_atlas_filters_chroma_at_its_own_resolution() {
	for samples in [1, 4] {
		mut scratch := platform.begin_thread_scratch('YUV atlas frame')
		mut planes := []u8{len: 24, init: 128}
		for i, value in [u8(80), 144, 80, 144] { planes[16 + i] = value }
		atlas := yuv.webp_420_atlas_upload(planes, 4, 4) or { panic('atlas') }
		mut pixels := []u8{len: 8 * 8 * 4, init: 255}
		assert draw_sampled_yuv_atlas_clipped(pixels.data, 8, 8, 32, 1, atlas, 4, 4,
			2, 2, 3, 3, samples, 4, 4, [12]f32{}) == 1
		// No chroma mip is selected. Its clamped endpoint texels and exact
		// midpoint retain their own sampling grid rather than luma's grid.
		for col, expected in [[u8(34), 149, 130, 255], [u8(98), 137, 130, 255],
			[u8(163), 124, 130, 255]] {
			i := (3 * 8 + col + 2) * 4
			assert pixels[i..i + 4] == expected, 'samples=${samples}, column=${col}'
		}
		for i, value in [u8(0), 255, 0, 255] { planes[16 + i] = value }
		for i, value in [u8(0), 255, 0, 255] { planes[20 + i] = value }
		clipped := yuv.webp_420_atlas_upload(planes, 4, 4) or { panic('clipped atlas') }
		assert draw_sampled_yuv_atlas_clipped(pixels.data, 8, 8, 32, 1, clipped, 4, 4,
			2, 2, 3, 3, samples, 4, 4, [12]f32{}) == 1
		assert pixels[(3 * 8 + 3) * 4..(3 * 8 + 3) * 4 + 4] == [u8(129), 131, 130, 255]
		// Even luma dimensions can have odd chroma dimensions. Near-half
		// sampling must retain the unrounded 3x3 plane and its edge texels.
		mut odd_chroma := []u8{len: 54, init: 128}
		for py in 0 .. 3 {
			for px in 0 .. 3 { odd_chroma[36 + py * 3 + px] = u8(80 + px * 32) }
		}
		odd_atlas := yuv.webp_420_atlas_upload(odd_chroma, 6, 6) or { panic('odd chroma atlas') }
		assert draw_sampled_yuv_atlas_clipped(pixels.data, 8, 8, 32, 1, odd_atlas, 6, 6,
			2, 2, 4, 4, samples, 6, 6, [12]f32{}) == 1
		for col, expected in [[u8(34), 149, 130, 255], [u8(74), 141, 130, 255], [u8(122), 132,
			130, 255], [u8(163), 124, 130, 255]] {
			i := (3 * 8 + col + 2) * 4
			assert pixels[i..i + 4] == expected, 'odd chroma, samples=${samples}, column=${col}'
		}
		assert pixels[..4] == [u8(255), 255, 255, 255]
		scratch.finish()
	}
}

fn test_yuv_atlas_rejects_unverified_scales_and_alpha_without_painting() {
	atlas := []u8{len: 64, init: 255}
	mut pixels := []u8{len: 64, init: 97}
	for size in [f32(0), 2, 4, 5] {
		assert draw_sampled_yuv_atlas_clipped(pixels.data, 4, 4, 16, 1, atlas, 4, 4,
			0, 0, size, size, 1, 4, 4, [12]f32{}) == 0
	}
	assert draw_sampled_yuv_atlas_clipped(pixels.data, 4, 4, 16, 1, atlas[..60], 4, 4,
		0, 0, 3, 3, 1, 4, 4, [12]f32{}) == 0
	assert draw_sampled_yuv_atlas_clipped(pixels.data, 4, 4, 16, 1, []u8{len: 64}, 4, 4,
		0, 0, 3, 3, 1, 4, 4, [12]f32{}) == 0
	assert pixels.all(it == 97)
}

fn test_full_plane_atlas_filters_the_first_chroma_mip_before_rgb_clipping() {
	mut planes := []u8{len: 12 * 12 * 3 / 2, init: 128}
	for py in 0 .. 6 {
		for px in 0 .. 6 {
			value := [u8(100), 250, 250, 0][(py % 2) * 2 + px % 2]
			planes[144 + py * 6 + px] = value
			planes[180 + py * 6 + px] = value
		}
	}
	atlas := yuv.webp_420_atlas_upload(planes, 12, 12) or { panic('full-plane atlas') }
	for samples in [1, 4] {
		mut pixels := []u8{len: 8 * 8 * 4, init: 255}
		assert draw_sampled_yuv_atlas_clipped(pixels.data, 8, 8, 32, 1, atlas, 12, 12, 2, 2, 4, 4, samples, 12, 12, [12]f32{}) == 1
		// At these centers the independent base sample and first mip both
		// equal 150. This isolates plane filtering from implicit LOD precision;
		// clipping RGB texels first would produce a different color.
		for col in [0, 1] {
			i := (3 * 8 + 2 + col) * 4
			assert pixels[i..i + 4] == [u8(175), 104, 166, 255], 'samples=${samples}, column=${col}'
		}
		assert pixels[..4] == [u8(255), 255, 255, 255]
	}
}

fn test_full_plane_atlas_mip_edges_match_an_independent_chroma_texture() {
	mut planes := []u8{len: 12 * 12 * 3 / 2, init: 128}
	mut chroma := []u8{cap: 6 * 6 * 4}
	for py in 0 .. 6 {
		for px in 0 .. 6 {
			u, v := u8((px * 43 + py * 17) % 256), u8((px * 19 + py * 47 + 13) % 256)
			planes[144 + py * 6 + px] = u
			planes[180 + py * 6 + px] = v
			chroma << [u8(128), u, v, u8(255)]
		}
	}
	atlas := yuv.webp_420_atlas_upload(planes, 12, 12) or { panic('edge atlas') }
	for samples in [1, 4] {
		mut actual := []u8{len: 8 * 8 * 4, init: 255}
		mut expected := actual.clone()
		assert draw_sampled_yuv_atlas_clipped(actual.data, 8, 8, 32, 1, atlas, 12, 12, 2, 2, 4, 4, samples, 12, 12, [12]f32{}) == 1
		// Constant luma lets a separate 6x6 texture supply independently filtered
		// chroma. Its physical texture edge clamps each mip at the correct texel.
		assert draw_sampled_yuv_with_mips_clipped(expected.data, 8, 8, 32, 1, chroma, 6, 6, 2, 2, 4, 4, samples, 6, 6, [12]f32{}, true) == 1
		for py in 0 .. 8 {
			for px in 0 .. 8 {
				i := (py * 8 + px) * 4
				assert actual[i..i + 4] == expected[i..i + 4], 'samples=${samples}, pixel=${px},${py}'
			}
		}
	}
}
