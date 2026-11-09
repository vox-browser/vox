module jpegxl

import encoding.hex

fn block_context_transcript(map_ BlockContextMap) !string {
	mut qfs := [u32(0), 1, 4, 12, 44, 255, 300, 0xffffffff]
	for q in map_.qf_thresholds {
		qfs << q
		qfs << q + 1
	}
	mut blocks := []string{}
	for c in 0 .. 3 {
		for shape in 0 .. 13 {
			for lf in [0, map_.num_lf_contexts / 2, map_.num_lf_contexts - 1] {
				for q in qfs { blocks << map_.block_context(lf, q, shape, c)!.str() }
			}
		}
	}
	mut nz := []string{}
	mut offsets := []string{}
	for b in [0, map_.num_contexts / 2, map_.num_contexts - 1] {
		offsets << map_.zero_density_context_offset(b)!.str()
		for n in 0 .. 67 { nz << map_.nonzero_context(u32(n), b)!.str() }
		nz << map_.nonzero_context(0xffffffff, b)!.str()
	}
	return '${map_.lf_thresholds[0].map(it.str()).join(',')}/${map_.lf_thresholds[1].map(it.str()).join(',')}/${map_.lf_thresholds[2].map(it.str()).join(',')}|${map_.qf_thresholds.map(it.str()).join(',')}|${map_.context_map.map(it.str()).join(',')}|${map_.num_lf_contexts},${map_.num_contexts},${map_.num_ac_contexts()}|${blocks.join(',')}|${nz.join(',')}|${offsets.join(',')}'
}

fn test_block_context_maps_match_source_thresholds_maps_queries_and_positions() {
	mut count := 0
	mut successes := 0
	mut source_overreads := 0
	for line in $embed_file('testdata/block-context.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 3
		data := hex.decode(f[0])!
		mut reader := new_bit_reader(data)
		actual := if map_ := reader.read_block_context_map() {
			successes++
			block_context_transcript(map_)!
		} else {
			'err'
		}
		assert actual == f[2], 'block context ${count}'
		if f[1].int() <= data.len * 8 {
			assert reader.position == f[1].int(), 'block context cursor ${count}'
		} else {
			// The cached source can consume past EOF; checked V reads may stop earlier.
			assert actual == 'err'
			source_overreads++
		}
		count++
	}
	assert count == 512
	assert successes > 300
	assert source_overreads > 0
}

fn test_zero_density_contexts_match_source_grid_and_scaled_rounding() {
	mut count := 0
	for line in $embed_file('testdata/zero-density.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 5
		assert zero_density_context(u32(f[0].u64()), u32(f[1].u64()), f[2].int(), f[3] == '1')! == f[4].int()
		count++
	}
	assert count == 8192
}

fn test_block_context_apis_reject_invalid_dimensions_and_storage() {
	mut reader := new_bit_reader([u8(1)])
	map_ := reader.read_block_context_map()!
	for args in [[-1, 0, 0], [1, 0, 0], [0, -1, 0], [0, 13, 0], [0, 0, -1], [0, 0, 3]] {
		if _ := map_.block_context(args[0], 0, args[1], args[2]) {
			assert false
		}
	}
	for context in [-1, 15] {
		if _ := map_.nonzero_context(0, context) {
			assert false
		}
		if _ := map_.zero_density_context_offset(context) {
			assert false
		}
	}
	broken := BlockContextMap{ num_lf_contexts: 1, num_contexts: 1 }
	if _ := broken.block_context(0, 0, 0, 0) {
		assert false
	}
	mut missing := new_bit_reader([]u8{})
	if _ := missing.read_block_context_map() {
		assert false
	}
	for args in [[0, 1, 0], [1, 0, 0], [64, 1, 0], [1, 64, 0], [1, 1, -1], [1, 1, 11]] {
		if _ := zero_density_context(u32(args[0]), u32(args[1]), args[2], false) {
			assert false
		}
	}
}
