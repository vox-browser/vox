module jpegxl

import math

fn test_chroma_planes_match_native_pinned_stages() {
	mut count := 0
	for line in $embed_file('testdata/chroma.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 5
		input := FloatPlane{ width: f[1].int(), height: f[2].int(), samples: f[3].split(',').map(math.f32_from_bits(it.u32())) }
		output := match f[0] {
			'H' { chroma_upsample_plane(input, .horizontal)! }
			'V' { chroma_upsample_plane(input, .vertical)! }
			'HV' { chroma_upsample_plane(chroma_upsample_plane(input, .horizontal)!, .vertical)! }
			else {
				assert false
				FloatPlane{}
			}
		}
		assert output.width == input.width * if f[0] in ['H', 'HV'] { 2 } else { 1 }
		assert output.height == input.height * if f[0] in ['V', 'HV'] { 2 } else { 1 }
		assert output.samples.map(math.f32_bits(it).str()).join(',') == f[4], 'Chroma ${count}'
		assert input.samples.map(math.f32_bits(it).str()).join(',') == f[3]
		count++
	}
	assert count == 384
}

fn test_chroma_borders_empty_and_output_bounds() {
	input := FloatPlane{ width: 3, height: 1, samples: [f32(1), 2, 4] }
	assert chroma_upsample_plane(input, .horizontal)!.samples == [f32(1), 1.25, 1.75, 2.5, 3.5,
		4]
	assert chroma_upsample_plane(FloatPlane{}, .vertical)!.samples.len == 0
	if _ := chroma_upsample_plane(FloatPlane{ width: 3, height: 1 }, .vertical) {
		assert false
	}
	if _ := chroma_upsample_plane(FloatPlane{ width: 1048576 }, .horizontal) {
		assert false
	}
}
