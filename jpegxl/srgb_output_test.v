module jpegxl

import math

fn test_srgb_output_matrix_and_intensity_match_source_header_planning() {
	mut count := 0
	for line in $embed_file('testdata/srgb-output.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 6
		m := f[2].split(',').map(math.f32_from_bits(it.u32()))
		b := f[3].split(',').map(math.f32_from_bits(it.u32()))
		q := f[4].split(',').map(math.f32_from_bits(it.u32()))
		space := match f[0] { 'rgb' { ColorSpace.rgb } 'gray' { ColorSpace.gray } else { ColorSpace.xyb } }
		color := ColorEncoding{ color_space: space, rendering_intent: if space == .xyb { RenderingIntent.perceptual } else { RenderingIntent.relative } }
		file := FileHeader{ metadata: ImageMetadata{ color_encoding: color,
			tone_mapping: ToneMapping{ intensity_target: math.f32_from_bits(f[1].u32()) } },
			transform: CustomTransformData{ opsin: OpsinInverseMatrix{
				inverse_matrix: [m[0],m[1],m[2],m[3],m[4],m[5],m[6],m[7],m[8]]!,
				opsin_biases: [b[0],b[1],b[2]]!, quant_biases: [q[0],q[1],q[2],q[3]]! } } }
		output := prepare_srgb_output(file)!
		mut words := output.opsin.inverse_matrix[..].map(math.f32_bits(it))
		words << output.opsin.opsin_biases[..].map(math.f32_bits(it))
		words << output.opsin.quant_biases[..].map(math.f32_bits(it))
		words << math.f32_bits(output.intensity_target)
		assert words == f[5].split(',').map(it.u32()), 'sRGB output color ${count}'
		count++
	}
	assert count == 128
}

fn test_srgb_output_rejects_profiles_outside_supported_boundary() {
	opsin := default_opsin()
	for color in [ColorEncoding{ want_icc: true }, ColorEncoding{ color_space: .unknown },
		ColorEncoding{ primaries: .p3 }, ColorEncoding{ white_point: .equal_energy },
		ColorEncoding{ have_gamma: true }, ColorEncoding{ transfer_function: .pq },
		ColorEncoding{ color_space: .xyb, rendering_intent: .relative }] {
		if _ := prepare_srgb_output(FileHeader{ metadata: ImageMetadata{ color_encoding: color },
			transform: CustomTransformData{ opsin: opsin } }) { assert false }
	}
	gray := prepare_srgb_output(FileHeader{ metadata: ImageMetadata{ color_encoding: ColorEncoding{ color_space: .gray } },
		transform: CustomTransformData{ opsin: opsin } })!
	for column in 0 .. 3 {
		assert gray.opsin.inverse_matrix[column] == gray.opsin.inverse_matrix[3 + column]
		assert gray.opsin.inverse_matrix[column] == gray.opsin.inverse_matrix[6 + column]
	}
}
