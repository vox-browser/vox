module jpegxl

import crypto.sha256
import math
import os

fn test_vardct_alpha_planes_match_native_output_across_global_and_grouped_streams() {
	mut count := 0
	mut global_count := 0
	mut grouped := 0
	mut multiple_lf := 0
	mut associated := 0
	for line in $embed_file('testdata/vardct-alpha-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		bytes := os.read_bytes(os.join_path(@VMODROOT,'jpegxl/testdata/vardct-alpha',f[0]))!
		assert sha256.sum(bytes).hex() == f[3]
		mut reader := new_bit_reader(extract_codestream(bytes)!)
		file := reader.read_file_header()!
		ctx := file.frame_header_context()
		mut frame := reader.read_frame_header(ctx)!
		frame.postprocess(ctx)!
		toc := reader.read_toc(int(frame.num_toc_entries()))!
		mut sections := reader.read_sections(toc)!
		mut peek := sections[0]
		global := peek.read_lf_global(file,frame)!
		infos := global.modular_plan.coded.map(global.modular_plan.buffers[it])
		buckets := plan_modular_sections(infos,frame)!
		if buckets[0].len > 0 { global_count++ }
		if buckets[2].len > 0 { grouped++ }
		if frame.num_lf_groups() > 1 { multiple_lf++ }
		if file.metadata.extra_channels[0].alpha_associated { associated++ }
		storage := if file.metadata.modular_16bit_sufficient { ModularStorage.signed16 } else { ModularStorage.signed32 }
		output := decode_vardct_frame_with_lf(file,frame,storage,none,mut sections) or { panic('${f[0]}: ${err.msg()}') }
		assert output.extra_channels.len == 1
		alpha := output.extra_channels[0]
		assert alpha.width == int(frame.width) && alpha.height == int(frame.height)
		assert alpha.samples.all(it >= 0 && it <= 255)
		mut mask := []u8{len: alpha.samples.len}
		for y in 0 .. alpha.height {
			for x in 0 .. alpha.width {
				dx,dy := file.metadata.orientation.display_pixel(u32(x),u32(y),file.size)!
				mask[int(dy)*f[1].int()+int(dx)] = u8(alpha.samples[y*alpha.width+x])
			}
		}
		assert sha256.sum(mask).hex() == f[6], 'Raw VarDCT alpha ${f[0]}'
		for c in 0 .. 3 { assert output.planes[c].samples.all(math.is_finite(it)) }
		for section in sections { assert section.available_bits() == 0 }
		assert reader.available_bits() == 0
		count++
	}
	assert count == 20 && global_count > 0 && grouped > 0 && multiple_lf == 4 && associated == 5
}

fn test_vardct_extra_channel_validation_preserves_old_opaque_contract_and_cursors() {
	file := FileHeader{ metadata: ImageMetadata{ extra_channels: [ExtraChannelInfo{}] } }
	frame := FrameHeader{ width: 8, height: 8, extra_upsampling: [u32(1)], restoration: RestorationFilter.default() }
	mut sections := [new_bit_reader([u8(255)])]
	if _ := decode_vardct_frame(file,frame,.signed16,mut sections) { assert false }
	assert sections[0].position == 0
	for extra in [ExtraChannelInfo{ kind: .depth },ExtraChannelInfo{ dimension_shift: 1 },
		ExtraChannelInfo{ bit_depth: BitDepth{ bits_per_sample: 16 } },ExtraChannelInfo{ bit_depth: BitDepth{ floating_point: true } }] {
		bad := FileHeader{ ...file, metadata: ImageMetadata{ ...file.metadata, extra_channels: [extra] } }
		if _ := decode_vardct_frame_with_lf(bad,frame,.signed16,none,mut sections) { assert false }
		assert sections[0].position == 0
	}
	for invalid in [FrameHeader{ ...frame, extra_upsampling: []u32{} },FrameHeader{ ...frame, extra_upsampling: [u32(2)] },
		FrameHeader{ ...frame, upsampling: 2 },FrameHeader{ ...frame, width: 65536, height: 65536 }] {
		if _ := decode_vardct_frame_with_lf(file,invalid,.signed16,none,mut sections) { assert false }
		assert sections[0].position == 0
	}
}
