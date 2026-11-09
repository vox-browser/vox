module jpegxl

import crypto.sha256
import math
import os

fn test_lf_reference_complete_photo_matches_native_rgba_in_both_output_modes() {
	mut count := 0
	for line in $embed_file('testdata/lf-reference-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/jpegxl', f[0]))!
		assert sha256.sum(bytes).hex() == f[3]
		for premultiply in [false, true] {
			image := decode_vardct_rgba(bytes, premultiply)!
			assert image.width == f[1].int() && image.height == f[2].int()
			assert image.pitch == image.width * 4
			assert sha256.sum(image.pixels).hex() == f[4], 'LF reference RGBA ${f[0]}'
		}
		count++
	}
	assert count == 1
}

fn test_lf_reference_frame_validates_ownership_before_reading_streams() {
	file := FileHeader{ size: Size{ width: 98, height: 98 }, metadata: ImageMetadata{ xyb_encoded: false } }
	base := FrameHeader{ frame_type: .lf, lf_level: 1, width: 98, height: 98, is_last: false, restoration: RestorationFilter.default() }
	for invalid in [FrameHeader{ ...base, frame_type: .regular }, FrameHeader{ ...base, lf_level: 0 },
		FrameHeader{ ...base, lf_level: 5 }, FrameHeader{ ...base, is_last: true },
		FrameHeader{ ...base, width: 97 }, FrameHeader{ ...base, have_crop: true },
		FrameHeader{ ...base, upsampling: 3 }, FrameHeader{ ...base, encoding: .modular }] {
		mut sections := [new_bit_reader([u8(255)])]
		if _ := decode_lf_reference_frame(file, invalid, .signed16, none, mut sections) { assert false }
		assert sections[0].position == 0
	}
}

fn test_vardct_lf_frames_save_restored_source_space_planes_at_each_level() {
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/vardct/constant-8x8-2.jxl'))!
	mut reader := new_bit_reader(bytes)
	file := reader.read_file_header()!
	ctx := file.frame_header_context()
	mut frame := reader.read_frame_header(ctx)!
	frame.postprocess(ctx)!
	toc := reader.read_toc(int(frame.num_toc_entries()))!
	sections := reader.read_sections(toc)!
	mut baseline_sections := sections.clone()
	raw := decode_vardct_frame(file, frame, .signed16, mut baseline_sections)!
	expected := restore_vardct_frame(raw, frame)!
	for level in u32(1) .. 5 {
		scale := u32(1) << (level*3)
		lf := FrameHeader{ ...frame, frame_type: .lf, lf_level: level, is_last: false, width: frame.width*scale, height: frame.height*scale }
		owner := FileHeader{ ...file, size: Size{ width: lf.width, height: lf.height } }
		mut inputs := sections.clone()
		actual := decode_lf_reference_frame(owner, lf, .signed16, none, mut inputs)!
		for c in 0 .. 3 {
			assert actual[c].width == 8 && actual[c].height == 8
			assert actual[c].samples.map(math.f32_bits(it)) == expected[c].samples.map(math.f32_bits(it))
		}
		for section in inputs { assert section.available_bits() == 0 }
	}
}

fn test_lf_reference_output_rejects_missing_truncated_and_trailing_frame_payloads() {
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/jpegxl/guardian-photo.jxl'))!
	mut reader := new_bit_reader(extract_codestream(bytes)!)
	file := reader.read_file_header()!
	reader.align_to_byte()!
	file_end := int(reader.position / 8)
	ctx := file.frame_header_context()
	mut frame := reader.read_frame_header(ctx)!
	frame.postprocess(ctx)!
	toc := reader.read_toc(int(frame.num_toc_entries()))!
	reader.read_sections(toc)!
	visible_start := int(reader.position / 8)
	// Keep the original file header and remove the LF frame it depends on.
	mut missing := bytes[..file_end].clone()
	missing << bytes[visible_start..]
	if _ := decode_vardct_rgba(missing, false) { assert false } else { assert err.msg() == 'Missing or unexpected JPEG XL LF reference' }
	for end in [file_end, visible_start, bytes.len-1] {
		if _ := decode_vardct_rgba(bytes[..end], false) { assert false }
	}
	mut trailing := bytes.clone()
	trailing << u8(0)
	if _ := decode_vardct_rgba(trailing, false) { assert false }
}
