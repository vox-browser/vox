module jpegxl

import crypto.sha256
import encoding.binary
import encoding.hex
import math

fn raw_quant_fixture_tree(property u8, threshold i32, predictor Predictor, left i32, right i32) !ModularTree {
	mut reader := new_bit_reader([u8(0xf2), 1])
	histograms := reader.read_histograms(2, true)!
	return ModularTree{
		num_properties: 16
		histograms:     histograms
		nodes:          [
			ModularTreeNode{ property: property, threshold: threshold, left: 1, right: 2 },
			ModularTreeNode{ is_leaf: true, predictor: predictor, offset: left, multiplier: 1, context: 0 },
			ModularTreeNode{ is_leaf: true, predictor: predictor, offset: right, multiplier: 1, context: 1 },
		]
	}
}

fn raw_quant_fixture_digest(matrix DequantMatrix) string {
	mut words := []u8{len: matrix.samples.len * 4}
	for i, value in matrix.samples {
		binary.little_endian_put_u32_at(mut words, math.f32_bits(value), i * 4)
	}
	return '${matrix.rows},${matrix.columns}|${sha256.sum(words).hex()}'
}

fn test_raw_quantization_streams_match_source_decoder_values_and_positions() {
	mut count := 0
	mut successes := 0
	for line in $embed_file('testdata/raw-quant-streams.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 13
		storage := if f[0] == '16' { ModularStorage.signed16 } else { ModularStorage.signed32 }
		frame := FrameHeader{ width: f[1].u32(), height: f[2].u32(), encoding: .vardct, restoration: RestorationFilter.default() }
		tree := raw_quant_fixture_tree(u8(f[4].u32()), i32(f[5].i64()), predictor_from_id(f[6].u32())!, i32(f[7].i64()), i32(f[8].i64()))!
		mut reader := new_bit_reader(hex.decode(f[9])!)
		actual := if matrix := reader.read_quant_matrix(f[3].int(), frame, storage, tree) {
			successes++
			raw_quant_fixture_digest(matrix)
		} else {
			'err'
		}
		expected := if f[12] == 'err' { 'err' } else { '${f[11]}|${f[12]}' }
		assert actual == expected, 'raw quantization stream ${count}'
		assert reader.position == f[10].int(), 'raw quantization cursor ${count}'
		count++
	}
	assert count == 512
	assert successes == 100
}

fn test_raw_quantization_stream_ids_and_missing_state_are_checked() {
	frame := FrameHeader{ width: 2049, height: 2050, encoding: .vardct, restoration: RestorationFilter.default() }
	assert frame.num_lf_groups() == 4
	assert frame.quant_table_stream_id(0)! == 13
	assert frame.quant_table_stream_id(16)! == 29
	for index in [-1, 17] {
		mut reader := new_bit_reader([u8(0)])
		if _ := reader.read_quant_matrix(index, frame, .signed32, none) {
			assert false
		}
		assert reader.position == 0
	}
	large := FrameHeader{ width: 0xffffffff, height: 0xffffffff, restoration: RestorationFilter.default() }
	if _ := large.quant_table_stream_id(0) {
		assert false
	}
	// Mode 7, denominator 1, global-tree flag with default weighted parameters.
	mut missing := new_bit_reader(hex.decode('07e01900')!)
	if _ := missing.read_quant_matrix(0, frame, .signed16, none) {
		assert false
	}
	assert missing.position == 23
	for bytes in [[]u8{}, [u8(7)], [u8(7), 0]] {
		mut reader := new_bit_reader(bytes)
		if _ := reader.read_quant_matrix(0, frame, .signed16, none) {
			assert false
		}
		assert reader.position <= bytes.len * 8
	}
	mut library := new_bit_reader([u8(0)])
	assert library.read_quant_matrix(0, frame, .signed16, none)!.samples.len == 192
	assert library.position == 3
}
