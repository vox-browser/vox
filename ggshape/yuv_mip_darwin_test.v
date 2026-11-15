// vtest build: macos
module ggshape

fn test_yuv_mip_reduces_byte_planes_before_color_conversion() {
	// The average Y=80.75 rounds to 81 in the hardware mip. The canvas
	// sampler blends that level before limited-range conversion, producing
	// 76 instead of the direct sample's 75.
	source := [u8(33), 128, 128, 255, 64, 128, 128, 255, 96, 128, 128, 255, 130, 128, 128, 255]
	for samples in [1, 4] {
		mut direct := []u8{len: 8 * 8 * 4, init: 255}
		mut mip := direct.clone()
		assert draw_sampled_yuv_clipped(direct.data, 8, 8, 32, 1, source, 2, 2,
			2, 2, 1, 1, samples, 2, 2, [12]f32{}) == 1
		assert draw_sampled_yuv_with_mips_clipped(mip.data, 8, 8, 32, 1, source, 2, 2,
			2, 2, 1, 1, samples, 2, 2, [12]f32{}, true) == 1
		i := (2 * 8 + 2) * 4
		assert direct[i..i + 4] == [u8(75), 75, 75, 255]
		assert mip[i..i + 4] == [u8(76), 76, 76, 255]
		// Three out-of-gamut blue samples and one saturated blue sample:
		// converting to RGB before reduction would average their clipped blue
		// bytes to 64. Retaining U through the mip gives blue 1 instead.
		clipped := [u8(128), 0, 128, 255, 128, 0, 128, 255, 128, 0, 128, 255, 128, 255, 128, 255]
		assert draw_sampled_yuv_with_mips_clipped(mip.data, 8, 8, 32, 1, clipped, 2, 2,
			2, 2, 1, 1, samples, 2, 2, [12]f32{}, true) == 1
		assert mip[i..i + 4] == [u8(1), 156, 130, 255]
		for p in 0 .. 8 * 8 {
			if p != 18 {
				assert mip[p * 4..p * 4 + 4] == [u8(255), 255, 255, 255]
			}
		}
	}
}
