module jpegxl

import math

fn test_modular_restoration_reuses_native_epf1_constant_sigma_records() {
	mut count := 0
	for line in $embed_file('testdata/epf1.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		p := f[7].split(':')
		if p[0] != 'C' || f[2] != '0' || f[3] != '0' || f[4].u32() != math.f32_bits(f32(1)) { continue }
		inverse := math.f32_from_bits(p[1].u32())
		sigma := epf_inverse_sigma_numerator / inverse
		if !math.is_finite(sigma) || sigma <= 0 { continue }
		// Require the metadata round trip to reproduce the frozen stage input.
		if math.f32_bits(epf_inverse_sigma_numerator / sigma) != math.f32_bits(inverse) { continue }
		input := f[8].split(';').map(FloatPlane{ width: f[0].int(), height: f[1].int(), samples: it.split(',').map(math.f32_from_bits(it.u32())) })
		cs := f[6].split(',').map(math.f32_from_bits(it.u32()))
		frame := FrameHeader{ encoding: .modular, width: f[0].u32(), height: f[1].u32(), restoration: RestorationFilter{
			gab: false, epf_iterations: 1, epf_sigma_for_modular: sigma,
			epf_border_sad_multiplier: math.f32_from_bits(f[5].u32()), epf_channel_scale: [cs[0],cs[1],cs[2]]! } }
		output := restore_modular_frame([input[0],input[1],input[2]]!, frame)!
		assert output[..].map(it.samples.map(math.f32_bits(it).str()).join(',')).join(';') == f[9]
		count++
	}
	assert count == 1
}

fn test_modular_restoration_orders_all_filters_and_crops_before_filtering() {
	mut planes := []FloatPlane{cap: 3}
	for c in 0 .. 3 {
		planes << FloatPlane{ width: 8, height: 8, samples: []f32{len: 64, init: f32((index * 11 + c * 3) % 17) / 64} }
	}
	for iterations in u32(0) .. 4 {
		filter := RestorationFilter{ ...RestorationFilter.default(), epf_iterations: iterations, epf_sigma_for_modular: 2 }
		frame := FrameHeader{ encoding: .modular, width: 5, height: 3, restoration: filter }
		actual := restore_modular_frame([planes[0],planes[1],planes[2]]!, frame)!
		mut expected := []FloatPlane{cap: 3}
		for c in 0 .. 3 {
			cropped := crop_float_plane(planes[c], 0, 0, 5, 3)!
			expected << gaborish_plane(cropped, filter.gab_weights[c*2], filter.gab_weights[c*2+1])!
		}
		common := EpfParameters{ border_sad_multiplier: filter.epf_border_sad_multiplier, channel_scale: filter.epf_channel_scale }
		sigma := EpfSigma.modular(2)!
		if iterations >= 3 { expected = epf0_planes(expected, EpfParameters{ ...common, sigma_scale: filter.epf_pass0_sigma_scale }, sigma, 0, 0)! }
		if iterations >= 1 { expected = epf1_planes(expected, common, sigma, 0, 0)! }
		if iterations >= 2 { expected = epf2_planes(expected, EpfParameters{ ...common, sigma_scale: filter.epf_pass2_sigma_scale }, sigma, 0, 0)! }
		for c in 0 .. 3 { assert actual[c].samples.map(math.f32_bits(it)) == expected[c].samples.map(math.f32_bits(it)) }
	}
	base := FrameHeader{ encoding: .modular, width: 1, height: 1, restoration: RestorationFilter.default() }
	for invalid in [FrameHeader{ ...base, encoding: .vardct }, FrameHeader{ ...base, upsampling: 2 },
		FrameHeader{ ...base, restoration: RestorationFilter{ ...base.restoration, epf_iterations: 4 } },
		FrameHeader{ ...base, restoration: RestorationFilter{ ...base.restoration, epf_sigma_for_modular: 0 } }] {
		if _ := restore_modular_frame([planes[0],planes[1],planes[2]]!, invalid) { assert false }
	}
}
