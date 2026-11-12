// vtest build: macos
module ggshape

import crypto.sha256

fn test_rounded_border_uses_the_original_layer_local_conic_coordinates() {
	// Independent pre-migration Graphite replay of the layer-local shape.
	hashes := ['f927c3fbc98f15cb44cc389558e68642b887d36b1019e192592ee70e2a00d5e4',
		'c1c887d6aaea45f958923dc735cbe0a87a8f345990d5fbaa2e5cad483e4219db',
		'860029b2d071b5c1be518d092adb5e6293b909571d811b6f3a602f65b768f1f2']
	mut index := 0
	for dy in [f32(-664), -1078, -204] {
		h := if dy == -204 { 1536 } else { 416 }
		shape := C.VoxGraphiteShape{ matrix: [f32(1), 0, -288, 0, 1, dy, 0, 0, 1]!, rect: [
			f32(1137),
			1041,
			294,
			86,
			43,
			43,
			43,
			43,
			43,
			43,
			43,
			43,
		]!, fill: 7, thickness: 2, alpha: 51, anti_alias: 1, force_msaa: 1, has_underlay: 1, underlay_rect: [
			f32(1136),
			1040,
			296,
			88,
			44,
			44,
			44,
			44,
			44,
			44,
			44,
			44,
		]!, underlay_rgba: [u8(255), 255, 255, 255]!, border_widths: [f32(2), 2, 2, 2]! }
		mut pixels := []u8{len: 2048 * h * 4, init: u8(252)}
		for i in 0 .. 2048 * h { pixels[i * 4 + 3] = 255 }
		local := localize_rounded_shape(shape, 288, 664)
		assert local.rect[0] == 849 && local.rect[1] == 377
		assert local.matrix[2] == 0 && local.matrix[5] == dy + 664
		assert draw(pixels.data, 2048, i32(h), 2048 * 4, 1, &local) == 1
		assert sha256.sum(pixels).hex() == hashes[index]
		index++
	}
}

fn test_local_origin_conversion_preserves_unsupported_transforms_and_clips() {
	base := C.VoxGraphiteShape{ matrix: [f32(1), 0, -288, 0, 1, -664, 0, 0, 1]!, rect: [
		f32(1137),
		1041,
		294,
		86,
		43,
		43,
		43,
		43,
		43,
		43,
		43,
		43,
	]! }
	for shape in [C.VoxGraphiteShape{ ...base, fill: 13 },
		C.VoxGraphiteShape{ ...base, clip_out_count: 1 },
		C.VoxGraphiteShape{ ...base, matrix: [f32(1), .1, -288, 0, 1, -664, 0, 0, 1]! }] {
		local := localize_rounded_shape(shape, 288, 664)
		assert local.matrix == shape.matrix && local.rect == shape.rect
	}
	local := localize_rounded_shape(base, 288.25, 664)
	assert local.matrix == base.matrix && local.rect == base.rect
}
