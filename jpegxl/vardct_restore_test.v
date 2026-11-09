module jpegxl

import math

fn test_vardct_restoration_preserves_native_gaborish_words_and_excludes_padding() {
	mut count := 0
	for line in $embed_file('testdata/gaborish.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		w := f[0].int()
		h := f[1].int()
		pw := ((w + 7) / 8) * 8
		ph := ((h + 7) / 8) * 8
		original := f[4].split(',').map(math.f32_from_bits(it.u32()))
		mut padded := []f32{len: pw * ph, init: 1000}
		for y in 0 .. h {
			for x in 0 .. w { padded[y * pw + x] = original[y * w + x] }
		}
		input := FloatPlane{ width: pw, height: ph, samples: padded }
		w1 := math.f32_from_bits(f[2].u32())
		w2 := math.f32_from_bits(f[3].u32())
		frame := FrameHeader{ width: u32(w), height: u32(h), restoration: RestorationFilter{
			gab: true, gab_weights: [w1,w2,w1,w2,w1,w2]!, epf_iterations: 0 } }
		result := restore_vardct_frame(VarDctFramePlanes{ planes: [input,input,input]! }, frame)!
		modular := restore_modular_frame([input,input,input]!, FrameHeader{ ...frame, encoding: .modular })!
		for plane in result {
			assert plane.width == w && plane.height == h
			assert plane.samples.map(math.f32_bits(it).str()).join(',') == f[5], 'Restoration Gaborish ${count}'
		}
		for c in 0 .. 3 { assert modular[c].samples.map(math.f32_bits(it)) == result[c].samples.map(math.f32_bits(it)) }
		count++
	}
	assert count == 512
}

fn test_vardct_restoration_checks_sigma_coverage_iterations_and_disabled_filters() {
	plane := FloatPlane{ width: 8, height: 8, samples: []f32{len: 64, init: f32(index)} }
	raw := VarDctFramePlanes{ planes: [plane,plane,plane]! }
	frame := FrameHeader{ width: 3, height: 2, restoration: RestorationFilter{ gab: false, epf_iterations: 0 } }
	output := restore_vardct_frame(raw, frame)!
	for p in output { assert p.samples == [f32(0),1,2,8,9,10] }
	if _ := restore_vardct_frame(raw, FrameHeader{ ...frame, restoration: RestorationFilter{ gab: false, epf_iterations: 4 } }) { assert false }
	if _ := restore_vardct_frame(raw, FrameHeader{ ...frame, restoration: RestorationFilter{ gab: false, epf_iterations: 1 } }) { assert false }
	if _ := restore_vardct_frame(raw, FrameHeader{ ...frame, width: 9 }) { assert false }
}
