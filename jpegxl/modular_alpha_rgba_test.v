module jpegxl

import crypto.sha256
import os

fn test_modular_xyb_alpha_matches_native_straight_and_paint_output() {
	mut count := 0
	mut total := 0
	mut grouped := 0
	mut multiple_lf := 0
	mut associated := 0
	for line in $embed_file('testdata/modular-alpha-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/modular-alpha', f[0]))!
		assert sha256.sum(data).hex() == f[3]
		for paint in [false, true] {
			image := decode_rgba(data, paint) or { panic('${f[0]}, paint=${paint}: ${err.msg()}') }
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width * 4
			assert sha256.sum(image.pixels).hex() == f[if paint { 5 } else { 4 }], 'Modular alpha ${f[0]}, paint=${paint}'
			mut alpha := []u8{len: image.width * image.height}
			for i in 0 .. alpha.len { alpha[i] = image.pixels[i * 4 + 3] }
			assert sha256.sum(alpha).hex() == f[6]
			total += image.pixels.len
		}
		mut reader := new_bit_reader(extract_codestream(data)!)
		file := reader.read_file_header()!
		ctx := file.frame_header_context()
		mut frame := reader.read_frame_header(ctx)!
		frame.postprocess(ctx)!
		assert frame.encoding == .modular && file.metadata.xyb_encoded
		if frame.num_groups() > 1 { grouped++ }
		if frame.num_lf_groups() > 1 { multiple_lf++ }
		if file.metadata.extra_channels[0].alpha_associated { associated++ }
		if _ := decode_opaque_rgba(data, false) { assert false }
		if _ := decode_vardct_rgba(data, false) { assert false }
		if _ := decode_lossless_rgba(data, false) { assert false }
		count++
	}
	assert count == 20 && total == 1800640 && grouped == 8 && multiple_lf == 4 && associated == 5
}

fn test_modular_xyb_alpha_validation_preserves_opaque_renderer_and_rejects_resampling() {
	data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/modular-alpha/xyb-alpha-17x13-2.jxl'))!
	mut reader := new_bit_reader(extract_codestream(data)!)
	file := reader.read_file_header()!
	ctx := file.frame_header_context()
	mut frame := reader.read_frame_header(ctx)!
	frame.postprocess(ctx)!
	validate_modular_xyb_frame_alpha(file, frame, true)!
	if _ := validate_modular_xyb_frame(file, frame) { assert false }
	for extra in [ExtraChannelInfo{ kind: .depth }, ExtraChannelInfo{ dimension_shift: 1 },
		ExtraChannelInfo{ bit_depth: BitDepth{ bits_per_sample: 16 } }, ExtraChannelInfo{ bit_depth: BitDepth{ floating_point: true } }] {
		bad := FileHeader{ ...file, metadata: ImageMetadata{ ...file.metadata, extra_channels: [extra] } }
		if _ := validate_modular_xyb_frame_alpha(bad, frame, true) { assert false }
	}
	for bad in [FrameHeader{ ...frame, extra_upsampling: []u32{} }, FrameHeader{ ...frame, extra_upsampling: [u32(3)] },
		FrameHeader{ ...frame, upsampling: 2 }] {
		if _ := validate_modular_xyb_frame_alpha(file, bad, true) { assert false }
	}
	for end in [0, 1, 2, 5, 10, data.len / 2, data.len - 1] {
		if _ := decode_rgba(data[..end], false) { assert false }
	}
	mut trailing := data.clone()
	trailing << u8(0)
	if _ := decode_rgba(trailing, true) { assert false }
}
