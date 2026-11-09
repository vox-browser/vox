module jpegxl

import crypto.sha256
import encoding.binary

fn hf_nonzero_fixture_word(mut data []u8, offset int, value u32) int {
	binary.little_endian_put_u32_at(mut data, value, offset)
	return offset + 4
}

fn test_hf_nonzero_maps_match_source_prediction_and_every_transform_update() {
	mut count := 0
	mut operations := 0
	mut output_words := 0
	mut transforms := map[int]bool{}
	for line in $embed_file('testdata/hf-nonzeros.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 5
		mut map_ := HfNonzeroMap{ width: f[0].int(), height: f[1].int(), samples: f[2].split(',').map(it.u32()) }
		ops := f[3].split(';')
		mut words := 2
		for op in ops { words += if op.starts_with('q,') { 4 } else { 6 + map_.samples.len } }
		mut data := []u8{len: words * 4}
		mut offset := 0
		for value in [u32(map_.width), u32(map_.height)] { offset = hf_nonzero_fixture_word(mut data, offset, value) }
		for op in ops {
			p := op.split(',')
			x := p[1].int()
			y := p[2].int()
			if p[0] == 'q' {
				for value in [u32(0), u32(x), u32(y), map_.predict_nonzeros(x, y)!] {
					offset = hf_nonzero_fixture_word(mut data, offset, value)
				}
			} else {
				id := p[3].int()
				nonzeros := p[4].u32()
				map_.record_block(x, y, hf_transform_from_id(id)!, nonzeros)!
				for value in [u32(1), u32(x), u32(y), u32(id), nonzeros, u32(map_.samples.len)] {
					offset = hf_nonzero_fixture_word(mut data, offset, value)
				}
				for value in map_.samples { offset = hf_nonzero_fixture_word(mut data, offset, value) }
				transforms[id] = true
			}
			operations++
		}
		assert offset == data.len
		assert sha256.sum(data).hex() == f[4], 'HF nonzero transcript ${count}'
		output_words += words
		count++
	}
	assert count == 512
	assert operations == 32768
	assert output_words == 6468090
	assert transforms.len == 27
}

fn test_hf_nonzero_map_validates_before_writes_and_preserves_wrapping_prediction() {
	mut map_ := HfNonzeroMap.new(2, 2)!
	assert map_.samples == [u32(0), 0, 0, 0]
	for point in [[-1, 0]!, [0, -1]!, [2, 0]!, [0, 2]!] {
		if _ := map_.predict_nonzeros(point[0], point[1]) { assert false }
		if _ := map_.record_block(point[0], point[1], .dct, 1) { assert false }
		assert map_.samples == [u32(0), 0, 0, 0]
	}
	if _ := map_.record_block(1, 1, .dct16x16, 1) { assert false }
	if _ := map_.record_block(0, 0, .dct, 64) { assert false }
	assert map_.samples == [u32(0), 0, 0, 0]
	map_.samples[1] = 0xffffffff
	map_.samples[2] = 0xffffffff
	assert map_.predict_nonzeros(1, 1)! == 0x7fffffff
	map_.samples[2] = 2
	assert map_.predict_nonzeros(1, 1)! == 1
	for dimension in [-1, 33] {
		if _ := HfNonzeroMap.new(dimension, 1) { assert false }
		if _ := HfNonzeroMap.new(1, dimension) { assert false }
	}
	empty := HfNonzeroMap.new(0, 0)!
	if _ := empty.predict_nonzeros(0, 0) { assert false }
	mut invalid := HfNonzeroMap{ width: 2, height: 2, samples: [u32(1)] }
	if _ := invalid.record_block(0, 0, .dct, 1) { assert false }
	assert invalid.samples == [u32(1)]
}
