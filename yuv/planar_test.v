module yuv

import crypto.sha256

fn test_reference_frames_match_the_previous_rust_decoder_exactly() {
	rows := $embed_file('testdata/rust-neon-rdm.tsv').to_string().trim_space().split_into_lines()
	assert rows.len == 252
	for row in rows {
		fields := row.split('\t')
		range := unsafe { Range(fields[0].int()) }
		matrix := unsafe { Matrix(fields[1].int()) }
		sampling := unsafe { Sampling(fields[2].int()) }
		width := fields[3].int()
		sx := if sampling == .yuv444 { 0 } else { 1 }
		mut y := []u8{len: 512}
		mut u := []u8{len: 256}
		mut v := []u8{len: 256}
		for i in 0 .. y.len {
			y[i] = u8(i * 73 + int(range) * 19 + int(matrix) * 11 + int(sampling) * 7)
		}
		for i in 0 .. u.len {
			u[i] = u8(i * 37 + int(matrix) * 43)
			v[i] = u8(i * 91 + int(range) * 31 + int(sampling) * 53)
		}
		us := ((width + sx) >> sx) + 2
		image := PlanarImage{
			y:        y
			u:        u
			v:        v
			y_stride: width + 3
			u_stride: us
			v_stride: us + 1
			width:    width
			height:   3
			sampling: sampling
		}
		stride := width * 4 + 7
		mut pixels := []u8{len: stride * 3, init: 0xa5}
		image.to_rgba(mut pixels, stride, range, matrix, .neon_rdm)!
		assert sha256.hexhash(pixels.bytestr()) == fields[4], row
	}
}

fn test_scalar_neutral_luma_and_clipping() {
	image := PlanarImage{
		y:        [u8(0), 16, 235, 255]
		u:        [u8(128), 128, 128, 128]
		v:        [u8(128), 128, 128, 128]
		y_stride: 4
		u_stride: 4
		v_stride: 4
		width:    4
		height:   1
		sampling: .yuv444
	}
	for matrix in [Matrix.bt709, .fcc, .bt470bg, .bt601, .smpte240, .bt2020] {
		mut pixels := []u8{len: 16}
		image.to_rgba(mut pixels, 16, .limited, matrix, .scalar)!
		assert pixels == [u8(0), 0, 0, 255, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255]
		image.to_rgba(mut pixels, 16, .full, matrix, .scalar)!
		assert pixels == [u8(0), 0, 0, 255, 16, 16, 16, 255, 235, 235, 235, 255, 255, 255, 255,
			255]
	}
}

fn test_short_views_and_invalid_strides_leave_the_destination_untouched() {
	valid := PlanarImage{
		y:        [u8(16), 235, 81, 145]
		u:        [u8(128)]
		v:        [u8(128)]
		y_stride: 2
		u_stride: 1
		v_stride: 1
		width:    2
		height:   2
	}
	for image in [PlanarImage{ ...valid, y: [u8(16)] }, PlanarImage{ ...valid, u: []u8{} },
		PlanarImage{ ...valid, v: []u8{} }, PlanarImage{ ...valid, y_stride: -1 },
		PlanarImage{ ...valid, y_stride: 1 }, PlanarImage{ ...valid, u_stride: 0 },
		PlanarImage{ ...valid, v_stride: 0 }, PlanarImage{ ...valid, width: 0 },
		PlanarImage{ ...valid, height: max_int }, PlanarImage{ ...valid, width: max_int }] {
		mut pixels := []u8{len: 16, init: 0xa5}
		if _ := image.to_rgba(mut pixels, 8, .limited, .bt709, .scalar) {
			assert false, 'invalid plane accepted'
		}
		assert pixels == []u8{len: 16, init: 0xa5}
	}
	for stride in [-1, 0, 7, max_int] {
		mut pixels := []u8{len: 16, init: 0xa5}
		if _ := valid.to_rgba(mut pixels, stride, .limited, .bt709, .scalar) {
			assert false
		}
		assert pixels == []u8{len: 16, init: 0xa5}
	}
	mut short := []u8{len: 15, init: 0xa5}
	if _ := valid.to_rgba(mut short, 8, .limited, .bt709, .scalar) {
		assert false
	}
	assert short == []u8{len: 15, init: 0xa5}
}

fn test_minimal_final_rows_are_valid_and_padding_is_untouched() {
	image := PlanarImage{
		y:        [u8(16), 0, 235]
		u:        [u8(128)]
		v:        [u8(128)]
		y_stride: 2
		u_stride: 2
		v_stride: 3
		width:    1
		height:   2
	}
	mut pixels := []u8{len: 11, init: 0xa5}
	image.to_rgba(mut pixels, 7, .limited, .bt709, .scalar)!
	assert pixels == [u8(0), 0, 0, 255, 0xa5, 0xa5, 0xa5, 255, 255, 255, 255]
}

fn test_native_boundary_rejects_metadata_before_borrowing_buffers() {
	y := [u8(16)]
	u := [u8(128)]
	v := [u8(128)]
	mut dst := []u8{len: 4, init: 0xa5}
	assert !convert_native(unsafe { nil }, 1, u.data, 1, v.data, 1, 1, 1, true, true, dst.data, 4, 0, 0)
	assert !convert_native(y.data, 1, u.data, 1, v.data, 1, 1, 1, false, true, dst.data, 4, 0, 0)
	assert !convert_native(y.data, 1, u.data, 1, v.data, 1, 1, 1, true, true, dst.data, 4, 2, 0)
	assert !convert_native(y.data, 1, u.data, 1, v.data, 1, 1, 1, true, true, dst.data, 4, 0, 6)
	assert !convert_native(y.data, u32(-1), u.data, 1, v.data, 1, 1, 1, true, true, dst.data, 4, 0, 0)
	assert !convert_native(y.data, 1, u.data, 1, v.data, 1, 0, 1, true, true, dst.data, 4, 0, 0)
	assert !convert_native(y.data, 1, u.data, 1, v.data, 1, 1, 1, true, true, dst.data, 3, 0, 0)
	assert dst == [u8(0xa5), 0xa5, 0xa5, 0xa5]
	assert convert_native(y.data, 1, u.data, 1, v.data, 1, 1, 1, true, true, dst.data, 4, 0, 0)
	assert dst == [u8(0), 0, 0, 255]
}
