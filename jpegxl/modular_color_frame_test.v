module jpegxl

import crypto.sha256
import encoding.binary
import math

fn test_modular_xyb_rendering_retains_all_frozen_native_conversion_words() {
	mut count := 0
	mut words := 0
	for line in $embed_file('testdata/modular-xyb.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		q := f[1].split(',').map(math.f32_from_bits(it.u32()))
		mut input := []ModularChannel{cap: 3}
		for c in 0 .. 3 {
			samples := f[c+2].split(',').map(i32(it.i64()))
			input << ModularChannel{ width: 4, height: samples.len/4, samples: samples }
		}
		frame := FrameHeader{ encoding: .modular, width: 4, height: u32(input[0].height), restoration: RestorationFilter{ gab: false, epf_iterations: 0 } }
		raw := ModularFramePlanes{ channels: input, quantization: LfQuantFactors{ quant_factors: [q[0],q[1],q[2]]! } }
		before := input[0].samples.clone()
		result := render_modular_xyb_frame(raw, FileHeader{}, frame, if f[0] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 })!
		mut bytes := []u8{len: 3*input[0].samples.len*4}
		for c in 0 .. 3 {
			assert result[c].width == 4 && result[c].height == input[0].height
			for i, value in result[c].samples { binary.little_endian_put_u32_at(mut bytes, math.f32_bits(value), (c*input[0].samples.len+i)*4) }
		}
		assert sha256.sum(bytes).hex() == f[5], 'Modular XYB rendering ${count}'
		assert input[0].samples == before
		words += input[0].samples.len*3
		count++
	}
	assert count == 512 && words == 130560
}

fn test_modular_xyb_rendering_filters_then_upsamples_and_checks_frame_services() {
	mut reader := new_bit_reader([u8(1)])
	transform := reader.read_transform_data(true)!
	file := FileHeader{ transform: transform }
	channels := []ModularChannel{len: 3, init: ModularChannel{ width: 4, height: 3, samples: []i32{len: 12, init: i32(index*9)} } }
	raw := ModularFramePlanes{ channels: channels, quantization: LfQuantFactors{ quant_factors: [f32(1)/65536,f32(1)/4096,f32(1)/4096]! } }
	frame := FrameHeader{ encoding: .modular, width: 7, height: 5, upsampling: 2, restoration: RestorationFilter.default() }
	actual := render_modular_xyb_frame(raw, file, frame, .signed16)!
	converted := modular_xyb_planes(channels, raw.quantization, .signed16)!
	restored := restore_modular_frame(converted, frame_filter_geometry(frame))!
	for c in 0 .. 3 {
		expected := upsample_plane(restored[c], 2, transform.weights2[..], 7, 5)!
		assert actual[c].samples.map(math.f32_bits(it)) == expected.samples.map(math.f32_bits(it))
	}
	for invalid in [FrameHeader{ ...frame, encoding: .vardct }, FrameHeader{ ...frame, flags: 1 },
		FrameHeader{ ...frame, flags: 2 }, FrameHeader{ ...frame, flags: 16 }, FrameHeader{ ...frame, flags: 32 },
		FrameHeader{ ...frame, do_ycbcr: true }, FrameHeader{ ...frame, width: 9 }] {
		if _ := render_modular_xyb_frame(raw, file, invalid, .signed16) { assert false }
	}
	if _ := render_modular_xyb_frame(raw, FileHeader{ metadata: ImageMetadata{ xyb_encoded: false } }, frame, .signed16) { assert false }
	if _ := render_modular_xyb_frame(ModularFramePlanes{ ...raw, channels: channels[..2] }, file, frame, .signed16) { assert false }
}
