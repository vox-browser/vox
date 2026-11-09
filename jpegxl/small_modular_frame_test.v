module jpegxl

import math
import os

fn test_small_modular_global_sections_match_source_raw_planes() {
	mut count := 0
	for line in $embed_file('testdata/small-modular-frame.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 6
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/jpegxl', f[0]))!
		mut input := new_bit_reader(extract_codestream(bytes)!)
		file := input.read_file_header()!
		ctx := file.frame_header_context()
		mut frame := input.read_frame_header(ctx)!
		frame.postprocess(ctx)!
		toc := input.read_toc(int(frame.num_toc_entries()))!
		mut sections := input.read_sections(toc)!
		assert sections[0].available_bits() == f[4].int() * 8
		storage := if f[1] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 }
		decoded := sections[0].decode_small_modular_frame(file, frame, storage)!
		quant := decoded.quantization
		assert '${quant.quant_factors[..].map(math.f32_bits(it).str()).join(',')}|${quant.inverse_factors[..].map(math.f32_bits(it).str()).join(',')}' == f[2]
		assert sections[0].position == f[3].int(), 'Frame consumed bits ${f[0]}'
		assert decoded.channels.map('${it.width},${it.height}:${it.samples.map(it.str()).join(',')}').join(';') == f[5], 'Frame raw planes ${f[0]}, ${f[1]}'
		count++
	}
	assert count == 12
}

fn test_small_modular_frame_rejects_unimplemented_services_and_grouped_channels() {
	for frame in [FrameHeader{ restoration: RestorationFilter.default() },
		FrameHeader{ restoration: RestorationFilter.default(), encoding: .modular, flags: 1 },
		FrameHeader{ restoration: RestorationFilter.default(), encoding: .modular, flags: 2 },
		FrameHeader{ restoration: RestorationFilter.default(), encoding: .modular, flags: 16 }] {
		mut reader := new_bit_reader([])
		if _ := reader.decode_small_modular_frame(FileHeader{}, frame, .signed32) {
			assert false
		}
		assert reader.position == 0
	}
	mut reader := new_bit_reader([u8(9)]) // Default quantization, no global tree, default modular header.
	if _ := reader.decode_small_modular_frame(FileHeader{}, FrameHeader{ restoration: RestorationFilter.default(), encoding: .modular, width: 512, height: 512 }, .signed32) {
		assert false
	}
	assert reader.position == 6
}
