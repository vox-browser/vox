// vtest build: macos
module ggshape

import crypto.sha256

fn non_scaling_test_pixels() []u8 {
	// Three padding pixels on each row must survive either backend.
	mut pixels := []u8{len: (48 + 3) * 32 * 4, init: 0xa5}
	for y in 0 .. 32 {
		for x in 0 .. 48 {
			i := (y * 51 + x) * 4
			pixels[i] = u8(x * 3)
			pixels[i + 1] = u8(y * 4)
			pixels[i + 2] = 80
			pixels[i + 3] = 200
		}
	}
	return pixels
}

// Both standalone and embedded SVG draws must match the original backend,
// including the effect of parent * matrix * inverse(matrix) rounding.
fn test_non_scaling_strokes_match_graphite_with_clips_and_svg_parents() {
	// Pinned against the pre-migration Graphite oracle on 2026-11-12.
	// Checking these pixels requires no Skia library at runtime.
	expected_hashes := [
		'898881e8547a5fb51da781f5856af6ecb6c0678c5e8fdcfd2efb0b02e670182a',
		'2514fd59078ef1324711678d250a7783b4ee9b80cf4142ad05c24f1ac7205ff0',
		'21d3d929a3fa7e428dcc2e50485a5c01d8753d6e999246215ea2174d62ce49ca',
		'45913b17122f079a7b91877d19e104d3350a1c0ae78296c30ebc8685833fb711',
		'cdf88d323693bfcc8ac5191651daad7595f891bdfe9e71793c615d530ef47fc8',
		'33ccff85abb65ad1a6e0e84c38e32dd17a4f5a40f66b6cef966985d81d5e8810',
		'894d60590abcb3db6b2d2c3793938b9195ebd4a40dee1d684934d82ec3d49efb',
		'a0e9c13f885d1207caaa4fab6ea9221ee14a76bb0c4dc8f1e0582a95815560f8',
		'a0e9c13f885d1207caaa4fab6ea9221ee14a76bb0c4dc8f1e0582a95815560f8',
		'66a13b39edb154f482a1cee59d881ee63d2945498404b2fdac0d99b0dc82f654',
		'50449e756c6d9a93fbbca8c87d56e2a53c52aaa908fa4b34b3a67b3a63ec682f',
		'788b648533c0d385128a18209da33d98eebceb77e3cfce28bb019faaebdcdd0b',
		'aacfa1bf87040dc0516a304634ab49d178bfe0dcca55e1be46c602c1e2b7b1c6',
		'6cb5725e59946b7eb098065dbe0ba913857122a471815bdfd065ece3f0528e6a',
		'6cb5725e59946b7eb098065dbe0ba913857122a471815bdfd065ece3f0528e6a',
		'898bd1cfccf4219e9ed06b4b40c56d13d4d313c52030206a1f9d0eb254c801f9',
		'5e847bc85e69161fef39984327ba021ea2ae589b30741938567460e49b6770c8',
		'92a55d431996a54408189f6efd536f30d63f9daae71906b31c96998d1a95bb01',
		'c70b3c1187d7f14244590103cbaf5b551fba73f4e2d8e667783c51aae9ba0245',
		'fe172419be2c024a18f7c700f4407dd6700c0ccc9738253b3c65b2a2e65b14ce',
		'fe172419be2c024a18f7c700f4407dd6700c0ccc9738253b3c65b2a2e65b14ce',
		'7e1159f3f8c8d807091639ea0760799da44fcbe17348bb68c388b9a27130c2d1',
		'bdfb22288fe73fcc3c8f3bd8de96aba2ed77e91139cc0164b93ff27b64dba217',
		'f507a5ce69fd7c1ee6886e7f697960d3c7273bdebe9693908752806eeccc6280',
		'b4b299cd7da69ada03d3a196bd4055f60d414a91fc62364d286eb64c341ba2fd',
		'6993b79a5a598e929de89d081623cebef9a2134f2d1bd67fd0aadd0a72401db7',
		'6993b79a5a598e929de89d081623cebef9a2134f2d1bd67fd0aadd0a72401db7',
		'5bd717d60dc09a4e8ed0660f770eeb1924727c81705eeddd16b4d0bddf0562f2',
		'e37f22151c4360763b185190210cf8b3d900cbfc40ab1bb53f94bfe7d5674967',
		'3fc762feb2c03bf2bf7361996ea832db8d2bb0dde0a27f9aaabc4d58bd661f78',
		'90eb73f956366ee4fe9dcdf8e5bad122d4ac28f7ca1416dde867568ef3bace38',
		'c99f123070c1a6cd631325269de2ae970e98d14f6eedb2b0a43ac2b3943dcf97',
		'c99f123070c1a6cd631325269de2ae970e98d14f6eedb2b0a43ac2b3943dcf97',
		'7b4f1b5e8ab3faada751b68ec5e6ba2bc7539eb3125888d41628730052232deb',
		'7722f3bb518d8e54eef62bd9d3727b5c620bf79e75baea6a442787c4bf245137',
		'084bb1eb1238c8e87ef931843c9c9492d5ff363daa93b3bf9dc852cfe61de60a',
		'01c2b1e944c648c41460684c6541c2e34bdc2fc327394d809aebd140fd5d0762',
		'01c2b1e944c648c41460684c6541c2e34bdc2fc327394d809aebd140fd5d0762',
		'01c2b1e944c648c41460684c6541c2e34bdc2fc327394d809aebd140fd5d0762',
		'0c7b42929a2971f9aaf8c387ba8b3b9a9725fb3c4d4b37b86379312fa65dc2a5',
		'0c7b42929a2971f9aaf8c387ba8b3b9a9725fb3c4d4b37b86379312fa65dc2a5',
		'0c7b42929a2971f9aaf8c387ba8b3b9a9725fb3c4d4b37b86379312fa65dc2a5',
	]
	mut receipt := 0

	mut segments := [f32(0), 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 12, 4, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 3, 24, 18, 15, 0, 22, 26, 0, 0, 0, 0, 0]
	matrices := [
		[f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!,
		[f32(3), 0, 1.5, 0, 2, 0.25, 0, 0, 1]!,
		[f32(-1.25), 0, 35, 0, 0.75, 0.5, 0, 0, 1]!,
		[f32(0), -1.25, 35, 0.75, 0, 0.5, 0, 0, 1]!,
		[f32(0.8660254), -0.5, 20, 0.5, 0.8660254, -6, 0, 0, 1]!,
		[f32(1), 0.3, 0, 0.1, 1, 0, 0, 0, 1]!,
		[f32(0), 0, 15, 0, 1, 2, 0, 0, 1]!,
	]
	parent := [f32(1.125), 0.2, 0.375, -0.125, 0.875, 1.25, 0, 0, 1]!
	viewport := [f32(0), 0, 42, 30]!
	rounded := [f32(1), 1, 44, 28, 3, 3, 3, 3, 3, 3, 3, 3]!
	for matrix in matrices {
		for background in [i32(0), 1] {
			mut path := C.VoxGraphitePath{
				matrix:             matrix
				segments:           segments.data
				segment_count:      3
				red:                35
				green:              167
				blue:               79
				alpha:              200
				stroke:             1
				non_scaling_stroke: 1
				stroke_width:       2.5
				line_join:          1
				line_cap:           2
				miter_limit:        4
				has_clip:           1
				clip:               [f32(1), 1, 28, 26, 4, 4, 4, 4, 4, 4, 4, 4]!
			}
			mut actual := non_scaling_test_pixels()
			assert draw_path(actual.data, 48, 32, 51 * 4, background, &path) == 1, 'matrix=${matrix} background=${background}'
			assert sha256.sum(actual).hex() == expected_hashes[receipt]
			receipt++
			for layer in [false, true] {
				clip := if layer { unsafe { &rounded[0] } } else { unsafe { &f32(nil) } }
				actual = non_scaling_test_pixels()
				assert draw_svg_image(actual.data, 48, 32, 51 * 4, background, &path, 1, &parent[0], &viewport[0], clip) == 1, 'matrix=${matrix} background=${background} layer=${layer}'
				assert sha256.sum(actual).hex() == expected_hashes[receipt]
				receipt++
			}
		}
	}
	assert receipt == expected_hashes.len
}

fn test_non_scaling_svg_decline_preserves_the_whole_target() {
	mut segments := [f32(0), 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 12, 4, 0, 0, 0, 0, 0, 0, 0, 0,
		0]
	mut paths := [C.VoxGraphitePath{
		matrix:             [f32(2), 0, 1, 0, 2, 1, 0, 0, 1]!
		segments:           segments.data
		segment_count:      2
		red:                255
		alpha:              255
		stroke:             1
		non_scaling_stroke: 1
		stroke_width:       2
	}, C.VoxGraphitePath{
		matrix:             [f32(2), 0, 1, 0, 2, 1, 0.01, 0, 1]!
		segments:           segments.data
		segment_count:      2
		red:                255
		alpha:              255
		stroke:             1
		non_scaling_stroke: 1
		stroke_width:       2
	}]
	parent := [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
	viewport := [f32(0), 0, 48, 32]!
	mut pixels := non_scaling_test_pixels()
	assert draw_svg_image(pixels.data, 48, 32, 51 * 4, 1, paths.data, 2, &parent[0], &viewport[0], unsafe { nil }) == 0
	assert pixels == non_scaling_test_pixels()
}
