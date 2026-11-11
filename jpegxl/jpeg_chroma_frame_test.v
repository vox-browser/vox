module jpegxl

import crypto.sha256
import os

fn test_jpeg_recompressed_chroma_images_match_complete_native_rgba() {
	mut count := 0
	mut bytes_compared := 0
	mut samplings := []int{len: 4}
	mut multiple_lf := 0
	for line in $embed_file('testdata/jpeg-chroma-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/jpeg-chroma', f[0]))!
		assert sha256.sum(data).hex() == f[3]
		for paint in [false, true] {
			image := decode_rgba(data, paint) or { panic('${f[0]}, paint=${paint}: ${err.msg()}') }
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width * 4
			assert sha256.sum(image.pixels).hex() == f[if paint { 5 } else { 4 }], 'JPEG chroma ${f[0]}, paint=${paint}'
			assert image.pixels == decode_opaque_rgba(data, paint)!.pixels
			assert image.pixels == decode_vardct_rgba(data, paint)!.pixels
			bytes_compared += image.pixels.len
		}
		mut reader := new_bit_reader(extract_codestream(data)!)
		file := reader.read_file_header()!
		ctx := file.frame_header_context()
		mut frame := reader.read_frame_header(ctx)!
		frame.postprocess(ctx)!
		assert !file.metadata.xyb_encoded && frame.do_ycbcr && !frame.should_do_adaptive_lf_smoothing()
		hs := frame.hshift(0)!
		vs := frame.vshift(0)!
		assert frame.hshift(1)! == 0 && frame.vshift(1)! == 0
		assert frame.hshift(2)! == hs && frame.vshift(2)! == vs
		samplings[int(hs + vs * 2)]++
		if frame.num_lf_groups() > 1 { multiple_lf++ }
		count++
	}
	assert count == 20 && bytes_compared == 1660864 && samplings == [5, 5, 5, 5] && multiple_lf == 4
}

fn test_subsampled_frame_services_are_checked_before_reading_sections() {
	data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/jpeg-chroma/jpeg-17x13-h2-v2.jxl'))!
	mut reader := new_bit_reader(data)
	file := reader.read_file_header()!
	ctx := file.frame_header_context()
	mut frame := reader.read_frame_header(ctx)!
	frame.postprocess(ctx)!
	validate_vardct_frame_reference(file, frame, none)!
	for bad in [FrameHeader{ ...frame, do_ycbcr: false }, FrameHeader{ ...frame, flags: frame.flags & ~u64(0x80) },
		FrameHeader{ ...frame, flags: frame.flags | 32 }, FrameHeader{ ...frame, frame_type: .lf }] {
		mut sections := [new_bit_reader([u8(255)])]
		if _ := decode_vardct_frame_with_lf(file, bad, .signed16, none, mut sections) { assert false }
		assert sections[0].position == 0
	}
	for end in [0, 1, 2, 5, 10, data.len / 2, data.len - 1] {
		if _ := decode_rgba(data[..end], false) { assert false }
	}
}
