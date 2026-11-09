module jpegxl

import math

fn test_vardct_epf_sigma_matches_all_source_block_words() {
	mut count := 0
	for line in $embed_file('testdata/epf-sigma.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 9
		maps := VarDctEpfMaps{
			width:         f[0].int()
			height:        f[1].int()
			raw_quant:     f[5].split(',').map(i32(it.i64()))
			transform_ids: f[6].split(',').map(u8(it.u32()))
			sharpness:     f[7].split(',').map(u8(it.u32()))
		}
		lut := f[4].split(',').map(math.f32_from_bits(it.u32()))
		mut fixed_lut := [8]f32{}
		for i in 0 .. 8 { fixed_lut[i] = lut[i] }
		filter := RestorationFilter{ epf_quant_multiplier: math.f32_from_bits(f[3].u32()), epf_sharp_lut: fixed_lut }
		sigma := EpfSigma.vardct(maps, QuantizerParams{ global_scale: f[2].u32(), quant_lf: 16 }, filter)!
		blocks := sigma.blocks or { panic('Missing variable EPF sigma') }
		assert blocks.width == maps.width && blocks.height == maps.height
		assert blocks.samples.map(math.f32_bits(it).str()).join(',') == f[8], 'VarDCT sigma ${count}'
		assert maps.raw_quant.map(it.str()).join(',') == f[5]
		assert maps.transform_ids.map(it.str()).join(',') == f[6]
		assert maps.sharpness.map(it.str()).join(',') == f[7]
		count++
	}
	assert count == 512
}

fn test_vardct_epf_sigma_rejects_incomplete_overlapping_or_invalid_maps() {
	base := VarDctEpfMaps{ width: 2, height: 2, raw_quant: [i32(1), 0, 0, 0], transform_ids: [
		u8(132),
		0,
		0,
		0,
	], sharpness: [u8(0), 1, 2, 7] }
	quant := QuantizerParams{ global_scale: 4096, quant_lf: 16 }
	filter := RestorationFilter{}
	sigma := EpfSigma.vardct(base, quant, filter)!
	blocks := sigma.blocks or { panic('Missing variable EPF sigma') }
	assert blocks.samples[0] == -10000
	for bad in [VarDctEpfMaps{}, VarDctEpfMaps{ ...base, raw_quant: [i32(1)] },
		VarDctEpfMaps{ ...base, raw_quant: [i32(0), 1, 1, 1] },
		VarDctEpfMaps{ ...base, raw_quant: [i32(-1), 1, 1, 1] },
		VarDctEpfMaps{ ...base, transform_ids: [u8(0), 0, 0, 0] },
		VarDctEpfMaps{ ...base, transform_ids: [u8(255), 0, 0, 0] },
		VarDctEpfMaps{ ...base, transform_ids: [u8(133), 0, 0, 0] },
		VarDctEpfMaps{ ...base, transform_ids: [u8(132), 128, 0, 0], raw_quant: [i32(1), 1, 0,
			0] }, VarDctEpfMaps{ ...base, sharpness: [u8(0), 1, 2, 8] }] {
		if _ := EpfSigma.vardct(bad, quant, filter) {
			assert false
		}
	}
	for scale in [u32(0), 73729] {
		if _ := EpfSigma.vardct(base, QuantizerParams{ global_scale: scale }, filter) {
			assert false
		}
	}
	for value in [f32(math.inf(1)), f32(math.nan())] {
		if _ := EpfSigma.vardct(base, quant, RestorationFilter{ epf_quant_multiplier: value }) {
			assert false
		}
		if _ := EpfSigma.vardct(base, quant, RestorationFilter{ epf_sharp_lut: [value, f32(1),
			1, 1, 1, 1, 1, 1]! }) {
			assert false
		}
	}
}
