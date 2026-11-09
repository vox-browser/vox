module jpegxl

import math
import os

fn test_lf_global_modular_plans_preserve_frozen_native_raw_planes_and_positions() {
	mut count := 0
	for line in $embed_file('testdata/small-modular-frame.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/jpegxl', f[0]))!
		mut input := new_bit_reader(extract_codestream(bytes)!)
		file := input.read_file_header()!
		ctx := file.frame_header_context()
		mut frame := input.read_frame_header(ctx)!
		frame.postprocess(ctx)!
		toc := input.read_toc(int(frame.num_toc_entries()))!
		mut sections := input.read_sections(toc)!
		global := sections[0].read_lf_global(file, frame)!
		assert global.vardct == none
		q := global.quantization
		assert '${q.quant_factors[..].map(math.f32_bits(it).str()).join(',')}|${q.inverse_factors[..].map(math.f32_bits(it).str()).join(',')}' == f[2]
		plan := global.modular_plan
		infos := plan.coded.map(plan.buffers[it].allocated())
		storage := if f[1] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 }
		coded := sections[0].decode_modular_stream(infos, storage, 0, global.modular_header, global.tree)!
		output := plan.reconstruct(coded, storage)!
		assert sections[0].position == f[3].int()
		assert output.map('${it.width},${it.height}:${it.samples.map(it.str()).join(',')}').join(';') == f[5]
		count++
	}
	assert count == 12
}

fn test_lf_global_vardct_omits_color_planes_and_empty_modular_header() {
	file := FileHeader{ metadata: ImageMetadata{ bit_depth: BitDepth{ bits_per_sample: 8 } } }
	for scale in [u32(1), 2048] {
		for extra in [false, true] {
			f := if extra { FileHeader{ ...file, metadata: ImageMetadata{ ...file.metadata,
				extra_channels: [ExtraChannelInfo{ kind: .alpha, bit_depth: BitDepth{ bits_per_sample: 8 } }] } } } else { file }
			frame := FrameHeader{ width: 16, height: 8, extra_upsampling: if extra { [u32(1)] } else { []u32{} }, restoration: RestorationFilter.default() }
			// Default LF factors, GS selector 0, LF selector 0 (16), default
			// block/color maps, no global tree, optional four-bit modular header.
			mut bits := u64(1) | (u64(scale - 1) << 3) | (u64(3) << 16)
			end := if extra { 23 } else { 19 }
			if extra { bits |= u64(3) << 19 }
			bits |= u64(21) << end
			mut reader := new_bit_reader([]u8{len: 4, init: u8(bits >> (index * 8))})
			state := reader.read_lf_global(f, frame)!
			assert reader.position == end
			assert reader.read(5)! == 21
			context := state.vardct or { panic('Missing VarDCT context') }
			assert context.quantizer.global_scale == scale && context.quantizer.quant_lf == 16
			assert context.block_context.num_contexts == 15
			assert state.tree == none
			if extra {
				h := state.modular_header or { panic('Missing alpha modular header') }
				assert h.use_global_tree && h.transforms.len == 0
				assert state.modular_plan.outputs.len == 1
				info := state.modular_plan.buffers[state.modular_plan.outputs[0]]
				assert info.output_channel == ?u32(u32(3)) && info.width == 16 && info.height == 8
			} else {
				assert state.modular_header == none && state.modular_plan.buffers.len == 0
			}
		}
	}
}

fn test_lf_global_rejects_feature_streams_and_invalid_geometry_before_input() {
	for flag in [u64(2), 16] {
		mut reader := new_bit_reader([u8(255)])
		if _ := reader.read_lf_global(FileHeader{}, FrameHeader{ width: 8, height: 8, flags: flag, restoration: RestorationFilter.default() }) { assert false }
		assert reader.position == 0
	}
	mut reader := new_bit_reader([u8(255)])
	if _ := reader.read_lf_global(FileHeader{}, FrameHeader{ restoration: RestorationFilter.default() }) { assert false }
	assert reader.position == 0
}
