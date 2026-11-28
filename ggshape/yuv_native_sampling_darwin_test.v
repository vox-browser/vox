// vtest build: macos
module ggshape

import crypto.sha256
import imageraster
import platform
import yuv

// Independent Skia Graphite/Metal R8 planes, GPU-generated mips, Rec601 limited
// conversion, linear mip sampling and a white 260x260 BGRA8 sRGB target.
// These are component oracles, not Brave screenshot or live-site acceptance.
// See docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md, Native YUV sampler isolation.
fn test_yuv_atlas_matches_native_plane_sampling_at_three_scales() {
	for mode, expected in [
		'd50519910df29bf37433495d28bb7a27523c427e12ad93f4f88f5e03432c4d96',
		'2cf75361e0ee678136744ed3c5843c96fee6a53a200c274b9874eac1ca525dbc',
		'5faaf7651b0b8b5d448b29ef1eacd039e61bde60e694017c0d2bfb050285a6b4',
	] {
		mut scratch := platform.begin_thread_scratch('Native YUV sampling oracle')
		width, height := if mode == 0 {
			256, 144
		} else if mode == 1 {
			320, 180
		} else {
			640, 360
		}
		dw, dh := if mode == 0 {
			130, 73
		} else if mode == 1 {
			245, 138
		} else {
			200, 113
		}
		nw, nh := if mode == 2 { 1280, 720 } else { width, height }
		luma_size := width * height
		cw, ch := width / 2, height / 2
		mut planes := []u8{len: luma_size * 3 / 2}
		for y in 0 .. height {
			for x in 0 .. width {
				planes[y * width + x] = u8((x * 17 + y * 29 + x * y * 7) & 255)
			}
		}
		for y in 0 .. ch {
			for x in 0 .. cw {
				planes[luma_size + y * cw + x] = u8((x * 31 + y * 11 + x * y * 3) & 255)
				planes[luma_size + cw * ch + y * cw + x] = u8((128 + x * 13 + y * 23) & 255)
			}
		}
		atlas := yuv.webp_420_atlas_upload(planes, width, height) or { panic('native atlas') }
		mut pixels := []u8{len: 260 * 260 * 4, init: 255}
		assert draw_sampled_yuv_atlas_clipped(pixels.data, 260, 260, 1040, 1,
			atlas, width, height, 2, 2, f32(dw), f32(dh), 1, nw, nh, [12]f32{}) == 1
		assert sha256.sum(pixels).hex() == expected, 'native plane sampling mode ${mode}'
		scratch.finish()
	}
}

struct NativeYuvMipReference {
	width    int
	height   int
	level    int
	channels [3]string
}

// Native R8 GPU texture readbacks exercise odd dimensions and halfway byte
// averages. Compare each packed channel separately, including every mip texel.
fn test_yuv_gpu_byte_mips_match_independent_native_r8_textures() {
	for reference in native_yuv_mip_references() {
		mut scratch := platform.begin_thread_scratch('Native R8 mip oracle')
		mut pixels := []u8{len: reference.width * reference.height * 4, init: 255}
		for y in 0 .. reference.height {
			for x in 0 .. reference.width {
				for c in 0 .. 3 {
					pixels[(y * reference.width + x) * 4 + c] = u8((x * 17 + y * 29 +
						x * y * (6 + c) + 13 + c * 41) & 255)
				}
			}
		}
		levels := gpu_image_mip_chain(imageraster.Image{
			width:  reference.width
			height: reference.height
			pixels: pixels
		}) or { panic('native mip chain') }
		level := levels[reference.level]
		for c, expected in reference.channels {
			mut channel := []u8{len: level.width * level.height}
			for i in 0 .. channel.len { channel[i] = level.pixels[i * 4 + c] }
			assert sha256.sum(channel).hex() == expected, 'native R8 ${reference.width}x${reference.height} mip ${reference.level}, channel ${c}'
		}
		scratch.finish()
	}
}

fn native_yuv_mip_references() []NativeYuvMipReference {
	return [
		NativeYuvMipReference{13, 9, 1, [
			'038e3567995dce7f8c10d7b8ec549c17163b2c0ac7912bf39a7d397714c41c01',
			'10d01fbd47b965a12690c0063e817592649c66d077b0cb5c978f0bb04b656a2c',
			'6792b89eb06fc4cc6776dc91175592d7f8e9dd716cd291bb2382e59455d07444',
		]!},
		NativeYuvMipReference{13, 9, 2, [
			'e1985edcaf9d91bc0cf5df97e988de772f4ba61f5d46d2d32725d6121be176de',
			'80422f1d02955ca5cf0e8350d1be312db3db5db005312f576f08c2f4ffb2c7e7',
			'8f10952bdfe54f8355b5d3b8c0cf8f7998e348b0c25e03b6110adbac0285a5a9',
		]!},
		NativeYuvMipReference{256, 144, 2, [
			'6585571be07d844bc7d7f04f9b4234c2fd3ffeb0f78f7d3f45551a5788e2ed46',
			'94da58759eb0ee43c66684fbe6f131e5c1c04371c52342a4be91a33a3f57f888',
			'f33179f8ee7893be947caae734f9da8a21caf55cf5025f82ab024cc0b54f59c1',
		]!},
		NativeYuvMipReference{256, 144, 3, [
			'2884759d1942fcb0d1d33300725368676d6b49f8d2a92f8aac393f28f807f33e',
			'9fd3a2788dcbc36d88dd3ce5cdb7469a7261a96e9bba075796d342e14e425647',
			'6cef009db7d525cac8f36d6116537d9618e0dbf563e4027771c9bf51a5ee8663',
		]!},
	]
}
