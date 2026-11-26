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
	assert output == [u8(178), 0, 0, 255, 255, 22, 22, 255, 255, 138, 138, 255, 255, 179, 179,
		255]
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

fn test_i420_bt601_row_ranges_preserve_padded_and_reversed_planes() {
	width, height := 1031, 513
	chroma_width, chroma_height := (width + 1) / 2, (height + 1) / 2
	y_stride, u_stride, v_stride, a_stride := width + 7, chroma_width + 3, chroma_width + 5, width + 9
	stride := width * 4 + 15
	y := []u8{len: y_stride * height, init: u8(index * 17 + index / y_stride)}
	u := []u8{len: u_stride * chroma_height, init: u8(index * 29 + index / u_stride)}
	v := []u8{len: v_stride * chroma_height, init: u8(index * 53 + index / v_stride)}
	a := []u8{len: a_stride * height, init: u8(index * 61 + index / a_stride)}
	actual := []u8{len: stride * height, init: 0x5a}
	expected := []u8{len: stride * height, init: 0x5a}
	unsafe {
		y_first := &u8(y.data) + (height - 1) * y_stride
		v_first := &u8(v.data) + (chroma_height - 1) * v_stride
		assert i420_bt601_to_rgba(y_first, -y_stride, u.data, u_stride, v_first, -v_stride,
			a.data, a_stride, actual.data, stride, width, height)
		for row in 0 .. height {
			assert i420_bt601_to_rgba(y_first - row * y_stride, -y_stride, &u8(u.data) +
				(row / 2) * u_stride, u_stride, v_first - (row / 2) * v_stride, -v_stride,
				&u8(a.data) + row * a_stride, a_stride, &u8(expected.data) + row * stride,
				stride, width, 1)
		}
	}
	matches := actual == expected
	assert matches
}

fn test_i420_bt601_preserves_write_order_when_output_overlaps_input() {
	width, height := 1027, 513
	chroma_width, chroma_height := (width + 1) / 2, (height + 1) / 2
	stride := width * 4
	u := []u8{len: chroma_width * chroma_height, init: u8(index * 21)}
	v := []u8{len: chroma_width * chroma_height, init: u8(index * 13)}
	actual := []u8{len: stride * height, init: u8(index * 7)}
	expected := actual.clone()
	unsafe {
		assert i420_bt601_to_rgba(actual.data, width, u.data, chroma_width, v.data, chroma_width,
			nil, 0, actual.data, stride, width, height)
		for row in 0 .. height {
			chroma_offset := (row / 2) * chroma_width
			assert i420_bt601_to_rgba(&u8(expected.data) + row * width, width, &u8(u.data) +
				chroma_offset, chroma_width, &u8(v.data) + chroma_offset, chroma_width,
				nil, 0, &u8(expected.data) + row * stride, stride, width, 1)
		}
	}
	matches := actual == expected
	assert matches
}
