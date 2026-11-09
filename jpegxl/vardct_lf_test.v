module jpegxl

import math

fn test_vardct_lf_reconstruction_matches_source_storage_sampling_and_contexts() {
	mut count := 0
	for line in $embed_file('testdata/vardct-lf.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 13
		mut hs := [3]u32{}
		mut vs := [3]u32{}
		mut factors := [3]f32{}
		mut thresholds := [3][]i32{}
		mut contexts := 1
		for c in 0 .. 3 {
			hs[c] = f[3].split(',')[c].u32()
			vs[c] = f[4].split(',')[c].u32()
			factors[c] = math.f32_from_bits(f[7].split(',')[c].u32())
			text := f[9].split(';')[c]
			thresholds[c] = if text == '' { []i32{} } else { text.split(',').map(i32(it.i64())) }
			contexts *= thresholds[c].len + 1
		}
		q := f[6].split(',')
		cc := f[8].split(',')
		parameters := VarDctLfParameters{
			width:             f[1].int()
			height:            f[2].int()
			horizontal_shift:  hs
			vertical_shift:    vs
			extra_precision:   f[5].u32()
			quantizer:         QuantizerParams{ global_scale: q[0].u32(), quant_lf: q[1].u32() }
			lf_quant:          LfQuantFactors{ quant_factors: factors }
			color_correlation: ColorCorrelationParams{ color_factor: cc[0].u32(), base_correlation_x: math.f32_from_bits(cc[1].u32()), base_correlation_b: math.f32_from_bits(cc[2].u32()), ytox_lf: i32(cc[3].i64()), ytob_lf: i32(cc[4].i64()) }
			block_context:     BlockContextMap{ lf_thresholds: thresholds, num_lf_contexts: contexts }
		}
		mut input := []ModularChannel{}
		for coded, text in f[10].split(';') {
			c := if coded < 2 { coded ^ 1 } else { 2 }
			input << ModularChannel{ width: parameters.width >> hs[c], height: parameters.height >> vs[c], samples: text.split(',').map(i32(it.i64())) }
		}
		output := reconstruct_vardct_lf(input, parameters)!
		assert output.width == parameters.width && output.height == parameters.height
		assert output.planes.len == 3
		actual := output.planes.map('${it.width},${it.height}:${it.samples.map(math.f32_bits(it).str()).join(',')}').join(';')
		assert actual == f[11], 'VarDCT LF planes ${count}, ${f[0]}-bit storage'
		assert output.quant_lf_contexts.map(it.str()).join(',') == f[12], 'VarDCT LF contexts ${count}'
		assert input.map(it.samples.map(it.str()).join(',')).join(';') == f[10]
		count++
	}
	assert count == 512
}

fn test_vardct_lf_reconstruction_rejects_invalid_geometry_scales_and_contexts() {
	input := []ModularChannel{len: 3, init: ModularChannel{ width: 2, height: 2, samples: [
		i32(0),
		1,
		-1,
		2,
	] }}
	base := VarDctLfParameters{ width: 2, height: 2, quantizer: QuantizerParams{ global_scale: 4096, quant_lf: 16 }, lf_quant: LfQuantFactors{ quant_factors: [
		f32(1.0 / 4096.0),
		f32(1.0 / 512.0),
		f32(1.0 / 256.0),
	]! }, block_context: BlockContextMap{ num_lf_contexts: 1 } }
	output := reconstruct_vardct_lf(input, base)!
	assert output.quant_lf_contexts == [u8(0), 0, 0, 0]
	for p in [VarDctLfParameters{ ...base, width: 0 },
		VarDctLfParameters{ ...base, extra_precision: 4 },
		VarDctLfParameters{ ...base, horizontal_shift: [u32(2), 0, 0]! },
		VarDctLfParameters{ ...base, horizontal_shift: [u32(1), 0, 0]! },
		VarDctLfParameters{ ...base, width: 3, horizontal_shift: [u32(1), 0, 0]! },
		VarDctLfParameters{ ...base, quantizer: QuantizerParams{} },
		VarDctLfParameters{ ...base, quantizer: QuantizerParams{ global_scale: 73729, quant_lf: 1 } },
		VarDctLfParameters{ ...base, quantizer: QuantizerParams{ global_scale: 1, quant_lf: 65537 } },
		VarDctLfParameters{ ...base, lf_quant: LfQuantFactors{} },
		VarDctLfParameters{ ...base, block_context: BlockContextMap{} },
		VarDctLfParameters{ ...base, color_correlation: ColorCorrelationParams{ color_factor: 0 } },
		VarDctLfParameters{ ...base, color_correlation: ColorCorrelationParams{ base_correlation_x: f32(math.nan()) } }] {
		if _ := reconstruct_vardct_lf(input, p) {
			assert false
		}
	}
	if _ := reconstruct_vardct_lf(input[..2], base) {
		assert false
	}
}
