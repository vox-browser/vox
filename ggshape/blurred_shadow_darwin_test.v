// vtest build: macos
module ggshape

import crypto.sha256

fn test_blurred_capsule_shadows_match_the_previous_gpu_pipeline() {
	// Pre-migration Graphite oracle, SHA-256
	// 59b9b9a5d65da5d69b196474afc5eb48c9e71e21f3fddfc04b986aa9d2a47c54.
	hashes := [
		'a84410f4134f37f6c763830247cc0bf1bea7baba7b97345b17c15c5ba39e9406',
		'210d17ba552cc757df36f7f01865cedeb778548f1af01d17865cb8ad8bb00105',
		'f556959e892337a6596b8a76cdb1d6a3a938983375ce06bdee71e5afea6bfa7e',
		'dbfc17a2b4bd114d485de32e6f6abfe27fb2c3bd756a8c3e4c2d3ea69cabf2ed',
		'e0926ff1881d238ce5377a269fd2ae84c42a0be41b3a3c81488d606dde2877fb',
		'a4f1ed3a55b4f5d504e7580d95269b3506d6cc5d194f521ed823f83df49d5390',
		'c5c6d7c8f6566c5b27b4304ddf175de05bdfb69582acde8c8e7651daca67986f',
		'8be7292cf5cd382fb3a4bb6d429838b681c2737faf19becbf52e13bd6930d157',
		'c954d16902cac5fd6c99d74d1b5fa5d536932af8b219e5bf044c35cd1f6d6278',
		'b895bb5aeb09f03f6b3d61665633ee04b3abd80059e124b967d96a549e6d753b',
	]
	mut index := 0
	for blur in [f32(2), 4, 8, 16, 160] {
		large := blur == 160
		width := if large { 2048 } else { 48 }
		height := if large { 1536 } else { 32 }
		for background in [i32(0), 1] {
			shape := C.VoxGraphiteShape{
				matrix:          [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
				rect:            if large {
					[f32(528), 700, 1512, 136, 68, 68, 68, 68, 68, 68, 68, 68]!
				} else {
					[f32(2.25), 3.5, 42.5, 24, 12, 12, 12, 12, 12, 12, 12, 12]!
				}
				underlay_rect:   if large {
					[f32(545), 709, 1478, 102, 51, 51, 51, 51, 51, 51, 51, 51]!
				} else {
					[f32(4.75), 5.25, 37, 19, 9.5, 9.5, 9.5, 9.5, 9.5, 9.5, 9.5, 9.5]!
				}
				fill:            10
				thickness:       blur
				anti_alias:      1
				has_float_color: 1
				float_color:     if large {
					[f32(0), 0, 0, f32(6) / 255]!
				} else {
					[f32(0.15), 0.4, 0.7, f32(10) / 255]!
				}
			}
			mut pixels := []u8{len: width * height * 4, init: u8(252)}
			for i in 0 .. width * height { pixels[i * 4 + 3] = 255 }
			assert draw(pixels.data, i32(width), i32(height), i32(width * 4), background, &shape) == 1
			assert sha256.sum(pixels).hex() == hashes[index], 'blur=${blur} background=${background}'
			index++
		}
	}
}

fn test_unsupported_blurred_shadow_declines_without_modifying_the_target() {
	for matrix in [[f32(1), 0.2, 0, 0, 1, 0, 0, 0, 1]!, [f32(-1), 0, 48, 0, 1, 0, 0, 0, 1]!] {
		shape := C.VoxGraphiteShape{
			matrix:    matrix
			rect:      [f32(2), 3, 42, 24, 12, 12, 12, 12, 12, 12, 12, 12]!
			fill:      10
			thickness: 16
		}
		mut pixels := []u8{len: 48 * 32 * 4, init: u8(0xa5)}
		assert draw(pixels.data, 48, 32, 48 * 4, 1, &shape) == 0
		assert pixels.all(it == 0xa5)
	}
}
