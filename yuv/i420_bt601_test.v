module yuv

// Reference bytes from libyuv's I420ToABGR/I420AlphaToABGR (vcpkg libyuv);
// the V conversion was also compared exhaustively against that library.
fn test_i420_bt601_matches_libyuv_abgr_bytes() {
	y := [u8(16), 100, 200, 235]
	u := [u8(90)]
	v := [u8(240)]
	mut output := []u8{len: 16}
	assert i420_bt601_to_rgba(y.data, 2, u.data, 1, v.data, 1, unsafe { nil }, 0, output.data,
		8, 2, 2)
	assert output == [u8(178), 0, 0, 255, 255, 22, 22, 255, 255, 138, 138, 255, 255, 179, 179, 255]
	alpha := [u8(0), 64, 128, 255]
	mut with_alpha := []u8{len: 16}
	assert i420_bt601_to_rgba(y.data, 2, u.data, 1, v.data, 1, alpha.data, 2, with_alpha.data,
		8, 2, 2)
	for index in 0 .. 4 {
		assert with_alpha[index * 4..index * 4 + 3] == output[index * 4..index * 4 + 3]
		assert with_alpha[index * 4 + 3] == alpha[index]
	}
}

fn test_i420_bt601_shares_chroma_across_odd_edges() {
	y := []u8{len: 9, init: 128}
	u := [u8(60), 200, 100, 30]
	v := []u8{len: 4, init: 128}
	mut output := []u8{len: 3 * 3 * 4}
	assert i420_bt601_to_rgba(y.data, 3, u.data, 2, v.data, 2, unsafe { nil }, 0, output.data,
		12, 3, 3)
	pixel := fn [output] (row int, column int) []u8 {
		return output[(row * 3 + column) * 4..(row * 3 + column) * 4 + 4]
	}
	// Columns 0-1 and rows 0-1 share a chroma sample; the odd last column and
	// row use the next one.
	assert pixel(0, 0) == pixel(0, 1) && pixel(0, 0) == pixel(1, 1)
	assert pixel(0, 2) != pixel(0, 1) && pixel(0, 2) == pixel(1, 2)
	assert pixel(2, 0) != pixel(1, 0) && pixel(2, 2) != pixel(2, 0)
	assert !i420_bt601_to_rgba(y.data, 3, u.data, 2, v.data, 2, unsafe { nil }, 0, output.data,
		11, 3, 3)
}
