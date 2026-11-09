module jpegxl

fn group_data_test_inputs(frame FrameHeader, owner u64) !(HfMetadata, VarDctLfResult) {
	r := frame.lf_group_rect(owner)!
	w := int(r.width)
	h := int(r.height)
	cw := (w + 7) / 8
	ch := (h + 7) / 8
	metadata := HfMetadata{ width: w, height: h,
		raw_quant: []i32{len: w * h, init: i32(index % 256 + 1)},
		transform_ids: []u8{len: w * h, init: 128}, sharpness: []u8{len: w * h, init: u8(index % 8)},
		colors: HfGroupColorMap{ y_to_x: []i32{len: cw * ch, init: i32(index % 255 - 128)},
			y_to_b: []i32{len: cw * ch, init: i32(127 - index % 255)} } }
	mut planes := []FloatPlane{cap: 3}
	for c in 0 .. 3 {
		pw := w >> frame.hshift(c)!
		ph := h >> frame.vshift(c)!
		planes << FloatPlane{ width: pw, height: ph, samples: []f32{len: pw * ph, init: f32(c * 100000 + index)} }
	}
	return metadata, VarDctLfResult{ width: w, height: h, planes: planes,
		quant_lf_contexts: []u8{len: w * h, init: u8(index % 18)} }
}

fn test_group_data_crops_the_correct_lf_owner_color_tiles_and_subsampled_planes() {
	for mode in 0 .. 4 {
		frame := FrameHeader{ width: 4129, height: 2105,
			max_hshift: if mode == 1 || mode == 2 { u32(1) } else { u32(0) },
			max_vshift: if mode == 1 || mode == 3 { u32(1) } else { u32(0) },
			jpeg_upsampling: [u32(0), u32(mode), u32(0)]!, restoration: RestorationFilter.default() }
		for group in [u64(0), 7, 8, 15, 16, 119, 127, 128, frame.num_groups() - 1] {
			r := frame.block_group_rect(group)!
			owner := u64(r.y / 256) * 3 + u64(r.x / 256)
			assert frame.vardct_lf_group_for_group(group)! == owner
			metadata, lf := group_data_test_inputs(frame, owner)!
			selected := select_vardct_group(frame, group, owner, metadata, lf)!
			assert selected.maps.width == int(r.width) && selected.maps.height == int(r.height)
			x := int(r.x % 256)
			y := int(r.y % 256)
			for iy in 0 .. int(r.height) {
				for ix in 0 .. int(r.width) {
					p := (y + iy) * metadata.width + x + ix
					q := iy * int(r.width) + ix
					assert selected.maps.raw_quant[q] == i32(p % 256 + 1)
					assert selected.maps.lf_contexts[q] == u8(p % 18)
					assert selected.sharpness[q] == u8(p % 8)
				}
			}
			cw := (int(r.width) + 7) / 8
			for iy in 0 .. (int(r.height) + 7) / 8 {
				for ix in 0 .. cw {
					p := (y / 8 + iy) * ((metadata.width + 7) / 8) + x / 8 + ix
					assert selected.colors.y_to_x[iy * cw + ix] == i32(p % 255 - 128)
					assert selected.colors.y_to_b[iy * cw + ix] == i32(127 - p % 255)
				}
			}
			for c in 0 .. 3 {
				plane := selected.lf[c]
				hs := frame.hshift(c)!
				vs := frame.vshift(c)!
				for iy in 0 .. plane.height {
					for ix in 0 .. plane.width {
						p := ((y >> vs) + iy) * (metadata.width >> hs) + (x >> hs) + ix
						assert plane.samples[iy * plane.width + ix] == f32(c * 100000 + p)
					}
				}
			}
		}
	}
}

fn test_group_data_rejects_wrong_owners_and_incomplete_maps() {
	frame := FrameHeader{ width: 2065, height: 33, restoration: RestorationFilter.default() }
	metadata, lf := group_data_test_inputs(frame, 1)!
	if _ := select_vardct_group(frame, 8, 0, metadata, lf) { assert false }
	if _ := select_vardct_group(frame, frame.num_groups(), 1, metadata, lf) { assert false }
	if _ := select_vardct_group(frame, 8, 1, HfMetadata{ ...metadata, raw_quant: []i32{} }, lf) { assert false }
	if _ := select_vardct_group(frame, 8, 1, metadata, VarDctLfResult{ ...lf, planes: []FloatPlane{} }) { assert false }
}
