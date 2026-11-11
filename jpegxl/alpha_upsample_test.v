module jpegxl

import crypto.sha256
import os

fn test_resampled_alpha_matches_native_vardct_and_modular_xyb_images() {
	mut count := 0
	mut bytes_compared := 0
	mut vardct := 0
	mut modular := 0
	mut late := 0
	mut early := 0
	for line in $embed_file('testdata/alpha-upsample-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/alpha-upsample', f[0]))!
		assert sha256.sum(data).hex() == f[3]
		for paint in [false, true] {
			image := decode_rgba(data, paint) or { panic('${f[0]}, paint=${paint}: ${err.msg()}') }
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width * 4
			assert sha256.sum(image.pixels).hex() == f[if paint { 5 } else { 4 }], 'Resampled alpha ${f[0]}, paint=${paint}'
			mut alpha := []u8{len: image.width * image.height}
			for i in 0 .. alpha.len { alpha[i] = image.pixels[i * 4 + 3] }
			assert sha256.sum(alpha).hex() == f[6]
			bytes_compared += image.pixels.len
		}
		mut reader := new_bit_reader(extract_codestream(data)!)
		file := reader.read_file_header()!
		ctx := file.frame_header_context()
		mut frame := reader.read_frame_header(ctx)!
		frame.postprocess(ctx)!
		parts := f[0].split('-')
		assert frame.upsampling == parts[2][1..].u32()
		assert frame.extra_upsampling == [parts[3][1..].u32()]
		if frame.encoding == .vardct { vardct++ } else { modular++ }
		if frame.upsampling > 1 && frame.upsampling == frame.extra_upsampling[0] { late++ } else { early++ }
		count++
	}
	assert count == 72 && bytes_compared == 4817664 && vardct == 36 && modular == 36 && late == 24 && early == 48
}

fn test_alpha_rendering_checks_channel_geometry_and_sampling_before_allocation() {
	file := FileHeader{ metadata: ImageMetadata{ extra_channels: [ExtraChannelInfo{}] } }
	frame := FrameHeader{ width: 8, height: 8, extra_upsampling: [u32(1)], restoration: RestorationFilter.default() }
	channel := ModularChannel{ width: 8, height: 8, samples: []i32{len: 64} }
	for bad in [FrameHeader{ ...frame, extra_upsampling: []u32{} }, FrameHeader{ ...frame, extra_upsampling: [u32(3)] },
		FrameHeader{ ...frame, upsampling: 2 }, FrameHeader{ ...frame, width: 9 },
		FrameHeader{ ...frame, width: 65536, height: 65536 }] {
		if _ := render_alpha_plane(channel, file, bad, .signed16) { assert false }
	}
	for extra in [ExtraChannelInfo{ kind: .depth }, ExtraChannelInfo{ dimension_shift: 1 },
		ExtraChannelInfo{ bit_depth: BitDepth{ bits_per_sample: 16 } }, ExtraChannelInfo{ bit_depth: BitDepth{ floating_point: true } }] {
		bad := FileHeader{ ...file, metadata: ImageMetadata{ ...file.metadata, extra_channels: [extra] } }
		if _ := render_alpha_plane(channel, bad, frame, .signed16) { assert false }
	}
	if _ := render_alpha_plane(ModularChannel{ ...channel, samples: []i32{} }, file, frame, .signed16) { assert false }
}
