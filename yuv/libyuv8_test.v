module yuv

// Reference bytes from libyuv's I420/I422ToARGBMatrixFilter (kFilterBilinear)
// and I400ToARGBMatrix with the Yvu constants libavif selects for RGBA output.
const libyuv_test_y = [u8(16), 60, 120, 235, 30, 90, 150, 200, 40, 80, 160, 220]
const libyuv_test_u = [u8(40), 200, 90, 160, 30, 220]
const libyuv_test_v = [u8(220), 30, 128, 60, 250, 10]

fn libyuv_test_convert(layout LibyuvLayout, matrix LibyuvMatrix, height int) []u8 {
	mut out := []u8{len: 16 * height}
	assert libyuv_to_rgba(libyuv_test_y.data, 4, libyuv_test_u.data, 2, libyuv_test_v.data, 2,
		out.data, 16, 4, height, layout, matrix, true)
	return out
}

fn test_libyuv_420_bilinear_full_range_bt709() {
	assert libyuv_test_convert(.yuv420, .bt709_full, 3) == [u8(161), 0, 0, 255, 131, 48, 0, 255,
		41, 137, 179, 255, 80, 255, 255, 255, 139, 12, 0, 255, 136, 84, 14, 255, 70, 169, 202,
		255, 58, 231, 255, 255, 76, 39, 0, 255, 77, 86, 30, 255, 80, 180, 195, 255, 102, 247, 255,
		255]
}

fn test_libyuv_422_linear_full_range_bt601() {
	assert libyuv_test_convert(.yuv422, .bt601_full, 3) == [u8(145), 0, 0, 255, 123, 44, 0, 255,
		50, 145, 176, 255, 97, 255, 255, 255, 30, 43, 0, 255, 66, 109, 55, 255, 78, 181, 176, 255,
		104, 238, 255, 255, 212, 0, 0, 255, 167, 53, 0, 255, 78, 186, 239, 255, 54, 255, 255, 255]
}

fn test_libyuv_400_limited_range() {
	assert libyuv_test_convert(.yuv400, .bt601_limited, 1) == [u8(0), 0, 0, 255, 51, 51, 51, 255,
		121, 121, 121, 255, 255, 255, 255, 255]
}

fn test_libyuv_rejects_missing_chroma() {
	mut out := []u8{len: 16}
	assert !libyuv_to_rgba(libyuv_test_y.data, 4, unsafe { nil }, 2, unsafe { nil }, 2, out.data,
		16, 4, 1, .yuv420, .bt601_limited, true)
}
