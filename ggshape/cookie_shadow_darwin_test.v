// vtest build: macos
module ggshape

import crypto.sha256

fn test_rounded_shadow_nine_patch_matches_the_previous_gpu_pipeline() {
	// Independent pre-migration Graphite library:
	// 59b9b9a5d65da5d69b196474afc5eb48c9e71e21f3fddfc04b986aa9d2a47c54.
	hashes := [
		'b54c1196673a8b86d79b47bc5dab650ca644d7f0d07e1c6e85ebe5abf3b6cfe0',
		'f6e716dd97e88779be4d6eb1cc66504753c00ffac9ad91470803540bbd9dc648',
		'13a6516d88825f85791dadd126a965f09bf8641e4427f3faf1902c2eb21b4fce',
		'24bb43ea963480d11d01bc0d5193b8a8e0062cf710edc5dd63acfab37013ea32',
		'ab5821286088c31be41283754b58dfafdb858bc53da34e3e61a169e8742f5786',
		'8afa13b0587ba09ccce58f1544c7ac81b3ab5c21ddb9804756a9840c2f07cc37',
	]
	mut index := 0
	for blur in [f32(8), 16, 24] {
		for background in [i32(0), 1] {
			shape := C.VoxGraphiteShape{ matrix: [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!, rect: [
				f32(52),
				53,
				1480,
				252,
				60,
				60,
				60,
				60,
				60,
				60,
				60,
				60,
			]!, underlay_rect: [f32(53), 46, 1478, 250, 59, 59, 59, 59, 59, 59, 59, 59]!, fill: 10, thickness: blur, anti_alias: 1, has_float_color: 1, float_color: [
				f32(0),
				0,
				0,
				f32(13) / 255,
			]! }
			mut pixels := []u8{len: 1600 * 400 * 4, init: u8(252)}
			for i in 0 .. 1600 * 400 { pixels[i * 4 + 3] = 255 }
			assert draw(pixels.data, 1600, 400, 1600 * 4, background, &shape) == 1
			assert sha256.sum(pixels).hex() == hashes[index], 'blur=${blur} background=${background}'
			index++
		}
	}
}
