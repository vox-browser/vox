module jpegxl

import crypto.sha256
import encoding.binary
import encoding.hex
import math

fn matrix_set_fixture_tree(property u8, threshold i32, predictor Predictor, left i32, right i32) !ModularTree {
	mut reader := new_bit_reader([u8(0xf2), 1])
	return ModularTree{
		num_properties: 16
		histograms:     reader.read_histograms(2, true)!
		nodes:          [
			ModularTreeNode{ property: property, threshold: threshold, left: 1, right: 2 },
			ModularTreeNode{ is_leaf: true, predictor: predictor, offset: left, multiplier: 1, context: 0 },
			ModularTreeNode{ is_leaf: true, predictor: predictor, offset: right, multiplier: 1, context: 1 },
		]
	}
}

fn matrix_set_fixture_digest(matrices DequantMatrices) !string {
	mut words := 0
	for table in matrices.tables { words += 3 + table.samples.len }
	for id in 0 .. 27 {
		dims := hf_transform_from_id(id)!.covered_blocks()
		words += 3 * (3 + dims[0] * dims[1] * 64)
	}
	mut data := []u8{len: words * 4}
	mut offset := 0
	for table in matrices.tables {
		for value in [u32(table.rows), u32(table.columns), u32(table.samples.len)] {
			binary.little_endian_put_u32_at(mut data, value, offset)
			offset += 4
		}
		for value in table.samples {
			binary.little_endian_put_u32_at(mut data, math.f32_bits(value), offset)
			offset += 4
		}
	}
	for id in 0 .. 27 {
		transform := hf_transform_from_id(id)!
		for c in 0 .. 3 {
			channel := matrices.channel(transform, c)!
			for value in [u32(id), u32(c), u32(channel.len)] {
				binary.little_endian_put_u32_at(mut data, value, offset)
				offset += 4
			}
			for value in channel {
				binary.little_endian_put_u32_at(mut data, math.f32_bits(value), offset)
				offset += 4
			}
		}
	}
	assert offset == data.len
	return sha256.sum(data).hex()
}

fn test_complete_matrix_sets_match_source_tables_transform_slices_and_positions() {
	mut count := 0
	mut successes := 0
	for line in $embed_file('testdata/quant-matrix-sets.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 12
		frame := FrameHeader{ width: f[1].u32(), height: f[2].u32(), encoding: .vardct, restoration: RestorationFilter.default() }
		storage := if f[0] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 }
		tree := if f[8] == '1' {
			?ModularTree(matrix_set_fixture_tree(u8(f[3].u32()), i32(f[4].i64()), predictor_from_id(f[5].u32())!, i32(f[6].i64()), i32(f[7].i64()))!)
		} else {
			?ModularTree(none)
		}
		mut reader := new_bit_reader(hex.decode(f[9])!)
		actual := if matrices := reader.read_dequant_matrices(frame, storage, tree) {
			assert matrices.tables.len == 17
			successes++
			matrix_set_fixture_digest(matrices)!
		} else {
			'err'
		}
		assert actual == f[11], 'matrix set ${count}'
		assert reader.position == f[10].int(), 'matrix-set cursor ${count}'
		count++
	}
	assert count == 64
	assert successes == 52
}

fn test_matrix_set_channel_ownership_and_invalid_storage() {
	frame := FrameHeader{ width: 8, height: 8, restoration: RestorationFilter.default() }
	mut reader := new_bit_reader([u8(1)])
	matrices := reader.read_dequant_matrices(frame, .signed16, none)!
	assert reader.position == 1
	mut channel := matrices.channel(.dct, 0)!
	before := channel[0]
	channel[0] = 0
	assert matrices.channel(.dct, 0)![0] == before
	for c in [-1, 3] {
		if _ := matrices.channel(.dct, c) {
			assert false
		}
	}
	if _ := (DequantMatrices{}).channel(.dct, 0) {
		assert false
	}
	bad := DequantMatrices{ tables: []DequantMatrix{len: 17} }
	if _ := bad.channel(.dct, 0) {
		assert false
	}
	mut missing := new_bit_reader([]u8{})
	if _ := missing.read_dequant_matrices(frame, .signed16, none) {
		assert false
	}
	assert missing.position == 0
}
