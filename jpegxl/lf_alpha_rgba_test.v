module jpegxl

import crypto.sha256
import os

fn test_lf_alpha_references_preserve_native_straight_and_paint_output() {
	mut count := 0
	mut total := 0
	mut lf_frames := 0
	for line in $embed_file('testdata/lf-alpha-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/lf-alpha', f[0]))!
		assert sha256.sum(data).hex() == f[3]
		for paint in [false, true] {
			image := decode_rgba(data, paint) or { panic('${f[0]}, paint=${paint}: ${err.msg()}') }
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width * 4
			assert sha256.sum(image.pixels).hex() == f[if paint { 5 } else { 4 }], 'LF alpha ${f[0]}, paint=${paint}'
			total += image.pixels.len
		}
		mut reader := new_bit_reader(extract_codestream(data)!)
		file := reader.read_file_header()!
		ctx := file.frame_header_context()
		mut lf := reader.read_frame_header(ctx)!
		lf.postprocess(ctx)!
		assert lf.frame_type == .lf && lf.encoding == .modular && lf.lf_level == 1
		assert !lf.is_last && !lf.has_lf_frame()
		lf_toc := reader.read_toc(int(lf.num_toc_entries()))!
		mut lf_sections := reader.read_sections(lf_toc)!
		storage := if file.metadata.modular_16bit_sufficient { ModularStorage.signed16 } else { ModularStorage.signed32 }
		saved := decode_lf_reference_frame(file, lf, storage, none, mut lf_sections)!
		for section in lf_sections { assert section.available_bits() == 0 }
		mut visible := reader.read_frame_header(ctx)!
		visible.postprocess(ctx)!
		assert visible.frame_type == .regular && visible.encoding == .vardct && visible.has_lf_frame()
		for plane in saved { assert plane.width == int(visible.size_blocks().width) && plane.height == int(visible.size_blocks().height) }
		lf_frames++
		count++
	}
	assert count == 20 && lf_frames == 20 && total == 1800640
}

fn test_lf_alpha_output_rejects_missing_reference_and_truncated_sections() {
	data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/lf-alpha/lf-alpha-17x13-2.jxl'))!
	mut reader := new_bit_reader(data)
	file := reader.read_file_header()!
	reader.align_to_byte()!
	file_end := int(reader.position / 8)
	ctx := file.frame_header_context()
	mut lf := reader.read_frame_header(ctx)!
	lf.postprocess(ctx)!
	toc := reader.read_toc(int(lf.num_toc_entries()))!
	reader.read_sections(toc)!
	visible_start := int(reader.position / 8)
	mut missing := data[..file_end].clone()
	missing << data[visible_start..]
	if _ := decode_rgba(missing, false) { assert false } else { assert err.msg() == 'Missing or unexpected JPEG XL LF reference' }
	for end in [file_end, visible_start - 1, visible_start, data.len - 1] {
		if _ := decode_rgba(data[..end], true) { assert false }
	}
}

fn test_lf_alpha_validation_rejects_unsupported_channels_before_reading_payload() {
	file := FileHeader{ size: Size{ width: 17, height: 13 }, metadata: ImageMetadata{ extra_channels: [ExtraChannelInfo{}] } }
	frame := FrameHeader{ frame_type: .lf, encoding: .modular, width: 17, height: 13, lf_level: 1, is_last: false,
		extra_upsampling: [u32(1)], restoration: RestorationFilter.default() }
	validate_lf_reference_frame(file, frame)!
	for extra in [ExtraChannelInfo{ kind: .depth }, ExtraChannelInfo{ dimension_shift: 1 },
		ExtraChannelInfo{ bit_depth: BitDepth{ bits_per_sample: 16 } }, ExtraChannelInfo{ bit_depth: BitDepth{ floating_point: true } }] {
		bad := FileHeader{ ...file, metadata: ImageMetadata{ ...file.metadata, extra_channels: [extra] } }
		mut sections := [new_bit_reader([u8(255)])]
		if _ := decode_lf_reference_frame(bad, frame, .signed16, none, mut sections) { assert false }
		assert sections[0].position == 0
	}
	for bad in [FrameHeader{ ...frame, extra_upsampling: []u32{} }, FrameHeader{ ...frame, extra_upsampling: [u32(2)] },
		FrameHeader{ ...frame, upsampling: 2 }] {
		mut sections := [new_bit_reader([u8(255)])]
		if _ := decode_lf_reference_frame(file, bad, .signed16, none, mut sections) { assert false }
		assert sections[0].position == 0
	}
}
